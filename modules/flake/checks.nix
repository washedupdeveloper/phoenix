# `nix flake check` BUILDS `checks` but only EVALUATES `nixosConfigurations`, so
# without this a machine that evaluates and fails to build would pass the gate.
#
# Derived from the configurations rather than listed beside them: each machine's
# `nixpkgs.hostPlatform` decides its system, so there is no second machine list.
{ config, lib, ... }:
{
  flake.checks = lib.genAttrs config.systems (
    system:
    lib.mapAttrs' (name: cfg: lib.nameValuePair "nixos-${name}" cfg.config.system.build.toplevel) (
      lib.filterAttrs (
        _: cfg: cfg.config.nixpkgs.hostPlatform.system == system
      ) config.flake.nixosConfigurations
    )
  );
}
