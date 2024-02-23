{
  pkgs,
  lib,
  inputs,
  username,
  ...
}: {
  imports = [inputs.nixos-wsl.nixosModules.wsl];
  home-manager.users.${username} = {
    imports = [../modules/home/git.nix];

    enableGlobalNodeJs = true;
    enableGlobalNodeJsPkgs = true;
    enableGlobalGolang = true;
    enableGlobalElixir = true;
  };

  environment.systemPackages = with pkgs; [deploy-rs];

  users.users.${username}.extraGroups = lib.mkAfter ["networkmanager"];

  programs.fish.interactiveShellInit = ''
    set fish_greeting
    bind -k nul -M insert 'accept-autosuggestion'
    set -Ux GIT_ASKPASS ""
    ssh-add ~/.ssh/id_ed25519
  '';

  services.k3s-self = {
    enable = true;
    helmCharts = ["traefik-dashboard"];
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
