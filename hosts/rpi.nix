{
  lib,
  pkgs,
  config,
  username,
  ...
}: {
  networking.hostName = lib.mkForce "nixos-rpi"; # overwrite, set by default in modules/system.nix

  users.users.${username} = {
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = [config.sops.secrets.ssh_key_pub.path];
  };
}
