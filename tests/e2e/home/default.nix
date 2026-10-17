# E2E: the user's home-manager configuration, on a booted machine.
#
# The `home` unit group asserts what the evaluated home-manager config says.
# This asserts what it does: activation renders the files, git signs a real
# commit with the key it was configured with, jj reads the same identity, and
# the fish hooks fire -- which is the behaviour docs/shell-integrations.md
# records as inert while the login shell was bash.
#
# The three per-tool modules are the real ones from `modules/home/`. What is
# restated here is only the composition `modules/home/default.nix` performs, and
# it has to be: a clanTest builds its nodes out of `clanInternals.nixosModules`,
# which are bare module sets, while `clan.specialArgs` -- how the repository
# hands `homeManagerModule` to that module -- is applied only when clan builds
# `nixosConfigurations` (`modules/clan/module.nix`). Supplying the argument
# through `_module.args` instead recurses, because the module imports it. The
# composition itself, and the identity wiring through `extraSpecialArgs`, are
# pinned by the `home` unit group, which reads the real machine's evaluated
# configuration.
#
# The machine is a plain test machine, not `workstation`: a NixOS-WSL guest has
# no bootloader, so it cannot be a nixosTest target.
{ inputs, ... }:
{
  name = "home";

  clan = {
    directory = ./.;
    test.useContainers = false;

    modules."base-system" = ../../../modules/clanServices/base-system;

    inventory = {
      machines.node1 = { };

      instances.base-system = {
        module.name = "base-system";
        module.input = "self";
        roles.default.tags = [ "all" ];
      };
    };
  };

  nodes.node1 =
    { config, ... }:
    {
      imports = [ inputs.home-manager.nixosModules.home-manager ];

      # Both `base-system` and the tool modules below read the account name; in
      # the repository clan.nix supplies it from `machines.workstation`.
      _module.args.username = "nixolotl";

      users.users.nixolotl = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        password = "test";
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          username = "nixolotl";
          identity = {
            name = "Nixolotl";
            email = "31986015+washedupdeveloper@users.noreply.github.com";
          };
          gitSigningKey = "~/.ssh/id_ed25519.pub";
        };
        users.nixolotl = {
          imports = [
            ../../../modules/home/git.nix
            ../../../modules/home/jj.nix
            ../../../modules/home/shell.nix
          ];
          home = {
            username = "nixolotl";
            homeDirectory = "/home/nixolotl";
            inherit (config.system) stateVersion;
          };
          programs.home-manager.enable = true;
          services.ssh-agent.enable = true;
        };
      };
    };

  testScript = ''
    start_all()
    node1.wait_for_unit("multi-user.target")

    # home-manager activation for the account. If this unit never appears,
    # nothing below can be true and the failure should say so first.
    node1.wait_for_unit("home-manager-nixolotl.service")

    # --- one identity, two tools -------------------------------------------
    # `git config --get` reads the file home-manager rendered, not the Nix
    # option, so a module that never reached ~/.gitconfig fails here.
    git_email = node1.succeed("su - nixolotl -c 'git config --global --get user.email'").strip()
    assert git_email == "31986015+washedupdeveloper@users.noreply.github.com", git_email
    git_name = node1.succeed("su - nixolotl -c 'git config --global --get user.name'").strip()
    assert git_name == "Nixolotl", git_name

    jj_email = node1.succeed("su - nixolotl -c 'jj config get user.email'").strip()
    assert jj_email == git_email, f"git and jj disagree: {git_email} vs {jj_email}"

    # jj has no `user.signingkey` of its own; git's key must not have leaked
    # into it, which is the drift the shared identity exists to prevent.
    jj_user = node1.succeed("su - nixolotl -c 'jj config list user'")
    assert "signingkey" not in jj_user, jj_user

    # --- git actually signs ------------------------------------------------
    # A real commit is the only assertion that proves `commit.gpgsign`,
    # `gpg.format = ssh` and the signing key work together: a config git never
    # parsed still answers `git config --get`.
    node1.succeed("su - nixolotl -c 'mkdir -p ~/sign-test && cd ~/sign-test && git init -q'")
    node1.succeed(
        "su - nixolotl -c 'mkdir -p ~/.ssh && test -f ~/.ssh/id_ed25519"
        " || ssh-keygen -q -t ed25519 -N \"\" -f ~/.ssh/id_ed25519'"
    )
    node1.succeed(
        "su - nixolotl -c 'echo \"nixolotl $(cat ~/.ssh/id_ed25519.pub)\" > ~/.ssh/allowed_signers'"
    )
    node1.succeed(
        "su - nixolotl -c 'cd ~/sign-test && echo hello > file.txt"
        " && git add file.txt && git commit -q -m signed'"
    )
    signature = node1.succeed(
        "su - nixolotl -c \"cd ~/sign-test && git log --format='%G?' -1\""
    ).strip()
    assert signature == "G", f"commit signature state {signature!r}, expected a good signature"

    # --- the fish integration is installed and works -----------------------
    # Every integration in modules/home/shell.nix is a fish hook, and the hook
    # is only read if fish is the login shell -- the pair that was inert while
    # the account landed in bash. First the file fish actually reads.
    node1.succeed("grep -q 'direnv hook fish' /home/nixolotl/.config/fish/config.fish")

    # Then the behaviour. direnv's hook is `--on-event fish_prompt`, and the
    # `PWD` hook it defines only exists after the first prompt -- which a
    # `fish -c` shell never draws. So the function the hook installs is called
    # directly: what this proves is that the hook is loaded, that direnv runs
    # under the account's own PATH, and that an allowed .envrc reaches the
    # shell's environment.
    node1.succeed("su - nixolotl -c 'mkdir -p ~/envrc-test'")
    node1.succeed("su - nixolotl -c 'echo \"export PROBE=live\" > ~/envrc-test/.envrc'")
    node1.succeed("su - nixolotl -c 'cd ~/envrc-test && direnv allow'")
    probe = node1.succeed(
        "su - nixolotl -c \"fish -ic 'cd ~/envrc-test; __direnv_export_eval; echo \\$PROBE'\""
    )
    assert "live" in probe, f"the fish direnv hook did not export PROBE: {probe!r}"

    # The Ctrl+Space binding, as the shell holds it. A `fish -c` session never
    # initialises key bindings at all, so this reads the function fish calls
    # when it does. That is where a wrong spelling fails: `nul` binds n, u and
    # l, and `-M insert` binds a mode this configuration never enters. See
    # docs/shell-integrations.md.
    binding = node1.succeed(
        "su - nixolotl -c \"fish -ic 'functions fish_user_key_bindings'\""
    )
    assert "bind ctrl-space accept-autosuggestion" in binding, binding
  '';
}
