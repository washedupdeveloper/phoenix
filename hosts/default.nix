{
  self,
  inputs,
  variables,
  ...
}: let
  commonModules = [
    ../system/base.nix
    inputs.home-manager.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {inherit inputs variables;};
        users.${variables.system.username}.imports = [
          ../user/base.nix
        ];
      };
    }
  ];

  commonSpecialArgs = {
    inherit self variables;
    inherit (self) inputs;
  };
in {
  # wsl
  nixos = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = commonSpecialArgs; # // { }
    system = variables.system.architecture or "x86_64-linux";
    modules =
      commonModules
      ++ [
        ./wsl
        {
          environment.systemPackages = [inputs.alejandra.defaultPackage.${variables.system.architecture}];
        }
        inputs.nixos-wsl.nixosModules.wsl
        inputs.vscode-server.nixosModules.default
      ];
  };
}
