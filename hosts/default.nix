{
  self,
  inputs,
  username,
  ...
}: let
  commonModules = [
    inputs.home-manager.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    inputs.vscode-server.nixosModules.default
    ../modules/system.nix
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {inherit inputs username;};
        users.${username}.imports = [
          inputs.sops-nix.homeManagerModules.sops
          ../modules/home
        ];
      };
    }
  ];

  commonSpecialArgs = {
    inherit username;
    inherit (self) inputs;
  };
in {
  # wsl
  nixos = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = commonSpecialArgs;
    system = "x86_64-linux";
    modules =
      commonModules
      ++ [
        inputs.nixos-wsl.nixosModules.wsl
        ./wsl.nix
        ../modules/infrastructure/k3s.nix
        ../modules/infrastructure/podman.nix
      ];
  };
  #IoT
  rpi = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = commonSpecialArgs;
    system = "aarch64-linux";
    modules =
      commonModules
      ++ [
        "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ./rpi.nix
        ../modules/infrastructure/k3s.nix
      ];
  };
  #TODO: Add VPS nixos configuration
}
