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
