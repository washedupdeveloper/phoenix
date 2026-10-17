# Core tests for the system, wired into the gate.
#
# `nix flake check` builds everything in `checks`, so everything below runs with
# the rest of the gate rather than when a human remembers to ask.
#
# Three tiers, and the tier is chosen by what the assertion needs:
#
# - `unit-<group>` -- the *value* of an option. `lib.runTests` over the
#   evaluated configuration: no build, no VM, milliseconds, and a failure names
#   the test with both values.
# - `build-<group>` -- the *file* the option produced. `runCommand` over
#   `system.build.etc` and the home-manager `home.file` sources: no kernel, no
#   QEMU, no Python. Anything that is a property of a generated file belongs
#   here, because a rendered file is evidence on its own.
# - `e2e-<name>` -- what a running machine *does* with it: a daemon parsing its
#   own config, a socket being open, a command succeeding. `testers.runNixOSTest`
#   with a Python `testScript`, which is the only tier that needs one.
#
# The rule this exists to enforce: Python is the price of the third tier and
# nothing else. An assertion that can be made against a rendered file must not
# be made by booting a machine to look at it.
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
# test module itself, `modules.nixosTest.clanTest`, is exposed directly and
# imported into a plain `testers.runNixOSTest`, which is the same machinery the
# nix.dev tutorial documents.
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

  # `testers.runNixOSTest` is `nixos.runTest` with `hostPkgs` and the node pkgs
  # already supplied, so neither is repeated here. `clanTest` resolves
  # `clan-core` from a module argument, supplied once for every e2e test.
  mkE2eCheck =
    pkgs: body:
    pkgs.testers.runNixOSTest (
      {
        imports = [ inputs.clan-core.modules.nixosTest.clanTest ];
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
      checks =
        (mkUnitChecks pkgs system config)
        // (import ../../tests/build { inherit pkgs lib machines; })
        // {
          e2e-base-system = mkE2eCheck pkgs (import ../../tests/e2e/base-system);
          e2e-home = mkE2eCheck pkgs (import ../../tests/e2e/home { inherit inputs; });
          e2e-ports = mkE2eCheck pkgs (import ../../tests/e2e/ports { inherit lib; });
        };
    };
}
