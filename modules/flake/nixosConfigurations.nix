{
  inputs,
  username,
  sshPubKey,
  ...
}: {
  flake.nixosConfigurations = let
    systemConfig = system: modules:
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs username sshPubKey;};
        inherit system;
        modules =
          [
            ../nixos/system.nix
            ../nixos/sops.nix
            ../home
          ]
          ++ modules;
      };
  in {
    wsl = systemConfig "x86_64-linux" [../../hosts/wsl.nix];
    laptop = systemConfig "x86_64-linux" [../../hosts/laptop];
    rpi = systemConfig "aarch64-linux" [
      "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      ../../hosts/rpi.nix
    ];
    racknerd = systemConfig "x86_64-linux" [../../hosts/racknerd.nix];
  };
}
