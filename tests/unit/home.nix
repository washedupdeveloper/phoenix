# The user half: what `modules/home/*` renders for the account, read out of the
# evaluated home-manager configuration.
#
# The system-level half of the same account -- the login shell, sudo, sshd --
# belongs to the `security` and `system` groups. This group covers what
# home-manager owns, and the wiring that makes one identity reach both git and
# jj: AGENTS.md records that the two copies drifted while each tool carried its
# own.
#
# Every assertion here is FLEET-shaped: it says "all of them", not "the one".
# The earlier spelling compared a per-machine map against a literal
# `{ workstation = [ "nixolotl" ]; }` and a per-user list against `[ [ ... ] ]`,
# which asserted that the fleet has exactly one machine and exactly one home.
# A second machine therefore failed the gate for existing rather than for being
# wrong, and the fix a reader would reach for is to add a second row -- which
# disables the assertion for the machine they just added. `docs/adding-a-machine.md`
# records the shape and why it is this one.
{
  lib,
  machines,
}:
let
  named = lib.mapAttrsToList (name: cfg: {
    inherit name;
    inherit (cfg) config;
  }) machines;

  # Every home-manager user on every machine, flattened. A machine without the
  # importer instance contributes nothing, which is what
  # `test_there_is_one_home_per_machine` is there to notice.
  hmUsers = lib.concatMap (
    m:
    lib.mapAttrsToList (user: hm: {
      inherit user hm;
      inherit (m) name;
      inherit (m.config) users;
      systemStateVersion = m.config.system.stateVersion;
      extraSpecialArgs = m.config.home-manager.extraSpecialArgs or { };
    }) (m.config.home-manager.users or { })
  ) named;

  email = "31986015+washedupdeveloper@users.noreply.github.com";
in
{
  home = {
    # Every machine carries this account, whatever its name. A machine that lost
    # home-manager contributes no home, and the two tests below catch it: this
    # one sees an empty list, the next one sees a length mismatch.
    test_every_machine_carries_the_account = {
      expr = lib.mapAttrs (_n: m: builtins.attrNames (m.config.home-manager.users or { })) machines;
      expected = lib.genAttrs (builtins.attrNames machines) (_: [ "nixolotl" ]);
    };

    # One home per machine: none contributes two, none contributes zero.
    # `hmUsers` is flattened across the fleet, so a count mismatch is the only
    # way this file can see a missing importer.
    test_there_is_one_home_per_machine = {
      expr = builtins.length hmUsers == builtins.length named;
      expected = true;
    };

    test_the_home_is_the_accounts_home = {
      expr = lib.all (
        u:
        "${u.user}:${u.hm.home.username}:${u.hm.home.homeDirectory}" == "nixolotl:nixolotl:/home/nixolotl"
      ) hmUsers;
      expected = true;
    };

    # home-manager's state version is not the system's, but it is derived from
    # it here so the two cannot be bumped apart.
    test_the_home_state_version_follows_the_system = {
      expr = lib.all (u: u.hm.home.stateVersion == u.systemStateVersion) hmUsers;
      expected = true;
    };

    test_home_manager_manages_itself_and_the_ssh_agent = {
      expr = lib.all (u: u.hm.programs.home-manager.enable && u.hm.services.ssh-agent.enable) hmUsers;
      expected = true;
    };

    # The invariant: one identity, two tools. A change that edits one copy is
    # the drift this pair exists to catch.
    test_git_and_jj_share_one_identity = {
      expr = lib.all (
        u:
        [
          u.hm.programs.git.settings.user.name
          u.hm.programs.git.settings.user.email
          u.hm.programs.jujutsu.settings.user.name
          u.hm.programs.jujutsu.settings.user.email
        ] == [
          "Nixolotl"
          email
          "Nixolotl"
          email
        ]
      ) hmUsers;
      expected = true;
    };

    test_the_identity_name_is_derived_from_the_username = {
      expr = lib.all (
        u:
        u.hm.programs.git.settings.user.name == (
          with lib.strings; toUpper (substring 0 1 u.hm.home.username) + substring 1 (-1) u.hm.home.username
        )
      ) hmUsers;
      expected = true;
    };

    test_git_signs_commits_with_the_ssh_key = {
      expr = lib.all (
        u:
        [
          u.hm.programs.git.settings.commit.gpgsign
          u.hm.programs.git.settings.gpg.format
          u.hm.programs.git.settings.user.signingkey
          u.hm.programs.git.settings.gpg.ssh.allowedSignersFile
        ] == [
          true
          "ssh"
          "~/.ssh/id_ed25519.pub"
          "~/.ssh/allowed_signers"
        ]
      ) hmUsers;
      expected = true;
    };

    # jj has no `user.signingkey` -- its signing is `signing.backend` plus
    # `signing.key` -- so the shared identity must stay out of git's extra key.
    test_jj_does_not_inherit_gits_signing_key = {
      expr = lib.all (u: !(u.hm.programs.jujutsu.settings.user ? signingkey)) hmUsers;
      expected = true;
    };

    test_fish_carries_the_declared_aliases = {
      expr = lib.all (
        u:
        lib.map (n: u.hm.programs.fish.shellAliases.${n} or null) [
          "cat"
          "find"
          "gc"
          "kubectl"
          "nix"
        ] == [
          "bat -p"
          "fd"
          "nix store gc"
          "kubecolor"
          "nom"
        ]
      ) hmUsers;
      expected = true;
    };

    # Every integration in modules/home/shell.nix targets fish. One left
    # without its fish hook is installed and inert.
    test_every_fish_integration_is_enabled = {
      expr = lib.all (
        u:
        [
          u.hm.programs.direnv.enable
          u.hm.programs.direnv.nix-direnv.enable
          u.hm.programs.direnv.enableFishIntegration
          u.hm.programs.atuin.enableFishIntegration
          u.hm.programs.zoxide.enableFishIntegration
          u.hm.programs.nix-your-shell.enableFishIntegration
          u.hm.programs.starship.enable
        ] == [
          true
          true
          true
          true
          true
          true
          true
        ]
      ) hmUsers;
      expected = true;
    };

    # ...and the shell those hooks are written into has to be the login shell,
    # or none of them is read. See docs/shell-integrations.md.
    test_the_login_shell_is_the_shell_the_integrations_target = {
      expr = lib.all (u: lib.hasInfix "fish" (toString (u.users.users.${u.user}.shell or ""))) hmUsers;
      expected = true;
    };

    # The identity reaches the tool modules through `extraSpecialArgs`, not
    # through a second definition inside one of them.
    test_the_identity_reaches_the_modules_through_extra_special_args = {
      expr = lib.all (
        u:
        lib.subtractLists (builtins.attrNames u.extraSpecialArgs) [
          "gitSigningKey"
          "identity"
          "username"
        ] == [ ]
      ) hmUsers;
      expected = true;
    };
  };
}
