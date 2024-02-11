{
  pkgs,
  lib,
  username,
  sshPubKey,
  ...
}: {
  imports = [./hardware.nix ./gnome.nix];

  environment.systemPackages = with pkgs; [microsoft-edge deploy-rs];

  home-manager.users.${username}.imports = [
    ../../modules/home/code/elixir
    ../../modules/home/code/golang
    ../../modules/home/code/javascript
    ../../modules/home/code/vscode-extensions.nix
    ../../modules/home/terminal/shell
    ../../modules/home/git.nix
    ../../modules/home/terminal/kitty.nix
  ];

  users.users.${username}.extraGroups = lib.mkAfter ["networkmanager"];

  services.xserver = {
    enable = true;
    layout = "dk";
    xkbVariant = "";
    libinput.enable = true;
  };

  console.keyMap = "dk-latin1";
  i18n.defaultLocale = "en_DK.UTF-8";
  i18n.extraLocaleSettings = {
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

  fonts.packages = with pkgs; [
    (nerdfonts.override {
      fonts = [
        "Meslo"
      ];
    })
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    tmp.cleanOnBoot = true;
  };
}
