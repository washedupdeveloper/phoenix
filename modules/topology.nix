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
{ config, lib, ... }:
{
  perSystem.topology.modules = [ ../topology.nix ];

  # `nix flake check` does not understand the `topology` flake output. It only
  # warns `unknown flake output 'topology'` and moves on, so a topology that
  # fails to evaluate or to build goes unnoticed until somebody asks for the
  # diagram by hand -- which is exactly how the broken wiring this file used to
  # contain survived. Re-exposing the rendered output as a check per declared
  # system puts it back under `nix flake check`.
  flake.checks = lib.genAttrs config.systems (system: {
    topology = config.flake.topology.${system}.config.output;
  });
}
