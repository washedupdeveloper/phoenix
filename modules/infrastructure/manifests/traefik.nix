{
  pkgs,
  lib,
  ...
}:
pkgs.writeTextFile {
  name = "traefik.yaml";
  text = lib.generators.toYAML {} {
    ingressRoute = {
      dashboard = {
        enabled = true;
        # matchRule = "Host(`traefik.localhost`)";
        entryPoints = [
          "websecure"
        ];
        middlewares = [
          {
            name = "traefik-dashboard-auth";
          }
        ];
      };
    };
    extraObjects = [
      {
        apiVersion = "v1";
        kind = "Secret";
        metadata = {
          name = "traefik-dashboard-auth";
        };
        type = "kubernetes.io/basic-auth";
        stringData = {
          username = "storm";
          password = "!_Asgerstorm123";
        };
      }
      {
        apiVersion = "traefik.io/v1alpha1";
        kind = "Middleware";
        metadata = {
          name = "traefik-dashboard-auth";
        };
        spec = {
          basicAuth = {
            secret = "traefik-dashboard-auth";
          };
        };
      }
    ];
  };
}
