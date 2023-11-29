{
  self,
  inputs,
  variables,
  ...
}: let
  commonModules = [
    inputs.home-manager.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    ../modules/system.nix
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {inherit inputs variables;};
        users.${variables.system.username}.imports = [
          inputs.sops-nix.homeManagerModules.sops
          ../home
        ];
      };
    }
  ];

  commonSpecialArgs = {
    inherit variables;
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
        ./wsl.nix
        inputs.nixos-wsl.nixosModules.wsl
        inputs.vscode-server.nixosModules.default
      ];
  };
}
