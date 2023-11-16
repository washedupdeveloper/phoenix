{ self, variables, ... }:
{
  networking.hostName = variables.system.hostname or "nixos-wsl";
  system.stateVersion = variables.system.stateVersion or "23.05";

  programs.fish.enable = true;
  services.vscode-server.enable = true;
  sops.defaultSopsFile = ./secrets.yaml;

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = variables.system.username;
    startMenuLaunchers = true;
    nativeSystemd = true;
  };

  fileSystems."/home/${variables.system.username}/.ssh" = {
    device = "C:\\Users\\${variables.system.username}\\.ssh";
    fsType = "drvfs";
    options = [ "rw" "noatime" "uid=1000" "gid=100" "case=off" "umask=0077" "fmask=0177" ];
  };

  # virtualisation.docker = {
  #   enable = true;
  #   enableOnBoot = true;
  #   autoPrune.enable = true;
  # };
}
