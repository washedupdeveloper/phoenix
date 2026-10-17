# Core tests for the system, wired into the gate.
#
# `nix flake check` builds everything in `checks`, so everything below runs with
# the rest of the gate rather than when a human remembers to ask.
#
# - `unit-<group>` asserts on the *evaluated* configuration. No VM and no build:
#   a drifted value fails in milliseconds, with a message naming the test and
#   both values.
# - `e2e-<name>` boots the modules and asserts what the running system does,
#   which evaluation cannot see.
#
# Scope is the system itself. Expectations that belong to one service -- a
# broker's port, a server's credential -- are not here: they move with that
# service into its own module and its own test.
#
# What the e2e tests deliberately do *not* target is the machine this repository
# deploys. `workstation` is a NixOS-WSL guest: `system.build.installBootLoader`
# resolves to `${pkgs.coreutils}/bin/true` because the WSL kernel boots it, so
# there is no bootloader and nothing for QEMU to start. The e2e tests apply the
# same modules to a test machine instead, which is the closest bootable thing.
#
# clan-core's own `clan.nixosTests` option is not used: it lives in clan-core's
# `testModule` flake module, which drags in clan-core's whole check suite. The
# test module itself, `modules.nixosTest.clanTest`, is exposed directly, so it
# is applied here through `nixosLib.runTest` -- the same call clan-core makes.
{
  config,
  inputs,
  lib,
  ...
}:
let
  # Captured at flake level: inside `perSystem` the `config` argument is the
  # per-system config, which does not carry `nixosConfigurations` or the clan
  # outputs.
  inherit (config) flake;

  machines = flake.nixosConfigurations;

  # The repository's own declaration of its clan: machines, modules and
  # inventory. Imported directly rather than read back out of clan's internals,
  # so the deployability checks assert on what this repo says, not on clan's
  # interpretation of it.
  clan = import ../../clan.nix { inherit inputs; };

  nixosLib = import (inputs.nixpkgs + "/nixos/lib") { };

  # One check per group, so `--keep-going` reports every failing group rather
  # than stopping at the first.
  #
  # The per-system config is passed in rather than read here: inside `perSystem`
  # `config` is that scope's config, and the `flake` group needs it -- the
  # devshell's environment and the per-system package set live nowhere else.
  mkUnitChecks =
    pkgs: system: perSystemConfig:
    let
      groups = import ../../tests/unit {
        inherit
          lib
          machines
          clan
          system
          flake
          ;
        inherit (flake) clanInternals;
        inherit (config) systems;
        topology = flake.topology.${system}.config;
        perSystem = perSystemConfig;
      };
    in
    lib.mapAttrs (
      group: tests:
      let
        failures = lib.runTests tests;
      in
      if failures == [ ] then
        pkgs.runCommand "unit-${group}" { } "touch $out"
      else
        lib.debug.throwTestFailures { inherit failures; }
    ) groups;

  # `clanTest` resolves `clan-core` from a module argument, so it is supplied
  # here once rather than in every test file.
  mkE2eCheck =
    pkgs: body:
    nixosLib.runTest (
      {
        imports = [ inputs.clan-core.modules.nixosTest.clanTest ];
        hostPkgs = pkgs;
        defaults.imports = [ { _module.args.clan-core = inputs.clan-core; } ];
      }
      // body
    );
in
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      checks = (mkUnitChecks pkgs system config) // {
        e2e-base-system = mkE2eCheck pkgs (import ../../tests/e2e/base-system);
        e2e-home = mkE2eCheck pkgs (import ../../tests/e2e/home { inherit inputs; });
        e2e-ports = mkE2eCheck pkgs (import ../../tests/e2e/ports { inherit lib; });
      };
    };
}
