{
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [./hardware.nix];

  # _module.args.pkgs = lib.mkForce (import inputs.nixpkgs rec {
  #   inherit system;
  #   config.allowUnfree = true;
  # });

  networking.hostName = "nixos-laptop";

  users.users.root = {
    hashedPassword = "$y$j9T$lMC7hcwcJYLWzYc.dmo6P.$pKG/CXDe5UfI.zyDvoj1GefBUkYB3Et6xwxfCwlFlV8";
    openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBCMD78tzMBKjffq9l65ho/6SDUrZu2gXeA6EpU5U/l 31986015+washedupdeveloper@users.noreply.github.com"];
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    tmp.cleanOnBoot = true;
  };

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "da_DK.UTF-8";
    LC_IDENTIFICATION = "da_DK.UTF-8";
    LC_MEASUREMENT = "da_DK.UTF-8";
    LC_MONETARY = "da_DK.UTF-8";
    LC_NAME = "da_DK.UTF-8";
    LC_NUMERIC = "da_DK.UTF-8";
    LC_PAPER = "da_DK.UTF-8";
    LC_TELEPHONE = "da_DK.UTF-8";
    LC_TIME = "da_DK.UTF-8"; # hi @lunarix
  };

  services.xserver = {
    enable = true;
    layout = "dk";
    xkbVariant = "";
    libinput.enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "storm";
  };

  fonts.packages = with pkgs; [
    (nerdfonts.override {
      fonts = [
        "Meslo"
      ];
    })
  ];

  console.keyMap = "dk-latin1";

  services.printing.enable = true;

  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  environment.gnome.excludePackages =
    (with pkgs; [
      gnome-photos
      gnome-tour
    ])
    ++ (with pkgs.gnome; [
      # cheese # webcam tool
      gnome-music
      # gnome-terminal
      # gedit # text editor
      # epiphany # web browser
      # geary # email reader
      # evince # document viewer
      # gnome-characters
      totem # video player
      tali # poker game
      iagno # go game
      hitori # sudoku game
      atomix # puzzle game
    ]);
}
