{
  self,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [k3s];

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

  # systemd.tmpfiles.rules = let
  #   permissionUserGroup = "0700 ${username} users";
  # in
  #   map (
  #     file: "C /var/lib/rancher/k3s/server/manifests/${file}.yaml ${permissionUserGroup} - ${
  #       (pkgs.formats.yaml {}).generate "" (import ./manifests/${file}.nix {})
  #     }"
  #   ) [
  #   ];

  systemd.tmpfiles.rules = let
    permissionUserGroup = "0700 ${self.username} users";
  in
    map (
      file: "C /var/lib/rancher/k3s/server/manifests/${file}.yaml ${permissionUserGroup} - ./manifests/${file}.yaml"
    ) [
      "traefik-dashboard"
    ];
}
