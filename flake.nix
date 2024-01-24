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
    systemConfig = sys: modules:
      inputs.nixpkgs.lib.nixosSystem {
        # Shared special args
        specialArgs = {
          inherit username;
          inherit (self) inputs;
        };
        system = sys;
        # Shared modules.
        modules =
          [
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
          ]
          ++ modules;
      };
    deployConfig = name: host: system: profileOverrides: {
      hostname = host;
      profiles.system =
        {
          user = "root";
          sshUser = username;
          path = inputs.deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
        }
        // profileOverrides;
    };
  in {
    nixosConfigurations = {
      nixos = systemConfig "x86_64-linux" [
        inputs.nixos-wsl.nixosModules.wsl
        ./modules/virtualisation
        ./hosts/wsl.nix
      ];
      rpi = systemConfig "aarch64-linux" [
        "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ./hosts/rpi.nix
      ];
      racknerd = systemConfig "x86_64-linux" [
        ./hosts/racknerd.nix
      ];
    };

    packages."x86_64-linux".rpi-sdcard = self.outputs.nixosConfigurations.rpi.config.system.build.sdImage;

    deploy.nodes = {
      racknerd = deployConfig "racknerd" "vps" "x86_64-linux" {};
      rpi = deployConfig "rpi" "192.168.0.183" "aarch64-linux" {};
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;
  };
}
