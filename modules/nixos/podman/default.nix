{
  self,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [kompose];

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  users.extraGroups.podman.members = [self.username];
}
