{ self, variables, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];

  networking.hostName = variables.system.hostname or "nixos-wsl";
  system.stateVersion = variables.system.stateVersion or "23.05";

  programs.fish.enable = true;
  services.vscode-server.enable = true;

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = variables.system.username;
    startMenuLaunchers = true;
    nativeSystemd = true;
  };

  # virtualisation.docker = {
  #   enable = true;
  #   enableOnBoot = true;
  #   autoPrune.enable = true;
  # };
}
