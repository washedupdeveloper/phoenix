# The user half: what `modules/home/*` renders, read from the evaluated
# home-manager config. System-level facts about the same account -- login shell,
# sudo, sshd -- live in the `security` and `system` groups.
#
# Every assertion is fleet-shaped -- "all of them", not "the one" -- so a second
# machine does not fail the gate for existing (docs/adding-a-machine.md).
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
  # importer contributes nothing, which `test_there_is_one_home_per_machine` notices.
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
    # A machine that lost home-manager contributes no home; the pair below catches
    # it -- this one sees an empty list, the next a length mismatch.
    test_every_machine_carries_the_account = {
      expr = lib.mapAttrs (_n: m: builtins.attrNames (m.config.home-manager.users or { })) machines;
      expected = lib.genAttrs (builtins.attrNames machines) (_: [ "nixolotl" ]);
    };

    # None contributes two homes, none contributes zero.
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

    # home-manager's state version is not the system's, but it is derived from it
    # here so the two cannot be bumped apart.
    test_the_home_state_version_follows_the_system = {
      expr = lib.all (u: u.hm.home.stateVersion == u.systemStateVersion) hmUsers;
      expected = true;
    };

    test_home_manager_manages_itself_and_the_ssh_agent = {
      expr = lib.all (u: u.hm.programs.home-manager.enable && u.hm.services.ssh-agent.enable) hmUsers;
      expected = true;
    };

    # One identity, two tools: a change editing one copy is the drift this catches.
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

    # jj has no `user.signingkey` -- it signs via `signing.backend` + `signing.key`.
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

    # An integration left without its fish hook is installed and inert.
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

    # ...and that shell has to be the login shell, or none of the hooks is read.
    test_the_login_shell_is_the_shell_the_integrations_target = {
      expr = lib.all (u: lib.hasInfix "fish" (toString (u.users.users.${u.user}.shell or ""))) hmUsers;
      expected = true;
    };

    # The identity reaches the tool modules through `extraSpecialArgs`, not a
    # second definition inside one of them.
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
