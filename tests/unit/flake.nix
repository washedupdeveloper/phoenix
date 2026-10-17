# Flake-level assertions: the wiring in `flake.nix` and its `perSystem` block
# that no single machine's configuration shows.
#
# These are built inside `perSystem` in `modules/flake/tests.nix`, because what
# they read -- the devshell's environment, the per-system package set, the
# output set itself -- exists only in that scope.
#
# `nixConfig` is deliberately not tested. It sits outside the flake's outputs,
# so `builtins.getFlake` has no `nixConfig` attribute and `nix flake metadata
# --json` omits it; the only way to read it would be to parse `flake.nix` as
# text. The cache invariant it belongs to is asserted from the machine side
# instead -- see the `substituters` tests below, and docs/flake-internals.md for
# why the two lists are allowed to differ by `cache.clan.lol`.
{
  lib,
  machines,
  systems,
  system,
  clan,
  clanInternals,
  flake,
  perSystem,
}:
let
  named = lib.mapAttrsToList (name: cfg: {
    inherit name;
    inherit (cfg) config;
  }) machines;

  # nix's own output names, plus clan's two: `nix flake check` knows neither
  # `clan` nor `clanInternals`, and there is nothing to pair them with.
  knownOutputs = [
    "apps"
    "checks"
    "clan"
    "clanInternals"
    "darwinConfigurations"
    "darwinModules"
    "devShells"
    "formatter"
    "homeConfigurations"
    "homeModules"
    "hydraJobs"
    "inputs"
    "legacyPackages"
    "nixosConfigurations"
    "nixosGenerations"
    "nixosModules"
    "overlays"
    "packages"
    "templates"
  ];

  customOutputs = lib.subtractLists knownOutputs (builtins.attrNames flake);

  # The devshell's NIX_CONFIG, split into the features it enables. The variable
  # holds `key = value` lines; `experimental-features` must name the same
  # features `base-system` puts in `nix.settings.experimental-features`, or the
  # devshell and the machine disagree about what the flake may parse.
  devshellEnv = perSystem.devshells.default.env;

  devshellNixConfig = lib.findFirst (e: e.name == "NIX_CONFIG") { value = ""; } devshellEnv;

  devshellFeatures = lib.sort builtins.lessThan (
    lib.filter (f: f != "") (
      lib.splitString " " (
        lib.removePrefix "experimental-features = " (
          lib.findFirst (l: lib.hasPrefix "experimental-features" l) "" (
            lib.splitString "\n" devshellNixConfig.value
          )
        )
      )
    )
  );

  machineFeatures = lib.sort builtins.lessThan (
    lib.unique (lib.concatMap (m: m.config.nix.settings.experimental-features) named)
  );

  # nixpkgs normalises substituter URLs and appends a trailing slash to some of
  # them, so compare hosts rather than URLs.
  asHost = url: lib.removeSuffix "/" (lib.removePrefix "https://" url);

  substituters = lib.unique (
    lib.map asHost (lib.concatMap (m: m.config.nix.settings.substituters) named)
  );

  # The three caches this machine substitutes from. `cache.clan.lol` is
  # deliberately not among them: flake.nix declares it for other evaluators.
  machineCaches = [
    "nix-community.cachix.org"
    "pre-commit-hooks.cachix.org"
    "numtide.cachix.org"
  ];

  clanPkgs = clanInternals.machines.${system} or { };
in
{
  flake = {
    # Two wirings of one package set. If they disagree the devshell allows
    # unfree packages and the clan CLI does not; see docs/flake-internals.md.
    test_the_per_system_pkgs_agree_with_the_clan_cli = {
      expr = lib.unique (
        [ perSystem._module.args.pkgs.config.allowUnfree ]
        ++ lib.map (m: m.config.nixpkgs.pkgs.config.allowUnfree) (builtins.attrValues clanPkgs)
      );
      expected = [ true ];
    };

    test_the_devshell_and_the_machine_enable_the_same_features = {
      expr = [
        devshellFeatures
        machineFeatures
      ];
      expected = [
        [
          "flakes"
          "nix-command"
          "pipe-operators"
        ]
        [
          "flakes"
          "nix-command"
          "pipe-operators"
        ]
      ];
    };

    # `systems` is a build contract, not a wish list: a system listed here is a
    # promise that every `perSystem` output evaluates for it.
    test_every_declared_system_has_a_devshell_and_checks = {
      expr = lib.filter (
        s: (flake.devShells.${s}.default or null) == null || (flake.checks.${s} or { }) == { }
      ) systems;
      expected = [ ];
    };

    # The other direction of `test_every_machine_runs_on_a_declared_system` in
    # the `system` group: a declared system with no machine behind it is
    # surface nothing exercises.
    test_the_declared_systems_are_the_systems_the_machines_run_on = {
      expr = lib.sort builtins.lessThan systems;
      expected = lib.sort builtins.lessThan (
        lib.unique (lib.map (m: m.config.nixpkgs.hostPlatform.system) named)
      );
    };

    # `nix flake check` silently skips an output name it does not know, so a
    # custom output is only verified if something checks it. The list is
    # enumerated so a new one cannot be added without a check.
    test_the_only_custom_output_is_the_topology = {
      expr = customOutputs;
      expected = [ "topology" ];
    };

    test_every_custom_output_is_paired_with_a_check = {
      expr = lib.filter (
        o: !(lib.elem o (builtins.attrNames (flake.checks.${system} or { })))
      ) customOutputs;
      expected = [ ];
    };

    # The machine side of the cache split: the three shared caches are trusted,
    # clan's is not, and flake config is not accepted silently.
    test_the_machine_substitutes_from_the_documented_caches = {
      expr = lib.subtractLists substituters machineCaches;
      expected = [ ];
    };

    test_the_machine_does_not_substitute_from_clans_cache = {
      expr = lib.elem "cache.clan.lol" substituters;
      expected = false;
    };

    test_flake_config_is_not_accepted_silently = {
      expr = lib.unique (lib.map (m: m.config.nix.settings.accept-flake-config or false) named);
      expected = [ false ];
    };

    test_the_clan_meta_is_complete = {
      expr = lib.subtractLists [
        "description"
        "domain"
        "name"
      ] (builtins.attrNames clan.meta);
      expected = [ ];
    };
  };
}
