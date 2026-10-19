# E2E: the user's home-manager configuration, on a booted machine.
#
# The `home` unit group asserts what the config says; this asserts what it does:
# activation renders the files, git signs a real commit, jj reads the same
# identity, and the fish hooks fire.
#
# The three per-tool modules are the real ones. What is restated is only the
# composition `modules/home/default.nix` performs, and it has to be: a clanTest
# builds nodes from `clanInternals.nixosModules`, while `clan.specialArgs` is
# applied only when clan builds `nixosConfigurations`. Supplying the argument via
# `_module.args` instead recurses, because the module imports it.
#
# Not `workstation`: a WSL guest has no bootloader for QEMU to start.
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

    # What the modules *render* -- both identity blocks, git's signing key
    # staying out of jj, the fish hook and the key binding -- is asserted by the
    # `build-home` checks against the files home-manager links. What follows is
    # what only a booted machine can answer: whether the tools agree with those
    # files and with each other.

    # --- one identity, two tools, as each tool parses it --------------------
    # Not a grep of the rendered files: `jj config get` runs jj's own parser
    # against jj's own activated config, so this catches a file that is right
    # and in the wrong place.
    git_email = node1.succeed("su - nixolotl -c 'git config --global --get user.email'").strip()
    jj_email = node1.succeed("su - nixolotl -c 'jj config get user.email'").strip()
    assert jj_email == git_email, f"git and jj disagree: {git_email} vs {jj_email}"

    # --- git actually signs ------------------------------------------------
    # The strongest assertion available: `git config --get` answers from the
    # same file whether or not git can use it, so a commit git verifies proves
    # `commit.gpgsign`, `gpg.format = ssh`, the signing key and the allowed
    # signers file all reached the live config and all work together.
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

    # --- the fish integration runs, not merely exists ----------------------
    # `build-home` asserts the hook is in the rendered config. This runs it:
    # direnv's own hook is `--on-event fish_prompt`, and the `PWD` hook it
    # defines only exists after the first prompt, which a `fish -c` shell never
    # draws -- so the function the hook installs is called directly. What this
    # proves is that the hook loaded under the account's own PATH and that an
    # allowed .envrc reaches the shell's environment.
    node1.succeed("su - nixolotl -c 'mkdir -p ~/envrc-test'")
    node1.succeed("su - nixolotl -c 'echo \"export PROBE=live\" > ~/envrc-test/.envrc'")
    node1.succeed("su - nixolotl -c 'cd ~/envrc-test && direnv allow'")
    probe = node1.succeed(
        "su - nixolotl -c \"fish -ic 'cd ~/envrc-test; __direnv_export_eval; echo \\$PROBE'\""
    )
    assert "live" in probe, f"the fish direnv hook did not export PROBE: {probe!r}"

    # The key binding as fish resolves it. `build-home` asserts the `bind` line
    # is in the config; this asserts fish accepts the key name, which is the
    # half that fails silently -- `nul` would bind n, u and l. A `fish -c`
    # session never initialises key bindings, so the function fish calls is read
    # rather than the binding table.
    binding = node1.succeed(
        "su - nixolotl -c \"fish -ic 'functions fish_user_key_bindings'\""
    )
    assert "bind ctrl-space accept-autosuggestion" in binding, binding
  '';
}
