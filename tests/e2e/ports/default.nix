# E2E: nothing listens that the configuration did not declare.
#
# The running-system half of the `ports` unit group: intent versus what the kernel
# is bound to, which catches a service opening a socket no option mentions.
#
# /proc/net rather than `ss`, because iproute2 is not part of a minimal system.
#
# Not `workstation`: a WSL guest has no bootloader for QEMU to start.
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
    # Cannot be omitted: the module system resolves `username` from `_module.args`
    # and errors when absent, so the `mkIf (username != null)` guard is unreachable.
    _module.args.username = "nixolotl";
    users.users.nixolotl = {
      isNormalUser = true;
      group = "nixolotl";
      extraGroups = [ "wheel" ];
    };
    users.groups.nixolotl = { };

    # Mirrors modules/clanServices/wsl. clan-core's networking module turns
    # resolved on -- it provides the mDNS on 5353 -- and resolved also takes 5355
    # and the :53 stub, three listeners nothing here declares.
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
