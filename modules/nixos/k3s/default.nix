{
  self,
  lib,
  pkgs,
  config,
  username,
  ...
}: let
  cfg = config.services.k3s-self;
  includeHelm = cfg.helmCharts != [];
in
  with lib; {
    options.services.k3s-self = {
      enable = mkEnableOption "k3s service";

      helmCharts = mkOption {
        type = with types; listOf str;
        default = [];
        description = "List of Helm charts to include.";
      };
    };

    config = mkIf cfg.enable {
      environment.systemPackages = with pkgs;
        [k3s]
        ++ optional includeHelm (wrapHelm kubernetes-helm {
          plugins = with kubernetes-helmPlugins; [helmfile helm-secrets];
        });

      services.k3s = {
        enable = true;
        role = "server";
      };

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [6443];
        allowedUDPPorts = [];
      };

      systemd.tmpfiles.rules = optionalAttrs includeHelm (
        map (
          file: let
            helmChart = "${self}/modules/nixos/k3s/helmCharts/${file}.yaml";
          in
            if builtins.pathExists helmChart
            then "C /var/lib/rancher/k3s/server/manifests/${file}.yaml 0700 ${username} users - ${helmChart}"
            else throw "The file ${helmChart} does not exist"
        )
        cfg.helmCharts
      );
    };
  }
