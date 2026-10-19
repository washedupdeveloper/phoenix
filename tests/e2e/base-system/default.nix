# E2E: the real `base-system` module on a bootable machine.
#
# Asserts what the running system does, not what the config says. `sshd -T` is
# sshd's own parse of the config it serves, so it cannot be satisfied by an option
# that never reached a file.
#
# Not `workstation`: a WSL guest has no bootloader for QEMU to start.
#
# `useContainers = false` (VM, not nspawn) because a container test needs nix's
# `uid-range` feature, advertised only when builders set `auto-allocate-uids`.
#
# `modules/flake/tests.nix` supplies `imports`, `hostPkgs` and `clan-core`.
{
  name = "base-system";

  clan = {
    directory = ./.;
    test.useContainers = false;

    # The real module, not a copy.
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

  nodes.node1 = {
    # The module's user half is gated on this argument, supplied in the real repo
    # by the clan machine definition.
    _module.args.username = "nixolotl";
    users.users.nixolotl = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      password = "test";
    };
  };

  testScript = ''
    start_all()
    node1.wait_for_unit("multi-user.target")

    # --- what only a booted machine can answer ------------------------------
    # Everything the module *renders* -- timezone, locale, $EDITOR, the sudoers
    # rule -- is asserted by the `build-etc` check against the files activation
    # installs, which needs no VM. What follows is the residue: the settings as
    # a live system uses them.

    # `users.mutableUsers = false` means the account is not a file in the store;
    # activation writes it. So the passwd database is the only place that says
    # the declared shell was actually applied.
    assert "fish" in node1.succeed("getent passwd nixolotl")

    # --- the security posture, as the daemon parses it ----------------------
    # `sshd -T` is sshd's own view of the config it will serve. `build-etc`
    # asserts the file's lines; this asserts that sshd accepts them, which a
    # line that is spelled right and parsed wrong would not satisfy. It exits 1
    # with "no hostkeys available" if the host keys are absent, so generate them
    # first -- a no-op once sshd-keygen has run.
    node1.succeed("ssh-keygen -A")
    # `sshd -T` echoes the config's own casing and NixOS writes CamelCase
    # (`PasswordAuthentication no`), so compare lowercased rather than assuming
    # sshd normalises the keywords.
    sshd = node1.succeed("sshd -T").lower()
    assert "passwordauthentication no" in sshd, f"sshd would accept passwords:\n{sshd}"
    assert "kbdinteractiveauthentication no" in sshd, f"sshd would accept kbd-interactive:\n{sshd}"
    assert "permitrootlogin prohibit-password" in sshd, f"root login policy drifted:\n{sshd}"

    # --- sudo actually escalates -------------------------------------------
    # `build-etc` asserts the rendered `%wheel ... NOPASSWD` rule. Whether sudo
    # honours it is a fact about the running system: a rule that is present and
    # ineffective passes every file-level check.
    node1.succeed("su - nixolotl -c 'sudo -n true'")
  '';
}
