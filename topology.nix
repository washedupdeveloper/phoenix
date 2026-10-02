# The parts of the topology that cannot be derived from a NixOS config: the
# uplink, the router, the Windows host and the two network segments.
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

    # Not a NixOS machine, so nothing about it can be derived. Values taken from
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

        # The Hyper-V switch WSL2 attaches to. Windows owns it and NATs it onto
        # the LAN, hence its own network rather than a second `lan` interface.
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

    # Windows picks the range per boot, so no cidrv4 is claimed.
    wsl-nat.name = "WSL2 NAT";
  };
}
