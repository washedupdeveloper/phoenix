{
  pkgs,
  config,
  inputs,
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
    };
  };

  users.mutableUsers = false;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ];
    shell = pkgs.fish;
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = [config.sops.secrets.ssh_pub_key.path];
  };
  security.sudo.wheelNeedsPassword = false;

  sops = {
    defaultSopsFile = ../secrets/default.yaml;
    age.keyFile = "/home/${username}/.config/sops/age/keys.txt";
    secrets = {
      user_password.neededForUsers = true;
      ssh_pub_key = {};
      ssh_password = {};
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

    registry = {
      nixpkgs.flake = inputs.nixpkgs;
      flakes.to = {
        owner = "washedupdeveloper";
        repo = "flakes";
        type = "github";
      };
    };

    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      accept-flake-config = true;
    };
  };

  documentation = {
    enable = false;
    nixos.enable = false;
    man.enable = false;
    dev.enable = false;
  };
}
