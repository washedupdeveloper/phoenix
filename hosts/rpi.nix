{lib, ...}: {
  # overwrites, set by default in modules/flake/system.nix
  networking.hostName = lib.mkForce "nixos-rpi";
}
