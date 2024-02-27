{...}: {
  imports = [
    ../modules/nixos/k3s
    ../modules/nixos/podman
  ];

  networking.hostName = "nixos-rpi";
}
