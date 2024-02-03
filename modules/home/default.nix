{pkgs, ...}: let
  username = "storm";
in {
  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "23.11";
    packages = with pkgs; [curl wget zip unzip];
  };

  programs.home-manager.enable = true;
  services.ssh-agent.enable = true;

  sops = {
    defaultSopsFile = ../../secrets/default.yaml;
    age.keyFile = "/home/${username}/.config/sops/age/keys.txt";
  };
}
