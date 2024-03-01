{
  config,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../modules/nixos/k3s
    ../modules/nixos/podman
  ];

  networking.hostName = "nixos-rpi";

  services.k3s-self = {
    enable = true;
    enableHelm = true;
    extraFlags = [
      "--node-name ${config.networking.hostName}"
      #   # "--node-ip ${cfg.nodeIP}"
      #   # "--disable servicelb"
      #   # "--disable traefik"

      #   # "--disable local-storage"
      #   # "--disable metrics-server"
      #   # "--disable-kube-proxy"
      #   # "--service-cidr cidr_address_here"
      #   # "--cluster-cidr cidr_address_here"
      #   # "--cluster-dns cluster_dns_here";
    ];
  };
}
