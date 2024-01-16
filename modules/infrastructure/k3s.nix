{
  pkgs,
  lib,
  self,
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

  # mode 0400 = readonly
  # systemd.tmpfiles.rules = [
  #   "C /var/lib/rancher/k3s/server/manifests 0700 k8 k8 - ${pkgs.writeTextFile "traefik.yaml" {}}/manifests/*"
  # ];

  systemd.tmpfiles.rules = let
    traefik = import ./manifests/traefik.nix {inherit pkgs lib;};
  in [
    "C /var/lib/rancher/k3s/server/manifests/${traefik.name} 0700 k8 k8 - ${traefik}"
  ];
}
