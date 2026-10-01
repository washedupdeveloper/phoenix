# https://oddlama.github.io/nix-topology/installation.html
#
# Wires this repository's global topology definitions into nix-topology.
#
# `topology.modules` takes *additional topology modules* -- not NixOS
# configurations. The per-machine half of the topology needs no wiring at all:
# nix-topology defaults `topology.nixosConfigurations` to
# `lib.filterAttrs (_: x: x.config ? topology) self.nixosConfigurations`, so
# every machine that imports `nix-topology.nixosModules.default` is picked up
# on its own. Only the things that cannot be derived from a single machine --
# the internet, the Windows host, the home router, the LAN -- are listed here.
{
  perSystem.topology.modules = [ ../topology.nix ];
}
