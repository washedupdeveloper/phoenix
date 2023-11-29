{
  pkgs,
  config,
  inputs,
  variables,
  ...
}: {
  time.timeZone = variables.region.timeZone or "UTC";
  i18n.defaultLocale = variables.region.locale or "C.UTF-8";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  fonts.packages = with pkgs; [
    (nerdfonts.override {
      fonts = [
        "Meslo"
      ];
    })
  ];

  environment.variables.EDITOR = "nano";
  environment.systemPackages = with pkgs; [sops alejandra];

  sops = {
    defaultSopsFile = ../secrets/system.yaml;
    age.keyFile = "/home/${variables.system.username}/.config/sops/age/keys.txt";
    secrets.user_password.neededForUsers = true;
    secrets.ssh_key_pub = {};
  };

  users.mutableUsers = true;
  users.users.${variables.system.username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ];
    shell = pkgs.fish;
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = [config.sops.secrets.ssh_key_pub.path];
  };

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
        owner = variables.git.github.username;
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
    enable = true;
    nixos.enable = true;
    man.enable = true;
    dev.enable = true;
  };
}
