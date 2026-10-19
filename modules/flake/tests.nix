# Three tiers, chosen by what the assertion needs:
#
#   unit-<group>   an option's value -- `lib.runTests` over the evaluated config,
#                  no build, milliseconds, and a failure names both values.
#   build-<group>  a generated file -- `runCommand` over `system.build.etc` and the
#                  home-manager `home.file` sources. A rendered file is evidence.
#   e2e-<name>     what a running machine does -- `testers.runNixOSTest` with a
#                  Python `testScript`, the only tier that needs one.
#
# Rule: Python is the price of the third tier and nothing else. An assertion that
# can be made against a rendered file must not boot a machine to make it.
#
# e2e tests target a test machine, not `workstation`: a WSL guest resolves
# `system.build.installBootLoader` to `true`, so QEMU has nothing to start.
#
# clan-core's `clan.nixosTests` is avoided -- it drags in clan-core's whole check
# suite. `modules.nixosTest.clanTest` is imported into a plain `runNixOSTest`.
{
  config,
  inputs,
  lib,
  ...
}:
let
  # Captured at flake level: inside `perSystem` the `config` argument is that
  # scope's config, which carries neither `nixosConfigurations` nor clan's outputs.
  inherit (config) flake;

  machines = flake.nixosConfigurations;

  # The repo's own declaration of its clan, imported directly so the deployability
  # checks assert on what this repo says, not on clan's interpretation of it.
  clan = import ../../clan.nix { inherit inputs; };

  # One check per group, so `--keep-going` reports every failing group. The
  # per-system config is passed in because the `flake` group needs it.
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

  # `runNixOSTest` already supplies `hostPkgs` and node pkgs; `clanTest` resolves
  # `clan-core` from a module argument, supplied once here for every e2e test.
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
