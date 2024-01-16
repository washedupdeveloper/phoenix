{
  config,
  pkgs,
  username,
  ...
}: {
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
      # enableNvidia = true;
    };
  };

  users.extraGroups.podman.members = [username];

  # nixpkgs.config.allowUnfree = true;

  # services.xserver.videoDrivers = ["nvidia"];

  # hardware = {
  #   opengl = {
  #     enable = true;
  #     driSupport = true;
  #     driSupport32Bit = true;
  #   };
  #   nvidia = {
  #     modesetting.enable = true;
  #     powerManagement.enable = false;
  #     powerManagement.finegrained = false;
  #     open = true;
  #   };
  # };
}
