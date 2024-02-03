{
  self,
  pkgs,
  ...
}: let
  username = "storm";
in {
  environment.systemPackages = with pkgs; [
    k3s
    (wrapHelm kubernetes-helm {
      plugins = with kubernetes-helmPlugins; [
        helm-secrets
      ];
    })
  ];
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      # "--kubelet-arg=v=4" # Optional args
    ];
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [6443];
    allowedUDPPorts = [];
  };

  systemd.tmpfiles.rules = let
    helperFunctions = import ../helperFunctions.nix;
  in
    map (
      file: let
        nixFile = ./manifests/${file}.nix;
        yamlFile = "${self}/modules/nixos/k3s/manifests/${file}.yaml";
      in "C /var/lib/rancher/k3s/server/manifests/${file}.yaml 0700 ${username} users - ${
        if builtins.pathExists nixFile
        then (pkgs.formats.yaml {}).generate "" (import nixFile {})
        else yamlFile
      }"
    ) [
      "traefik-dashboard"
      # "traefik-config"
    ]
    ++ [
      "f /etc/rancher/k3s/k3s.yaml 0644 ${username} users - -"
    ];
}
