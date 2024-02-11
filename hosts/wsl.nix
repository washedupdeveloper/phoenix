{
  pkgs,
  inputs,
  username,
  ...
}: {
  imports = [inputs.nixos-wsl.nixosModules.wsl];

  environment.systemPackages = with pkgs; [deploy-rs];

  home-manager.users.${username}.imports = [
    ../modules/home/code/elixir
    ../modules/home/code/golang
    ../modules/home/code/javascript
    ../modules/home/code/vscode-extensions.nix
    ../modules/home/terminal/shell
    ../modules/home/git.nix
  ];

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = username;
    startMenuLaunchers = true;
    nativeSystemd = true;
    interop.register = true;
  };

  fileSystems."/home/${username}/.ssh" = {
    device = "C:\\Users\\${username}\\.ssh";
    fsType = "drvfs";
    options = ["rw" "noatime" "uid=1000" "gid=100" "case=off" "umask=0077" "fmask=0177"];
  };

  # for building raspberry pi builds
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
}
