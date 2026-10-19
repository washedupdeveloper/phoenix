# The parts of the topology that cannot be derived from a NixOS config: the
# uplink, the router, the Windows host and the LAN.
# Per-machine facts belong under `topology.self` in the machine's own config.
# https://oddlama.github.io/nix-topology/defining-additional-things.html
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
    internet = mkInternet {
      connections = mkConnection "home-router" "wan";
    };

    # DHCP server and default gateway for the LAN.
    home-router = mkRouter "Home router" {
      info = "ISP router / DHCP server";
      connections.wan = mkConnection "internet" "*";
      interfaces.lan = {
        network = "lan";
        addresses = [ "192.168.68.1/24" ];
      };
    };

    # Not a NixOS machine, so nothing is derivable; values from `ipconfig /all`.
    # No Hyper-V switch modelled: mirrored networking puts the guest NIC straight
    # onto the LAN rather than behind a NAT (docs/adr/0002).
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
      };
    };
  };

  networks = {
    lan = {
      name = "Home network";
      cidrv4 = "192.168.68.0/24";
    };
  };
}
