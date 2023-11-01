{ self, inputs, variables, ... }:
let
  commonModules = [
    ../system/base.nix
    inputs.home-manager.nixosModules.default
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = { inherit inputs variables; };

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

    modules = commonModules ++ [
      ./wsl.nix
      inputs.nixos-wsl.nixosModules.wsl
      inputs.vscode-server.nixosModules.default
    ];
  };
}
