{
  self,
  lib,
  pkgs,
  config,
  username,
  ...
}: let
  cfg = config.services.k3s-extras;
in {
  options.services.k3s-extras = {
    enable = lib.mkEnableOption "k3s-extras service";

    includeHelm = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include Helm in the system packages.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      [k3s]
      ++ lib.optional cfg.includeHelm (wrapHelm kubernetes-helm {
        plugins = with kubernetes-helmPlugins; [helmfile helm-secrets];
      });

    services.k3s = {
      enable = true;
      role = "server";
      extraFlags = toString [
        # "--kubelet-arg=v=4" # Optional args
      ];
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [6443];
      allowedUDPPorts = [];
    };

    systemd.tmpfiles.rules = lib.optionalAttrs cfg.includeHelm (
      map (
        file: let
          helmChart = "${self}/modules/nixos/k3s/manifests/${file}.yaml";
        in "C /var/lib/rancher/k3s/server/manifests/${file}.yaml 0700 ${username} users - ${helmChart}"
      ) [
        "traefik-dashboard"
      ]
      ++ [
        "f /etc/rancher/k3s/k3s.yaml 0644 ${username} users - -"
      ]
    );
  };
}
