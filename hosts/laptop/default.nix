{
  pkgs,
  username,
  ...
}: {
  imports = [./hardware.nix ./gnome.nix];
  home-manager.users.${username}.imports = [
    ../../modules/home/code/elixir
    ../../modules/home/code/golang
    ../../modules/home/code/javascript
    ../../modules/home/code/vscode-extensions.nix
    ../../modules/home/terminal/shell
    ../../modules/home/git.nix
    ../../modules/home/terminal/kitty.nix
  ];

  environment.systemPackages = with pkgs; [microsoft-edge];

  networking.hostName = "nixos-laptop";
  # networking.wireless.enable = true; # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;

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

  console.keyMap = "dk-latin1";
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
}
