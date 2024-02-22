{lib, ...}: {
  imports = [./hardware.nix];

  networking.hostName = "nixos-rpi";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
}
