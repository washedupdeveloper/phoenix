# The user half: what `modules/home/*` renders for the account, read out of the
# evaluated home-manager configuration.
#
# The system-level half of the same account -- the login shell, sudo, sshd --
# belongs to the `security` and `system` groups. This group covers what
# home-manager owns, and the wiring that makes one identity reach both git and
# jj: AGENTS.md records that the two copies drifted while each tool carried its
# own.
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
  # importer instance contributes nothing.
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
    # The set is enumerated so a second account, or a second machine gaining
    # one, has to be added here on purpose.
    test_the_home_manager_users_are_the_expected_ones = {
      expr = lib.mapAttrs (_n: m: builtins.attrNames (m.config.home-manager.users or { })) machines;
      expected = {
        workstation = [ "nixolotl" ];
      };
    };

    test_the_home_is_the_accounts_home = {
      expr = lib.map (u: "${u.user}:${u.hm.home.username}:${u.hm.home.homeDirectory}") hmUsers;
      expected = [ "nixolotl:nixolotl:/home/nixolotl" ];
    };

    # home-manager's state version is not the system's, but it is derived from
    # it here so the two cannot be bumped apart.
    test_the_home_state_version_follows_the_system = {
      expr = lib.map (u: u.hm.home.stateVersion == u.systemStateVersion) hmUsers;
      expected = [ true ];
    };

    test_home_manager_manages_itself_and_the_ssh_agent = {
      expr = lib.map (u: [
        u.hm.programs.home-manager.enable
        u.hm.services.ssh-agent.enable
      ]) hmUsers;
      expected = [
        [
          true
          true
        ]
      ];
    };

    # The invariant: one identity, two tools. A change that edits one copy is
    # the drift this pair exists to catch.
    test_git_and_jj_share_one_identity = {
      expr = lib.map (u: [
        u.hm.programs.git.settings.user.name
        u.hm.programs.git.settings.user.email
        u.hm.programs.jujutsu.settings.user.name
        u.hm.programs.jujutsu.settings.user.email
      ]) hmUsers;
      expected = [
        [
          "Nixolotl"
          email
          "Nixolotl"
          email
        ]
      ];
    };

    test_the_identity_name_is_derived_from_the_username = {
      expr = lib.map (
        u:
        u.hm.programs.git.settings.user.name == (
          with lib.strings; toUpper (substring 0 1 u.hm.home.username) + substring 1 (-1) u.hm.home.username
        )
      ) hmUsers;
      expected = [ true ];
    };

    test_git_signs_commits_with_the_ssh_key = {
      expr = lib.map (u: [
        u.hm.programs.git.settings.commit.gpgsign
        u.hm.programs.git.settings.gpg.format
        u.hm.programs.git.settings.user.signingkey
        u.hm.programs.git.settings.gpg.ssh.allowedSignersFile
      ]) hmUsers;
      expected = [
        [
          true
          "ssh"
          "~/.ssh/id_ed25519.pub"
          "~/.ssh/allowed_signers"
        ]
      ];
    };

    # jj has no `user.signingkey` -- its signing is `signing.backend` plus
    # `signing.key` -- so the shared identity must stay out of git's extra key.
    test_jj_does_not_inherit_gits_signing_key = {
      expr = lib.map (u: u.hm.programs.jujutsu.settings.user ? signingkey) hmUsers;
      expected = [ false ];
    };

    test_fish_carries_the_declared_aliases = {
      expr = lib.map (
        u:
        lib.map (n: u.hm.programs.fish.shellAliases.${n} or null) [
          "cat"
          "find"
          "gc"
          "kubectl"
          "nix"
        ]
      ) hmUsers;
      expected = [
        [
          "bat -p"
          "fd"
          "nix store gc"
          "kubecolor"
          "nom"
        ]
      ];
    };

    # Every integration in modules/home/shell.nix targets fish. One left
    # without its fish hook is installed and inert.
    test_every_fish_integration_is_enabled = {
      expr = lib.map (u: [
        u.hm.programs.direnv.enable
        u.hm.programs.direnv.nix-direnv.enable
        u.hm.programs.direnv.enableFishIntegration
        u.hm.programs.atuin.enableFishIntegration
        u.hm.programs.zoxide.enableFishIntegration
        u.hm.programs.nix-your-shell.enableFishIntegration
        u.hm.programs.starship.enable
      ]) hmUsers;
      expected = [
        [
          true
          true
          true
          true
          true
          true
          true
        ]
      ];
    };

    # ...and the shell those hooks are written into has to be the login shell,
    # or none of them is read. See docs/shell-integrations.md.
    test_the_login_shell_is_the_shell_the_integrations_target = {
      expr = lib.map (u: lib.hasInfix "fish" (toString (u.users.users.${u.user}.shell or ""))) hmUsers;
      expected = [ true ];
    };

    # The identity reaches the tool modules through `extraSpecialArgs`, not
    # through a second definition inside one of them.
    test_the_identity_reaches_the_modules_through_extra_special_args = {
      expr = lib.map (
        u:
        lib.subtractLists (builtins.attrNames u.extraSpecialArgs) [
          "gitSigningKey"
          "identity"
          "username"
        ]
      ) hmUsers;
      expected = [ [ ] ];
    };
  };
}
