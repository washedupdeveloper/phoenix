# Flake-level assertions: the wiring in `flake.nix` and its `perSystem` block that
# no machine's configuration shows. Built inside `perSystem`, because what they
# read -- devshell env, per-system packages, the output set -- exists only there.
#
# `nixConfig` is not tested: it sits outside the flake's outputs, so
# `builtins.getFlake` has no such attribute and `metadata --json` omits it. The
# cache invariant is asserted from the machine side instead.
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

  # The machine templates on disk, read from the tree rather than listed: a template
  # added to `templates/machine/` joins the `systems` assertion below without anyone
  # remembering to add it there.
  templateNames = builtins.attrNames (builtins.readDir ../../templates/machine);

  # nix's own output names, plus clan's two -- `nix flake check` knows neither.
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

  # The devshell's NIX_CONFIG, split into the features it enables. Must name the
  # same features `base-system` sets in `nix.settings.experimental-features`.
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

  # nixpkgs normalises substituter URLs and appends a trailing slash to some, so
  # compare hosts rather than URLs.
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
    # the `system` group: a declared system that nothing in the repository aims at
    # is surface nothing exercises. `systems` may legitimately lead the machines --
    # the Pi's `aarch64-linux` is declared, and its checks leg built by CI, while the
    # machine itself is still one `clan machines create` away -- so a machine
    # TEMPLATE counts as aiming at a system. The template's platform is read from the
    # same `platform.nix` the template's own `nixpkgs.hostPlatform` comes from, not
    # restated here: a second copy would drift, and drifting is what this catches.
    test_the_declared_systems_are_the_systems_the_machines_run_on = {
      expr = lib.sort builtins.lessThan systems;
      expected = lib.sort builtins.lessThan (
        lib.unique (
          (lib.map (m: m.config.nixpkgs.hostPlatform.system) named)
          ++ (lib.map (t: import (../../templates/machine + "/${t}/platform.nix")) templateNames)
        )
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
