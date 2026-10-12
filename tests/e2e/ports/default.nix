# E2E: nothing listens that the configuration did not declare.
#
# This is the running-system half of the `ports` unit group. The unit test
# asserts what the configuration *intends* to expose; this asserts what the
# kernel is actually listening on. They are different claims, and the second is
# the one that catches a service opening a socket no option mentions.
#
# /proc/net is read rather than `ss` because iproute2 is not part of a minimal
# system, and the test must not depend on a diagnostic tool being installed.
#
# The machine is a plain test machine, not the WSL guest: `workstation` has no
# bootloader (the WSL kernel boots it), so it cannot be a nixosTest target. The
# modules under test are applied here unchanged.
{ lib, ... }:
{
  name = "ports";

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

  nodes.node1 = {
    # base-system's user half is gated on this argument. It cannot simply be
    # omitted: `username ? null` in the module's function pattern is bypassed by
    # the module system, which resolves the formal from `_module.args` and
    # errors when it is absent -- so the `lib.mkIf (username != null)` guard is
    # unreachable and a machine must always supply it.
    _module.args.username = "nixolotl";
    users.users.nixolotl = {
      isNormalUser = true;
      group = "nixolotl";
      extraGroups = [ "wheel" ];
    };
    users.groups.nixolotl = { };

    # Mirrors `modules/clanServices/wsl`, which forces this off. clan-core's own
    # networking module turns systemd-resolved on (it is what provides the mDNS
    # on 5353 that clan advertises in the firewall), and resolved then also
    # takes the LLMNR port 5355 and the loopback DNS stub on 53. The WSL module
    # disables it because WSL supplies its own resolver; a machine that did not
    # would show three listeners nothing in this repository declared.
    services.resolved.enable = lib.mkForce false;
  };

  testScript = ''
    start_all()
    node1.wait_for_unit("multi-user.target")

    # Recorded in the log so a failure says which daemon is responsible.
    print("resolved:", node1.succeed("systemctl is-active systemd-resolved || true").strip())

    # Every socket the kernel has, as "file local state".
    dump = node1.succeed(
        "for f in /proc/net/tcp /proc/net/tcp6 /proc/net/udp /proc/net/udp6; do"
        "  [ -f $f ] && awk -v F=$f 'NR>1 {print F, $2, $4}' $f;"
        "done; true"
    )

    def sockets(proto, states):
        """(exposed, loopback) port sets, split by the address bound."""
        exposed, loopback = set(), set()
        for line in dump.strip().splitlines():
            f, local, state = line.split()
            if not f.endswith(proto) or state not in states:
                continue
            addr, port = local.rsplit(":", 1)
            port = int(port, 16)
            # An all-zero address is "every interface"; anything else is
            # specific, and the loopback forms are 0100007F and ::1.
            if set(addr) == {"0"}:
                exposed.add(port)
            else:
                loopback.add(port)
        return sorted(exposed), sorted(loopback)

    tcp_exposed, tcp_local = sockets("tcp", {"0A"})   # 0A = LISTEN
    udp_exposed, udp_local = sockets("udp", {"07"})   # 07 = UNCONN (bound)

    print("TCP exposed:", tcp_exposed, "loopback:", tcp_local)
    print("UDP exposed:", udp_exposed, "loopback:", udp_local)

    # sshd, and nothing else, may be reachable.
    assert tcp_exposed == [22], f"undeclared TCP listener(s): {tcp_exposed}"
    assert udp_exposed == [], f"undeclared UDP listener(s): {udp_exposed}"

    # Nothing may listen on loopback either. This system has no local daemon
    # that needs one, so any listener here is a service announcing itself.
    assert tcp_local == [], f"unexpected loopback TCP: {tcp_local}"
    assert udp_local == [], f"unexpected loopback UDP: {udp_local}"
  '';
}
