{
  pkgs,
  lib,
  config,
  username,
  ...
}: let
  cfg = config.services.k3s-self;
  includeHelm = cfg.helmCharts != [] || cfg.enableHelm;
in
  with lib; {
    options.services.k3s-self = {
      enable = mkEnableOption "k3s service";
      role = mkOption {
        type = types.enum ["server" "agent"];
        default = "server";
      };

      serverAddr = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "the server address 'ip:port'. Only intended for agents or appended multi-node servers";
      };

      extraFlags = mkOption {
        type = with types; listOf str;
        default = [];
      };

      enableHelm = mkOption {
        type = types.bool;
        default = true;
      };

      helmCharts = mkOption {
        type = with types; listOf str;
        default = [];
        description = "List of Helm charts to include";
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
        role = cfg.role;
        serverAddr = mkIf (cfg.serverAddr != null) cfg.serverAddr;
        extraFlags = builtins.toString cfg.extraFlags;
      };

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [
          6443
          # 2379 # etcd clients: required for "High Availability Embedded etcd"
          # 2380 # etcd peers: required for "High Availability Embedded etcd"
        ];
        allowedUDPPorts = [8472];
      };

      systemd.tmpfiles.rules = lib.optionalAttrs includeHelm (
        lib.pipe cfg.helmCharts [
          (map (file: "${toString ./.}/helmCharts/${file}.yaml"))
          (map (file:
            if pathExists file
            then file
            else throw "The file ${file} does not exist"))
          (map (file: "C /var/lib/rancher/k3s/server/manifests/${baseNameOf file} 0700 ${username} users - ${file}"))
        ]
      );
    };
  }
