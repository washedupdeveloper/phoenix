{
  pkgs,
  config,
  username,
  ...
}: {
  networking.hostName = "nixos";
  system.stateVersion = "23.11";
  time.timeZone = "Europe/Copenhagen"; # e.g. "UTC"
  i18n.defaultLocale = "en_DK.UTF-8"; # e.g. "en_US.UTF-8"

  programs.fish.enable = true;
  services.vscode-server.enable = true;
  services.openssh = {
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

  users.mutableUsers = false;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ];
    shell = pkgs.fish;
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBCMD78tzMBKjffq9l65ho/6SDUrZu2gXeA6EpU5U/l 31986015+washedupdeveloper@users.noreply.github.com"];
  };
  security.sudo.wheelNeedsPassword = false;

  sops = {
    defaultSopsFile = ../secrets/default.yaml;
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

  # fonts.packages = with pkgs; [
  #   (nerdfonts.override {
  #     fonts = [
  #       "Meslo"
  #     ];
  #   })
  # ];

  environment.variables.EDITOR = "nano";
  environment.systemPackages = with pkgs; [sops alejandra];

  nixpkgs.config.allowUnfree = true;
  nix = {
    package = pkgs.nixFlakes;

    gc = {
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

  documentation = {
    enable = false;
    nixos.enable = false;
    man.enable = false;
    dev.enable = false;
  };
}
