{
  description = "My ever-changing immutable homelab";

  inputs = {
    nixpkgs.follows = "clan-core/nixpkgs";
    clan-core = {
      url = "git+https://git.clan.lol/clan/clan-core";
      inputs.flake-parts.follows = "flake-parts";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "clan-core/nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "clan-core/nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "clan-core/nixpkgs";
    };
    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "clan-core/nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # ── Hermes Agent, patched by overlay rather than by editing its source ──
    #
    # `nixpkgs.follows` is DELIBERATELY absent. Following would rebuild Hermes
    # against this repo's nixpkgs — a full uv2nix venv build — and could also
    # disagree with the version the agent's own lock was tested against. Without
    # it, this input resolves to the same derivation the profile already has, so
    # the patch costs a wrapper, not a rebuild.
    #
    # Pinned to a rev rather than a branch for the same reason every other pin in
    # this repo is: a branch would silently change what the machine runs.
    hermes-agent.url = "github:NousResearch/hermes-agent/b56a10246e81e23d10bf6f49ae176c082db53ed9";

    # The overlay source: `overlays.wrapper` in this repo wraps an existing
    # hermes-agent with a plugin on PYTHONPATH, so the agent's source tree and its
    # store path stay untouched. See plugins/README.md there.
    hermes-skills.url = "github:washedupdeveloper/hermes-skills";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.clan-core.flakeModules.default
        inputs.devshell.flakeModule
        inputs.nix-topology.flakeModule
        ./modules/flake/nix-topology.nix
        ./modules/flake/git-hooks.nix
        ./modules/flake/treefmt.nix
        ./modules/flake/checks.nix
        ./modules/flake/tests.nix
        ./modules/flake/atomvm.nix
      ];

      systems = [ "x86_64-linux" ];

      clan = {
        imports = [ (import ./clan.nix { inherit inputs; }) ];
        specialArgs = {
          homeManagerModule = inputs.home-manager.nixosModules.home-manager;
          nixosWslModule = inputs.nixos-wsl.nixosModules.default;
        };
      };

      perSystem =
        {
          config,
          pkgs,
          inputs',
          system,
          ...
        }:
        {
          devshells.default = {
            packages =
              with pkgs;
              [
                nixd
                deadnix
                statix
                nixfmt
                nix-output-monitor
              ]
              ++ [
                inputs'.clan-core.packages.clan-cli
                config.treefmt.build.wrapper
              ];

            devshell.startup.pre-commit.text = config.pre-commit.installationScript;

            env = [
              {
                name = "NIX_CONFIG";
                # Must list the same features as base-system's nix.settings.
                value = "experimental-features = nix-command flakes pipe-operators";
              }
            ];
          };

          # Must agree with `clan.pkgs` below, or the devshell and the clan CLI
          # disagree about allowUnfree. See docs/flake-internals.md.
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          clan.pkgs = pkgs;

          # The patched agent, as an installable output:
          #
          #   nix profile install ~/projects/phoenix#hermes-agent
          #
          # This is the CLEAN route, and it is two lines of mechanism: upstream's own
          # documented seam, `hermes-agent.override { extraPythonPackages = [...]; }`.
          # Upstream's build then generates the wrapper's PYTHONPATH itself, runs its
          # plugin/core collision check over the extra packages, and the result is an
          # ordinary derivation — no `wrapProgram` postBuild, no seeded pkgs, no overlay
          # indirection.
          #
          # The plugin is built with HERMES' OWN nixpkgs, not this repo's. Those are
          # different revisions (python 3.14.6 there, 3.14.7 here), and
          # `extraPythonPackages` is resolved by `requiredPythonModules` inside upstream's
          # build — against upstream's interpreter. Building the plugin with the consumer's
          # python would put a second interpreter's site-packages on the same PYTHONPATH.
          #
          # Only the final wrapper derivation rebuilds: `extraPythonPackages` feeds the
          # wrapper, not the uv2nix venv, so the expensive part comes from the cache.
          packages.hermes-agent =
            let
              hermesPkgs = import inputs.hermes-agent.inputs.nixpkgs { inherit system; };
              plugin = hermesPkgs.callPackage (inputs.hermes-skills.outPath + "/nix/plugin.nix") { };
            in
            inputs.hermes-agent.packages.${system}.minimal.override {
              extraPythonPackages = [ plugin ];
            };

          # The plugin on its own, built by this repo's nixpkgs. Useful for inspecting it
          # or for a machine that is not running a Nix-built agent.
          packages.hermes-harness-audit = inputs.hermes-skills.packages.${system}.harness-audit;
        };
    };

  # For callers that accept the flake config. `extra-experimental-features`
  # enables `|>` for this repo's imported modules -- but not for `flake.nix`
  # itself, which nix parses before it reads `nixConfig`, so a bare `nix` with
  # no config still needs the feature in nix.conf. See
  # docs/experimental-features.md.
  #
  # The two lists must stay literal: nix reads a flake's `nixConfig` before
  # evaluating anything else and rejects a `let`-bound one with "expected a set
  # but got a thunk". Keep each substituter adjacent to its key.
  nixConfig = {
    extra-experimental-features = [ "pipe-operators" ];
    extra-substituters = [
      "https://nix-community.cachix.org/"
      "https://pre-commit-hooks.cachix.org/"
      "https://numtide.cachix.org"
      "https://cache.clan.lol"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      "cache.clan.lol-1:3KztgSAB5R1M+Dz7vzkBGzXdodizbgLXGXKXlcQLA28="
    ];
  };
}
