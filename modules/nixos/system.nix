{
  lib,
  pkgs,
  config,
  inputs,
  username,
  sshPubKey,
  ...
}:
with lib; {
  imports = [inputs.vscode-server.nixosModules.default];

  environment.variables.EDITOR = mkDefault "nano";
  environment.systemPackages = with pkgs; [sops alejandra nil];

  networking.hostName = mkDefault "nixos";
  system.stateVersion = mkDefault "23.11";
  time.timeZone = mkDefault "Europe/Copenhagen";
  i18n.defaultLocale = mkDefault "en_DK.UTF-8";

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      bind -k nul -M insert 'accept-autosuggestion'
    '';
  };
  services = {
    tailscale.enable = mkDefault true;
    vscode-server.enable = mkDefault true;
    openssh = mkDefault {
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
    users.${username} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
      ];
      shell = pkgs.fish;
      hashedPasswordFile = config.sops.secrets.user_password.path;
      openssh.authorizedKeys.keys = [sshPubKey];
    };
  };

  security.sudo.wheelNeedsPassword = mkDefault false;
  security.sudo.execWheelOnly = mkDefault true;

  nixpkgs.config.allowUnfree = mkDefault true;
  nix = {
    gc = mkDefault {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      accept-flake-config = true;
      trusted-users = ["root" "@wheel"];
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "storm:4kby1i6kECwL05+f6r3/QhosRrr+V1g8D5cB7YsimUw="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  documentation = mkDefault {
    enable = false;
    nixos.enable = false;
    man.enable = false;
    dev.enable = false;
  };
}
