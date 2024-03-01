{
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

      serverAddr = mkOption {
        type = with types; uniq str;
        default = "";
        description = "List of Helm charts to include";
      };

      extraFlags = mkOption {
        type = with types; listOf str;
        default = [];
      };

      enableHelm = mkOption {
        type = with types; bool;
        default = true;
      };

      helmCharts = mkOption {
        type = with types; listOf str;
        default = [];
        description = "List of Helm charts to include";
      };
    };

    config = let
      includeHelm = cfg.helmCharts != [] || cfg.enableHelm;
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

        # services.k3s.enable = true;
        # services.k3s.package = cfg.package;
        # services.k3s.extraFlags =
        #   builtins.toString
        #   (
        #     ["--node-name ${cfg.nodeName}"]
        #     ++ (optional (cfg.nodeIP != "") "--node-ip ${cfg.nodeIP}")
        #     ++ (
        #       if (isAgent == false)
        #       then
        #         (
        #           [
        #             "--cluster-cidr ${finalClusterCIDR}"
        #             "--service-cidr ${finalServiceCIDR}"
        #             "--cluster-dns ${cfg.clusterDNS}"
        #             "--cluster-domain ${cfg.clusterDomain}"
        #             "--disable servicelb"
        #             "--disable traefik"
        #           ]
        #           ++ (optional (cfg.tlsSAN != "") "--tls-san ${cfg.tlsSAN}")
        #           ++ (optional cfg.disableLocalPV "--disable local-storage")
        #           ++ (
        #             if cfg.disableFlannel
        #             then ["--flannel-backend none --disable-network-policy"]
        #             else ["--flannel-backend host-gw"]
        #           )
        #           ++ (optional cfg.disableMetricsServer "--disable metrics-server")
        #           ++ (optional cfg.disableKubeProxy "--disable-kube-proxy")
        #         )
        #       else []
        #     )
        #   );

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
              helmChart = "${builtins
                .toString
                ./.}/helmCharts/${file}.yaml";
            in
              if builtins.pathExists helmChart
              then "C /var/lib/rancher/k3s/server/manifests/${file}.yaml 0700 ${username} users - ${helmChart}"
              else throw "The file ${helmChart} does not exist"
          )
          cfg.helmCharts
        );
      };
  }
