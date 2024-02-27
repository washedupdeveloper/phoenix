{
  self,
  lib,
  pkgs,
  config,
  username,
  ...
}: let
  cfg = config.services.k3s-self;
in
  with lib; {
    options.services.k3s-self = {
      enable = mkEnableOption "k3s service";

      role = mkOption {
        type = types.enum ["server" "agent"];
        default = "server";
      };

      extraFlags = mkOption {
        type = with types; listOf str;
        default = [];
      };

      serverAddr = mkOption {
        type = with types; uniq str;
        default = "";
      };

      helmCharts = mkOption {
        type = with types; listOf str;
        default = [];
        description = "List of Helm charts to include";
      };
    };

    config = let
      includeHelm = cfg.helmCharts != [];
    in
      mkIf cfg.enable {
        environment.systemPackages = with pkgs;
          [k3s]
          ++ optional includeHelm (wrapHelm kubernetes-helm {
            plugins = with kubernetes-helmPlugins; [helmfile helm-secrets];
          });

        services.k3s = {
          enable = true;
          role = cfg.role;
          extraFlags = builtins.toString cfg.extraFlags;
        };
        # // optionalAttrs (cfg.role == "agent") {
        #   serverAddr = cfg.serverAddr;
        # };

        networking.firewall = {
          enable = true;
          allowedTCPPorts = [
            6443
            # 2379 # etcd clients: required for "High Availability Embedded etcd"
            # 2380 # etcd peers: required for "High Availability Embedded etcd"
          ];
          allowedUDPPorts = [8472];
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
