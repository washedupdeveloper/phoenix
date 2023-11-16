{
  pkgs,
  inputs,
  variables,
  ...
}: {
  time.timeZone = variables.region.timeZone or "UTC";
  i18n.defaultLocale = variables.region.locale or "C.UTF-8";

  services.openssh = {
    enable = true;
    #   settings = {
    #     PasswordAuthentication = false;
    #   };

    #   hostKeys = [{
    #     # path = ;
    #     type = "ed25519";
    #   }];
    # };
  };

  fonts.fonts = with pkgs; [
    (nerdfonts.override {
      fonts = [
        "Meslo"
        # "CascadiaCode"
        # "JetbrainsMono"
      ];
    })
  ];

  environment.systemPackages = [ pkgs.sops ];

  users.users.${variables.system.username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      # "docker"
    ];
    shell = pkgs.fish;
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
