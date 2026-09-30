{
  inputs = {
    nixpkgs.follows = "clan-core/nixpkgs";
    clan-core.url = "git+https://git.clan.lol/clan/clan-core";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "clan-core/nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "clan-core/nixpkgs";
    };
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    devshell.url = "github:numtide/devshell";
    git-hooks.url = "github:cachix/git-hooks.nix";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "clan-core/nixpkgs";
    };
    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "clan-core/nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.clan-core.flakeModules.default
        inputs.devshell.flakeModule
        inputs.nix-topology.flakeModule
        ./modules/topology.nix
        ./modules/git-hooks.nix
        ./modules/treefmt.nix
        ./modules/devshells/atomvm.nix
      ];

      systems = [
        "x86_64-linux"
      ];

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
                value = "experimental-features = nix-command flakes pipe-operators";
              }
            ];
          };

          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ inputs.nix-topology.overlays.default ];
          };
        };
    };
}
