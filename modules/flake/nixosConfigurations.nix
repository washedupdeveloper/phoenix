{
  self,
  inputs,
  ...
}: let
  username = "storm";
  commonModules = [
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.default
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {};
        users.${username}.imports = [
          inputs.sops-nix.homeManagerModules.sops
          ../home
        ];
      };
    }
    inputs.vscode-server.nixosModules.default
    ../nixos/system.nix
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
      ../../hosts/laptop
      inputs.disko.nixosModules.disko
      {
        local.disko = {
          enable = true;
          device = ["/dev/nvme0n1"];
          partitionScheme = ["ext4"];
          swapSizeInGb = ["12"];
        };
      }
    ];
    rpi = systemConfig "aarch64-linux" [
      "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      ../../hosts/rpi.nix
    ];
    racknerd = systemConfig "x86_64-linux" [
      inputs.disko.nixosModules.disko
      ../../hosts/racknerd.nix
    ];
    nixos-anywhere = systemConfig "x86_64-linux" [
      inputs.disko.nixosModules.disko
      ../nixos/disko/btrfs.nix
      {
        users.users.root = {
          hashedPassword = inputs.nixpkgs.lib.mkForce "$y$j9T$f4LE30RF2QMBy6jiR5j3M1$/X6daMyAm0fJ9iohebi0LZjiCHrmK092WpBpdTW6Z7A";
          openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBCMD78tzMBKjffq9l65ho/6SDUrZu2gXeA6EpU5U/l 31986015+washedupdeveloper@users.noreply.github.com"];
          # TODO: add AGE secret for SOPS
        };

        systemd.services.sshd.wantedBy = inputs.nixpkgs.lib.mkForce ["multi-user.target"];
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = inputs.nixpkgs.lib.mkForce true;
            PermitRootLogin = "yes";
          };
          hostKeys = [
            {
              path = "/etc/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
          ];
        };

        boot = {
          loader = {
            systemd-boot.enable = true;
            efi.canTouchEfiVariables = true;
            grub.devices = ["/dev/nvme0n1"];
          };
          tmp.cleanOnBoot = true;
          kernelModules = ["kvm-intel"];
          initrd.kernelModules = ["nvme"];
          initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "alcor"];
        };
      }
    ];
  };
}
