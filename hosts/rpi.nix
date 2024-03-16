{modulesPath, ...}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../modules/nixos/podman
  ];

  networking.hostName = "rpi";
}
