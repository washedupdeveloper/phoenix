# Global topology definitions, plus the check that keeps them evaluated.
# https://oddlama.github.io/nix-topology/installation.html
{ config, lib, ... }:
{
  # Machines join the diagram on their own -- nix-topology defaults
  # `topology.nixosConfigurations` to every config carrying a `topology`
  # option. This list is for additional topology modules only.
  perSystem.topology.modules = [ ../../topology.nix ];

  # `nix flake check` skips outputs it does not recognise with only a warning,
  # so without this a broken diagram is invisible. See docs/flake-internals.md.
  flake.checks = lib.genAttrs config.systems (system: {
    topology = config.flake.topology.${system}.config.output;
  });
}
