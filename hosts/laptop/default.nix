{
  pkgs,
  lib,
  username,
  ...
}: {
  imports = [./hardware.nix ./gnome.nix ../../modules/nixos/disko ../../modules/nixos/podman];
  home-manager.users.${username}.imports = [../../modules/home/git.nix];

  environment.systemPackages = with pkgs; [microsoft-edge];

  users.users.${username}.extraGroups = lib.mkAfter ["networkmanager"];

  programs.fish.interactiveShellInit = lib.mkAfter ''
    set -Ux GIT_ASKPASS ""
    ssh-add ~/.ssh/id_ed25519
  '';

  services = {
    disko = {
      # enable = true;
      device = "/dev/nvme0n1";
      fileSystem = "btrfs";
      swapSizeInGb = "12";
    };
    xserver = {
      enable = true;
      layout = "dk";
      xkbVariant = "";
      libinput.enable = true;
      displayManager.gdm.enable = true;
      displayManager.autoLogin.enable = true;
      displayManager.autoLogin.user = username;
    };
  };

  console.keyMap = "en-latin1";
  i18n = {
    defaultLocale = "en_DK.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "da_DK.UTF-8";
      LC_IDENTIFICATION = "da_DK.UTF-8";
      LC_MEASUREMENT = "da_DK.UTF-8";
      LC_MONETARY = "da_DK.UTF-8";
      LC_NAME = "da_DK.UTF-8";
      LC_NUMERIC = "da_DK.UTF-8";
      LC_PAPER = "da_DK.UTF-8";
      LC_TELEPHONE = "da_DK.UTF-8";
      LC_TIME = "da_DK.UTF-8";
    };
  };

  fonts.packages = with pkgs; [
    (nerdfonts.override {
      fonts = [
        "Meslo"
      ];
    })
  ];
}
