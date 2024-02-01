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
    ];
    rpi = systemConfig "aarch64-linux" [
      "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      ../../hosts/rpi.nix
    ];
    racknerd = systemConfig "x86_64-linux" [
      inputs.disko.nixosModules.disko
      ../../hosts/racknerd.nix
    ];
    liveISO = systemConfig "x86_64-linux" [
      {
        services.openssh.settings.PasswordAuthentication = inputs.nixpkgs.lib.mkForce true;
        users.users.root = {
          initialHashedPassword = inputs.nixpkgs.lib.mkForce "$y$j9T$f4LE30RF2QMBy6jiR5j3M1$/X6daMyAm0fJ9iohebi0LZjiCHrmK092WpBpdTW6Z7A";
          openssh.authorizedKeys.keys = [self.sshPubKey];
          # TODO: add AGE secret for SOPS
        };

        systemd.services.cp-disko = {
          script = "${pkgs.coreutils}/bin/cp ${self}/modules/nixos/disko.nix /tmp/disko.nix";
          wantedBy = ["multi-user.target"];
          after = ["network.target"];
        };
      }
    ];
  };
}
