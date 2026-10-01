{
  description = "My ever-changing immutable homelab";

  # Binary caches this flake's inputs are published to, recorded next to the
  # inputs that need them so a third-party evaluator (a CI runner, another
  # machine) can substitute them by accepting the flake config. Both keys are
  # only honoured by a caller that does, which the machines here do
  # (`nix.settings.accept-flake-config`, modules/clanServices/base-system).
  #
  # `extra-experimental-features` is deliberately *not* set here. It cannot
  # bootstrap anything: Nix has to parse `flake.nix` before it can read
  # `nixConfig`, so a flake whose own code needs a feature (say
  # `pipe-operators`) cannot enable it for that evaluation. Verified with nix
  # 2.35.2 -- a flake declaring `extra-experimental-features = [ "pipe-operators" ]`
  # and then using `|>` in its own `outputs` still fails with
  # "experimental Nix feature 'pipe-operators' is disabled". Features belong in
  # nix.conf / NIX_CONFIG / `nix.settings.experimental-features`; the devshell
  # sets NIX_CONFIG for exactly this reason.
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

  inputs = {
    nixpkgs.follows = "clan-core/nixpkgs";
    clan-core = {
      url = "git+https://git.clan.lol/clan/clan-core";
      # clan-core ships its own flake-parts and treefmt-nix, both of which
      # currently resolve to the same revisions this flake already pins, so
      # following them removes two duplicate lock nodes without changing what
      # clan-core evaluates with. clan-core's own flake.nix anticipates the
      # treefmt-nix one: "Make treefmt-nix optional -- This only works if you
      # set inputs.clan-core.inputs.treefmt-nix.follows".
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
    # nixos-wsl, devshell, git-hooks and nix-topology each ship their own
    # nixpkgs/flake-parts. Nothing here consumes their *own* outputs -- only
    # `nixosModules.default`, `flakeModule` and `flakeModules.default`, all of
    # which are evaluated against this flake's pkgs and flake-parts -- so they
    # can follow the pinned copies instead of dragging in four nixpkgs.
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      # Without the last two, hermes-agent drags in its own home-manager and
      # flake-parts: the lock carried two of each. It only exports a
      # home-manager module and a nixos module here, neither of which is
      # evaluated against its own nixpkgs or its own flake-parts, so both can
      # safely follow the copies this flake already pins.
      inputs = {
        nixpkgs.follows = "clan-core/nixpkgs";
        home-manager.follows = "home-manager";
        flake-parts.follows = "flake-parts";
      };
    };
    # Skills only, and the repository ships no flake. Tracking `main` is the
    # point: the revision lives in flake.lock, and the weekly refresh job in
    # modules/hermes.nix moves it forward.
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
        ./modules/topology.nix
        ./modules/git-hooks.nix
        ./modules/treefmt.nix
        ./modules/devshells/atomvm.nix
      ];

      # One entry per architecture actually built today. clan's own flake-parts
      # template lists several, but declaring a system here means every
      # `perSystem` output is expected to evaluate -- and, with
      # `nix flake check --all-systems`, to build -- for it, so a system earns
      # its place by having a machine. `aarch64-linux` joins when the Pi does.
      systems = [
        "x86_64-linux"
      ];

      clan = {
        imports = [ (import ./clan.nix { inherit inputs; }) ];
        specialArgs = {
          homeManagerModule = inputs.home-manager.nixosModules.home-manager;
          nixosWslModule = inputs.nixos-wsl.nixosModules.default;
          # Source tree for the caveman skills; modules/hermes.nix builds it.
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

          # The documented way to give `perSystem` a nixpkgs with a non-default
          # config. Note this is *not* what clan builds its machines from: clan
          # reads `perSystem.clan.pkgs` and falls back to a plain
          # `nixpkgs.legacyPackages` when it is unset, so the two have to be
          # pointed at the same thing or the devshell and the deployed machine
          # disagree about `allowUnfree`. See `clan.pkgs` below.
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          # The pkgs clan uses for the per-system instantiations it keeps
          # internally -- `clanInternals.machines`, which is what the vars
          # generators are built from, and what `clan machines`/`clan vars` read
          # through the CLI. Clan falls back to a plain
          # `nixpkgs.legacyPackages` when this is unset, so without it the CLI
          # and the devshell would disagree about `allowUnfree`. This is the
          # pairing clan's own flake-parts template shows.
          #
          # It does *not* change `nixosConfigurations`: clan builds those with
          # `nixosSystem` without passing pkgs, so the deployed system keeps
          # deriving its pkgs from `nixpkgs.hostPlatform` and `nixpkgs.*`. No
          # overlay for nix-topology is needed here either -- its flake module
          # extends the pkgs it evaluates with its own overlay.
          clan.pkgs = pkgs;

          # The caveman skill set as its own derivation, so the weekly refresh
          # job can build a new revision and diff it before you switch to it.
          packages.caveman-skills = pkgs.callPackage ./modules/caveman-skills.nix {
            cavemanSrc = inputs.caveman;
          };
        };
    };
}
