{
  self,
  inputs,
  ...
}: let
  username = "storm";
  systemConfig = sys: modules:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {inherit self inputs username;};
      system = sys;
      modules =
        [
          ../nixos/system.nix
          ({config, ...}: {
            imports = [inputs.sops-nix.nixosModules.sops];
            sops = {
              defaultSopsFile = ../../secrets/default.yaml;
              age.keyFile = "/home/${username}/.config/sops/age/keys.txt";
              secrets = {
                user_password.neededForUsers = true;
                cache_key_priv = {
                  owner = config.users.users.${username}.name;
                  group = config.users.users.${username}.group;
                  mode = "0770";
                };
              };
            };
          })
          {
            imports = [inputs.home-manager.nixosModules.default];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {inherit inputs username;};
              users.${username}.imports = [../home];
            };
          }
        ]
        ++ modules;
    };
in {
  flake.nixosConfigurations = {
    wsl = systemConfig "x86_64-linux" [
      ../../hosts/wsl.nix
      {
        imports = [../nixos/k3s];
        services.k3s-extras = {
          enable = true;
          includeHelm = true;
        };
      }
    ];
    laptop = systemConfig "x86_64-linux" [
      ../../hosts/laptop
      {
        imports = [../nixos/disko];
        services.disko = {
          enable = true;
          device = "/dev/nvme0n1";
          fileSystem = "ext4";
          swapSizeInGb = "12";
        };
      }
    ];
    rpi = systemConfig "aarch64-linux" [
      "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      ../../hosts/rpi.nix
    ];
    racknerd = systemConfig "x86_64-linux" [
      ../../hosts/racknerd.nix
    ];
    nixosAnywhere = systemConfig "x86_64-linux" [
      {
        imports = [../nixos/disko];
        services.disko = {
          enable = true;
          device = "/dev/nvme0n1";
          fileSystem = "btrfs";
          swapSizeInGb = "12";
        };
      }
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
      }
    ];
  };
}
