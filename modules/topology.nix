# flake-parts module: nix-topology.
# https://oddlama.github.io/nix-topology/installation.html
{ self, ... }:
{
  perSystem = {
    topology.modules = [
      ../topology.nix
      # Feeds Clan's own nixosConfigurations output in, so topology can
      # extract from them automatically.
      { nixosConfigurations = self.nixosConfigurations; }
    ];
  };
}
