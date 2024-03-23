{
  pkgs,
  lib,
  config,
  username,
  ...
}:
with lib; {
  options = {
    enableKompose = mkOption {
      type = types.bool;
      default = true;
    };
    enableCompose = mkOption {
      type = types.bool;
      default = true;
    };
  };
  config = mkIf config.virtualisation.podman.enable {
    environment.systemPackages = with pkgs;
      (optional config.enableKompose kompose) ++ (optional config.enableCompose podman-compose);

    virtualisation.podman = {
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    users.extraGroups.podman.members = [username];
  };
}
