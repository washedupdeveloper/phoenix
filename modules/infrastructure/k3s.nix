{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [k3s];

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      # "--kubelet-arg=v=4" # Optionally add additional args to k3s
    ];
  };

  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [6443];
      allowedUDPPorts = [];
    };
  };

  # environment.etc."rancher/k3s/config.yaml".text = lib.generators.toYAML {} {
  #   "write-kubeconfig-mode" = "0644";
  #   "tls-san" = ["foo.local"];
  #   "node-label" = ["foo=bar" "something=amazing"];
  #   "cluster-init" = true;
  # };
}
