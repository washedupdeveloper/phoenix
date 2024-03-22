{
  pkgs,
  lib,
  config,
  username,
  ...
}: let
  cfg = config.modules.k3s;
  includeHelm = cfg.helmCharts != [] || cfg.enableHelm;
in
  with lib; {
    options.modules.k3s = {
      enable = mkEnableOption "k3s module";

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
        tokenFile = config.sops.secrets.k3s_token.path;
      };

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [6443 2379 2380];
        allowedUDPPorts = [8472];
        # trustedInterfaces = ["flannel.1" "tailscale0"];
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
