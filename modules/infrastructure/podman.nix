{
  pkgs,
  username,
  ...
}: {
  virtualisation = {
    docker.enable = false;
    podman = {
      enable = true;
      dockerCompat = true;
      # dockerSocket.enable = true;
    };
  };

  users.extraGroups.podman.members = [username];
}
