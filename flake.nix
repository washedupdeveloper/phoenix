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
    nil.url = "github:oxalica/nil";
    alejandra.url = "github:kamadorueda/alejandra/3.0.0";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = {self, ...} @ inputs: let
    username = "storm";
    commonModules = [
      inputs.home-manager.nixosModules.default
      inputs.sops-nix.nixosModules.sops
      inputs.vscode-server.nixosModules.default
      ./modules/system.nix
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {inherit inputs username;};
          users.${username}.imports = [
            inputs.sops-nix.homeManagerModules.sops
            ./modules/home
          ];
        };
      }
    ];

    commonSpecialArgs = {
      inherit username;
      inherit (self) inputs;
    };
  in {
    nixosConfigurations = {
      # WSL
      nixos = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = commonSpecialArgs;
        system = "x86_64-linux";
        modules =
          commonModules
          ++ [
            inputs.nixos-wsl.nixosModules.wsl
            # ./modules/k3s
            ./modules/virtualisation
            ./hosts/wsl.nix
          ];
      };
      # IOT
      rpi = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = commonSpecialArgs;
        system = "aarch64-linux";
        modules =
          commonModules
          ++ [
            "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            # ./modules/k3s
            ./hosts/rpi.nix
          ];
      };
      # VPS
      racknerd = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = commonSpecialArgs;
        system = "x86_64-linux";
        modules =
          commonModules
          ++ [
            # ../modules/k3s
            ./hosts/racknerd.nix
          ];
      };
    };

    packages."x86_64-linux".rpi-sdcard = self.outputs.nixosConfigurations.rpi.config.system.build.sdImage;

    # Deploy-rs
    deploy.nodes = {
      rpi = {
        hostname = "192.168.0.183";
        profiles.system = {
          sshUser = username;
          user = username;
          # sshOpts = ["-t"];
          # magicRollback = false;
          path =
            inputs.deploy-rs.lib.aarch64-linux.activate.nixos
            self.nixosConfigurations.rpi;
        };
      };
      racknerd = {
        hostname = "192.210.226.104";
        profiles.system = {
          sshUser = username;
          user = username;
          path =
            inputs.deploy-rs.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations.racknerd;
        };
      };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;
  };
}
