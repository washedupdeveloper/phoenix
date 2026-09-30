# https://oddlama.github.io/nix-topology/installation.html
{ config, ... }:
let
  rootConfig = config;
in
{
  perSystem = {
    topology.modules = [ rootConfig.nixosConfigurations ];
  };
}
