{
  self,
  inputs,
  ...
}: let
  commonModules = [
    inputs.home-manager.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    inputs.vscode-server.nixosModules.default
    ../nixos/system.nix
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {inherit self;};
        users.${self.username}.imports = [
          inputs.sops-nix.homeManagerModules.sops
          ../home
        ];
      };
    }
  ];
  systemConfig = sys: modules:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {inherit self inputs;};
      system = sys;
      modules = commonModules ++ modules;
    };
in {
  flake.nixosConfigurations = {
    desktop = systemConfig "x86_64-linux" [
      inputs.nixos-wsl.nixosModules.wsl
      ../nixos/k3s
      ../../hosts/desktop.nix
    ];
    laptop = systemConfig "x86_64-linux" [
      inputs.disko.nixosModules.disko
      ../nixos/k3s
      ../../hosts/laptop.nix
      (import ../nixos/disko.nix {
        device = "/dev/nvme0n1";
        swapSizeInGb = "12";
      })
    ];
    rpi = systemConfig "aarch64-linux" [
      "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      ../../hosts/rpi.nix
    ];
    racknerd = systemConfig "x86_64-linux" [../../hosts/racknerd.nix];
    liveISO = systemConfig "x86_64-linux" [
      ../nixos/liveIso.nix
    ];
  };
}
