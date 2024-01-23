{lib, ...}: {
  networking.hostName = lib.mkForce "nixos-rpi"; # overwrite, set by default in modules/system.nix
}
