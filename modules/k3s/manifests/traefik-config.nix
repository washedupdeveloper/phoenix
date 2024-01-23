{...}: {
  apiVersion = "helm.cattle.io/v1";
  kind = "HelmChartConfig";
  metadata = {
    name = "traefik";
    namespace = "kube-system";
  };
  spec = {
    valuesContent = {
      dashboard.enable = true;
      ports.traefik.expose = true;
      logs.access.enabled = true;
    };
  };
}
