# `nix flake check` BUILDS the `checks` output and only EVALUATES
# `nixosConfigurations` -- the machine's toplevel is listed under the command's
# "evaluation checks", not among the checks it builds. So without this, a machine
# that evaluates but fails to BUILD passes the gate, which is the one failure a
# config repository most needs caught.
#
# The list is derived from the configurations rather than maintained beside them:
# a machine's own `nixpkgs.hostPlatform` decides which system it lands under, so
# there is no second machine list to keep in step with `clan.inventory.machines`.
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
