{
  description = "My ever-changing immutable homelab";

  # Substituters for this flake's inputs, for callers that accept the flake
  # config. Deliberately no `extra-experimental-features`: a flake cannot enable
  # the features its own evaluation needs. See docs/flake-internals.md.
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org/"
      "https://pre-commit-hooks.cachix.org/"
      "https://numtide.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
    ];
  };

  # Every input is consumed for its modules, never for its own flake outputs, so
  # each follows the pinned copies instead of dragging in its own nixpkgs and
  # flake-parts. See docs/flake-internals.md.
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
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs = {
        nixpkgs.follows = "clan-core/nixpkgs";
        home-manager.follows = "home-manager";
        flake-parts.follows = "flake-parts";
      };
    };
    # Skills only, and the repo ships no flake. `main` is tracked on purpose;
    # modules/hermes.nix advances the lock weekly.
    caveman = {
      url = "github:JuliusBrussee/caveman";
      flake = false;
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
        ./modules/nix-topology.nix
        ./modules/git-hooks.nix
        ./modules/treefmt.nix
        ./modules/devshells/atomvm.nix
      ];

      # A system here is a promise that every perSystem output evaluates for it,
      # so it earns its place by having a machine. aarch64-linux joins with the
      # Pi.
      systems = [
        "x86_64-linux"
      ];

      clan = {
        imports = [ (import ./clan.nix { inherit inputs; }) ];
        specialArgs = {
          homeManagerModule = inputs.home-manager.nixosModules.home-manager;
          nixosWslModule = inputs.nixos-wsl.nixosModules.default;
          cavemanSrc = inputs.caveman;
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

          # Built by the weekly refresh job in modules/hermes.nix.
          packages.caveman-skills = pkgs.callPackage ./modules/caveman-skills.nix {
            cavemanSrc = inputs.caveman;
          };
        };
    };
}
