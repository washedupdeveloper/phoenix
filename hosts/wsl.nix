{
  pkgs,
  inputs,
  username,
  ...
}: {
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    ../modules/nixos/podman
    ../modules/nixos/k3s
  ];
  home-manager.users.${username} = {
    imports = [../modules/home/git.nix];

    enableGlobalNodeJs = true;
    enableGlobalNodeJsPkgs = true;
    enableGlobalGolang = true;
    enableGlobalElixir = true;
  };

  environment.systemPackages = with pkgs; [deploy-rs];

  networking.hostName = "wsl";

  programs.fish.interactiveShellInit = ''
    set fish_greeting
    bind -k nul -M insert 'accept-autosuggestion'
    set -Ux GIT_ASKPASS ""
    ssh-add ~/.ssh/id_ed25519
  '';

  services.k3s-self.enable = true;
  services.k3s = {
    role = "server";
    extraFlags = toString [];
  };

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
