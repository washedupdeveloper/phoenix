# Global topology definitions -- things that can't be derived automatically
# from a single NixOS config (per-machine specifics go in that machine's
# own configuration.nix under `topology.self.*` instead).
# https://oddlama.github.io/nix-topology/defining-additional-things.html
{ config, ... }:
let
  inherit (config.lib.topology) mkInternet mkConnection;
in
{
  nodes.internet = mkInternet { connections = mkConnection "windows-host" "eth"; };

  nodes.windows-host = {
    name = "Windows Host";
    deviceType = "device";
    interfaces.eth = {
      network = "lan";
      physicalConnections = [ (mkConnection "workstation" "wsl0") ];
    };
  };

  networks.lan.name = "Home network";
}
