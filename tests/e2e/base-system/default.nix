# E2E: the real `base-system` module, applied to a bootable machine.
#
# The unit tests assert what the configuration *says*. This asserts what the
# running system *does*: the settings are rendered into the files and units that
# consume them, and the daemons agree. `sshd -T` is the point of the exercise --
# it is sshd's own parse of the config it will serve, so it cannot be satisfied
# by an option that never reached a file.
#
# The machine this repository deploys is a NixOS-WSL guest and cannot be the
# target: `system.build.installBootLoader` is `${pkgs.coreutils}/bin/true`
# because the WSL kernel boots it, so there is no bootloader for QEMU to start.
# The same module is applied to a test machine instead.
#
# `useContainers = false` (a VM, not an nspawn container) is deliberate. A
# container test additionally requires nix's `uid-range` system feature, which
# is advertised only when the builder sets `auto-allocate-uids`; nixpkgs'
# default `system-features` is `[ "nixos-test" "benchmark" "big-parallel" "kvm" ]`
# and this machine does not add it, so `nix flake check` would fail on a
# container test with "missing system features". A VM needs only `kvm` and
# `nixos-test`. Flip this to `true` and rename `nodes` to `containers` once
# `nix.settings.auto-allocate-uids = true` is set on the builders.
#
# This is the test module body. `modules/flake/tests.nix` supplies `imports`,
# `hostPkgs` and the `clan-core` argument, which are the same for every e2e test.
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
    # The module's user-facing half is conditional on this argument, which the
    # clan machine definition supplies in the real repository.
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

    # --- the module's settings reached the running system -------------------
    # time.timeZone renders to /etc/localtime, so read it back rather than the
    # option.
    assert "Europe/Copenhagen" in node1.succeed("readlink -f /etc/localtime")
    assert "en_DK.UTF-8" in node1.succeed("cat /etc/locale.conf")

    # environment.variables.EDITOR is set on the system profile.
    assert "nano" in node1.succeed("cat /etc/set-environment")

    # The conditional half of the module: `username`'s shell is fish. Without
    # the argument this block is skipped entirely, so this is what proves the
    # module was instantiated with a username rather than silently inert.
    assert "fish" in node1.succeed("getent passwd nixolotl")

    # --- the security posture, as the daemon parses it ----------------------
    # `sshd -T` is sshd's own view of the config it will serve: a Nix option
    # that never reached a file cannot satisfy these. It exits 1 with
    # "no hostkeys available" if the host keys are absent, so generate them
    # first -- a no-op once sshd-keygen has run.
    node1.succeed("ssh-keygen -A")
    # `sshd -T` echoes the config's own casing and NixOS writes CamelCase
    # (`PasswordAuthentication no`), so compare lowercased rather than assuming
    # sshd normalises the keywords.
    sshd = node1.succeed("sshd -T").lower()
    assert "passwordauthentication no" in sshd, f"sshd would accept passwords:\n{sshd}"
    assert "kbdinteractiveauthentication no" in sshd, f"sshd would accept kbd-interactive:\n{sshd}"
    assert "permitrootlogin prohibit-password" in sshd, f"root login policy drifted:\n{sshd}"

    # --- sudo ---------------------------------------------------------------
    # execWheelOnly + wheelNeedsPassword=false is only meaningful if a wheel
    # member can escalate without a prompt.
    node1.succeed("grep -q '%wheel' /etc/sudoers")
    node1.succeed("su - nixolotl -c 'sudo -n true'")
  '';
}
