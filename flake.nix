{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    sops-nix.url = "github:Mic92/sops-nix";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    # alejandra.url = "github:kamadorueda/alejandra/3.0.0";
    deploy-rs.url = "github:serokell/deploy-rs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    disko = {
      url = "github:nix-community/disko/refs/tags/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # devshell.url = "github:numtide/devshell";
    # kubeGenerators.url = "github:farcaller/nix-kube-generators";
    # kubeModules.url = "github:farcaller/nix-kube-modules";
    # cake.url = "github:farcaller/cake";
  };

  outputs = {self, ...} @ inputs: let
    username = "storm";
    sshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBCMD78tzMBKjffq9l65ho/6SDUrZu2gXeA6EpU5U/l 31986015+washedupdeveloper@users.noreply.github.com";
  in
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ({inputs, ...}: {
          flake.nixosModules.deploy =
            inputs.flake-parts.lib.importApply ./modules/flake/deploy.nix
            {inherit username;};
        })
      ];
      flake = {
        nixosConfigurations = let
          systemConfig = system: modules:
            inputs.nixpkgs.lib.nixosSystem {
              specialArgs = {
                inherit self inputs;
                username = username;
                sshPubKey = sshPubKey;
              };
              inherit system;
              modules =
                [
                  ./modules/nixos/system.nix
                  ./modules/nixos/sops.nix
                  ./modules/home
                ]
                ++ modules;
            };
        in {
          wsl = systemConfig "x86_64-linux" [./hosts/wsl.nix];
          laptop = systemConfig "x86_64-linux" [./hosts/laptop];
          rpi = systemConfig "aarch64-linux" [
            "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./hosts/rpi
          ];
          racknerd = systemConfig "x86_64-linux" [./hosts/racknerd.nix];
        };
      };
      systems = ["x86_64-linux" "aarch64-linux"];
      perSystem = {system, ...}: {
        # formatter = inputs.alejandra.defaultPackage.${system};
        packages = {
          rpi = self.nixosConfigurations.rpi.config.system.build.sdImage;
          nixosAnywhere = inputs.nixos-anywhere.packages.${system}.nixos-anywhere;
        };
        # devshells.default = {
        #   packages = with pkgs; [];
        # };
      };
    };
}
