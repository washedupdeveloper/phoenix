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

    # Pinned to a release tag, not a bare rev: `nix flake lock` records the tag in
    # `original.ref` and the commit it resolved to in `locked.rev`, so this is still an
    # exact pin, and the version string is derived from the tag instead of defaulting to
    # 0.0.0. Nix discards the ref before the derivation sees it, so `flake.lock` is the
    # only place the tag survives — `outputs` reads it back. See docs/flake-internals.md.
    #
    # `nixpkgs` is followed deliberately. clan-core's nixpkgs input IS the
    # nixpkgs-unstable channel, so following it builds the agent, its uv2nix venv and
    # its runtime tools (python, ripgrep, ffmpeg) with the machine's own nixpkgs instead
    # of the snapshot this rev happened to lock. Cost: the venv is rebuilt, because the
    # derivation no longer matches anything in the binary cache.
    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v0.22.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Supplies the overlay and `packages.harness-audit`.
    hermes-skills.url = "github:washedupdeveloper/hermes-skills";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    let
      # The tag in `inputs.hermes-agent.url`, as `nix flake lock` recorded it. One fact:
      # bumping the release means editing the URL, and the version string follows.
      lock = builtins.fromJSON (builtins.readFile ./flake.lock);
      hermesTag =
        lock.nodes.hermes-agent.original.ref
          or (throw "hermes-agent must be pinned to a release tag: flake.lock records no `ref`");
      hermesVersion = builtins.substring 1 (builtins.stringLength hermesTag - 1) hermesTag;
    in
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

          # Install with: nix profile install ~/projects/phoenix#hermes-agent
          #
          # Upstream's own seam. `extraPythonPackages` feeds the wrapper, not the
          # uv2nix venv, so only the final derivation rebuilds. The plugin is built from
          # this repo's `pkgs` because `hermes-agent` follows `nixpkgs`: that is the
          # interpreter whose site-packages the wrapper's PYTHONPATH has to reach.
          #
          # `version` is what `hermes --version` reports; upstream defaults it to 0.0.0
          # because the Nix evaluator never sees a git tag.
          packages.hermes-agent =
            let
              plugin = pkgs.callPackage (inputs.hermes-skills.outPath + "/nix/plugin.nix") { };
            in
            inputs.hermes-agent.packages.${system}.minimal.override {
              version = hermesVersion;
              extraPythonPackages = [ plugin ];
            };

          # The plugin on its own, built by this repo's nixpkgs. Useful for inspecting it
          # or for a machine that is not running a Nix-built agent.
          packages.hermes-harness-audit = inputs.hermes-skills.packages.${system}.harness-audit;
        };
    };

  # Must stay literal: nix reads nixConfig before evaluating anything else, and
  # rejects a `let`-bound value with "expected a set but got a thunk".
  #
  # `extra-experimental-features` enables `|>` for imported modules but not for
  # flake.nix itself, which is parsed before nixConfig is read -- a bare `nix` with
  # no config still needs the feature in nix.conf (docs/experimental-features.md).
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
