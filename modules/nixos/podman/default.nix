{
  pkgs,
  lib,
  config,
  username,
  ...
}: let
  cfg = config.modules.podman;
in
  with lib; {
    options.modules.podman = {
      enable = mkEnableOption "podman module";

      enableKompose = mkOption {
        type = types.bool;
        default = true;
      };
      enableCompose = mkOption {
        type = types.bool;
        default = true;
      };
    };
    config = mkIf cfg.enable {
      environment.systemPackages = with pkgs;
        (optional cfg.enableKompose kompose) ++ (optional cfg.enableCompose podman-compose);

      virtualisation = {
        podman = {
          enable = true;
          dockerCompat = true;
          dockerSocket.enable = true;
          defaultNetwork.settings.dns_enabled = true;
        };
      };

      users.extraGroups.podman.members = [username];
    };
  }
