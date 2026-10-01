# Global topology definitions -- things that can't be derived automatically
# from a single NixOS config (per-machine specifics go in that machine's
# own configuration.nix under `topology.self.*` instead).
# https://oddlama.github.io/nix-topology/defining-additional-things.html
#
# Only one machine is a NixOS configuration today, so everything the diagram
# shows apart from that machine -- the uplink, the router, the Windows host and
# the two network segments -- is declared here.
{ config, ... }:
let
  inherit (config.lib.topology)
    mkConnection
    mkDevice
    mkInternet
    mkRouter
    ;
in
{
  nodes = {
    # The WAN uplink. `mkInternet` is nix-topology's own helper for the cloud
    # node: it sets the `internet` deviceType and a wildcard interface that
    # every uplink attaches to.
    internet = mkInternet {
      connections = mkConnection "home-router" "wan";
    };

    # The ISP router. It owns the LAN and is the DHCP server and default
    # gateway for everything on it. `mkRouter` is `mkSwitch` with the `router`
    # deviceType, so ports are declared through `connections` and interface
    # options can be given alongside.
    home-router = mkRouter "Home router" {
      info = "ISP router / DHCP server";
      connections.wan = mkConnection "internet" "*";
      interfaces.lan = {
        network = "lan";
        addresses = [ "192.168.68.1/24" ];
      };
    };

    # The Windows 11 host. It is not a NixOS machine, so nix-topology cannot
    # derive anything about it: every interface below is declared by hand, from
    # the host's `ipconfig /all`.
    windows-host = mkDevice "Desktop-Storm" {
      info = "Windows 11 host - Ryzen 9 9900X3D / Radeon RX 9070 XT";
      connections.eth = mkConnection "home-router" "lan";
      interfaces = {
        # Realtek PCIe GbE Family Controller -- the only connected NIC.
        eth = {
          network = "lan";
          type = "ethernet";
          mac = "30:c5:99:26:e1:4f";
          addresses = [ "192.168.68.107/24" ];
          gateways = [ "192.168.68.1" ];
        };

        # The Hyper-V virtual switch that WSL2 attaches to. Windows owns it and
        # NATs it onto the LAN, which is why it belongs to its own network
        # instead of being folded into `lan`.
        wsl-switch = {
          network = "wsl-nat";
          virtual = true;
          type = "ethernet";
          physicalConnections = [ (mkConnection "workstation" "wsl0") ];
        };
      };
    };
  };

  networks = {
    lan = {
      name = "Home network";
      cidrv4 = "192.168.68.0/24";
    };

    # WSL2's private NAT segment. Windows picks the range per boot, so no
    # cidrv4 is claimed here.
    wsl-nat.name = "WSL2 NAT";
  };
}
