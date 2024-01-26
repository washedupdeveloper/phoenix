{
  self,
  pkgs,
  ...
}: {
  home = {
    username = self.username;
    homeDirectory = "/home/${self.username}";
    stateVersion = "23.11";
    packages = with pkgs; [curl wget zip unzip];
  };

  programs.home-manager.enable = true;
  services.ssh-agent.enable = true;

  sops = {
    defaultSopsFile = ../../secrets/default.yaml;
    age.keyFile = "/home/${self.username}/.config/sops/age/keys.txt";
  };
}
