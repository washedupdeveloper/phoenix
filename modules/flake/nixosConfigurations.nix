{
  self,
  inputs,
  ...
}: let
  systemModule = {
    lib,
    pkgs,
    config,
    ...
  }: {
    imports = [inputs.vscode-server.nixosModules.default];

    environment.variables.EDITOR = lib.mkDefault "nano";
    environment.systemPackages = with pkgs; [sops alejandra nil];

    networking.hostName = lib.mkDefault "nixos";
    system.stateVersion = lib.mkDefault "23.11";
    time.timeZone = lib.mkDefault "Europe/Copenhagen";
    i18n.defaultLocale = lib.mkDefault "en_DK.UTF-8";

    programs.fish.enable = true;
    programs.fish.interactiveShellInit = ''
      set fish_greeting
      bind -k nul -M insert 'accept-autosuggestion'
    '';
    services = {
      vscode-server = {
        enable = true;
        enableFHS = true;
        nodejsPackage = pkgs.nodejs;
      };
      openssh = lib.mkDefault {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };
    };

    users = {
      mutableUsers = false;
      users.${self.username} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
        ];
        shell = pkgs.fish;
        hashedPasswordFile = config.sops.secrets.user_password.path;
        openssh.authorizedKeys.keys = [self.sshPubKey];
      };
    };

    security.sudo.wheelNeedsPassword = lib.mkDefault false;
    security.sudo.execWheelOnly = lib.mkDefault true;

    nixpkgs.config.allowUnfree = lib.mkDefault true;
    nix = {
      gc = lib.mkDefault {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };

      settings = {
        experimental-features = ["nix-command" "flakes"];
        auto-optimise-store = true;
        accept-flake-config = true;
        trusted-users = ["root" "@wheel"];
        trusted-public-keys = ["storm:4kby1i6kECwL05+f6r3/QhosRrr+V1g8D5cB7YsimUw="];
      };
    };
  };
  sopsModule = {config, ...}: {
    imports = [inputs.sops-nix.nixosModules.sops];
    sops = {
      defaultSopsFile = ../../secrets/default.yaml;
      age.keyFile = "/home/${self.username}/.config/sops/age/keys.txt";
      secrets = {
        user_password.neededForUsers = true;
        cache_key_priv = {
          owner = config.users.users.${self.username}.name;
          group = config.users.users.${self.username}.group;
          mode = "0770";
        };
      };
    };
  };
  homeManagerModule = {
    pkgs,
    config,
    ...
  }: {
    imports = [inputs.home-manager.nixosModules.default];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs;
        username = self.username;
        sshPubKey = self.sshPubKey;
      };
      users.${self.username}.imports = [../home];
    };
  };
  systemConfig = system: modules:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit self inputs;
        username = self.username;
        sshPubKey = self.sshPubKey;
      };
      inherit system;
      modules =
        [
          systemModule
          sopsModule
          homeManagerModule
        ]
        ++ modules;
    };
in {
  flake.nixosConfigurations = {
    wsl = systemConfig "x86_64-linux" [
      ../../hosts/wsl.nix
      ../nixos/k3s
    ];
    laptop = systemConfig "x86_64-linux" [
      ../../hosts/laptop
      ../nixos/disko
    ];
    rpi = systemConfig "aarch64-linux" [
      "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      ../../hosts/rpi.nix
    ];
    racknerd = systemConfig "x86_64-linux" [
      ../../hosts/racknerd.nix
      ../nixos/k3s
      ../nixos/podman
    ];
    nixosAnywhere = systemConfig "x86_64-linux" [
      {
        imports = [../nixos/disko];
        services.disko = {
          enable = true;
          device = "/dev/DEVICE_NAME";
          fileSystem = "btrfs";
          swapSizeInGb = "12";
        };
      }
      {
        users.users.root = {
          hashedPassword = inputs.nixpkgs.lib.mkOverride "$y$j9T$f4LE30RF2QMBy6jiR5j3M1$/X6daMyAm0fJ9iohebi0LZjiCHrmK092WpBpdTW6Z7A";
          openssh.authorizedKeys.keys = [self.sshPubKey];
          # TODO: add AGE secret for SOPS
        };

        systemd.services.sshd.wantedBy = inputs.nixpkgs.lib.mkOverride ["multi-user.target"];
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = inputs.nixpkgs.lib.mkOverride true;
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
          tmp.cleanOnBoot = true;
          loader = {
            systemd-boot.enable = true;
            efi = {
              canTouchEfiVariables = true;
              efiSysMountPoint = "/boot";
            };
            grub = {
              efiSupport = true;
              #efiInstallAsRemovable = true; # in case canTouchEfiVariables doesn't work for your system
              device = "nodev";
            };
          };
        };
      }
    ];
  };
}
