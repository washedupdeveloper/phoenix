# Tests for the deployable system, wired into the gate.
#
# `nix flake check` builds everything in `checks`, so everything below runs with
# the rest of the gate rather than when a human remembers to ask.
#
# - `unit/<group>` asserts on the *evaluated* configuration. No VM and no build:
#   a drifted option value fails in milliseconds, with a message naming the test
#   and both values.
# - `e2e/<name>` boots the real modules and asserts behaviour, which evaluation
#   cannot see.
#
# What the e2e tests deliberately do *not* target is the machine this repository
# deploys. `workstation` is a NixOS-WSL guest: `system.build.installBootLoader`
# resolves to `${pkgs.coreutils}/bin/true` because the WSL kernel boots it, so
# there is no bootloader and nothing for QEMU to start. The e2e tests apply the
# same modules to a container instead, which is the closest bootable thing.
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
  # per-system config, which does not carry `nixosConfigurations`.
  inherit (config) flake;

  machines = flake.nixosConfigurations;

  nixosLib = import (inputs.nixpkgs + "/nixos/lib") { };

  # One check per group, so `--keep-going` reports every failing group rather
  # than stopping at the first.
  mkUnitChecks =
    pkgs: system:
    let
      groups = import ../../tests/unit {
        inherit lib machines;
        inherit (config) systems;
        topology = flake.topology.${system}.config;
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
        lib.throwTestFailures { inherit failures; }
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
    { pkgs, system, ... }:
    {
      checks = (mkUnitChecks pkgs system) // {
        e2e-base-system = mkE2eCheck pkgs (import ../../tests/e2e/base-system);
      };
    };
}
