{
  lib,
  pkgs,
  config,
  username,
  ...
}: {
  # overwrites, set by default in modules/system.nix
  networking.hostName = lib.mkForce "nixos-racknerd";
  time.timeZone = lib.mkForce "UTC";
  i18n.defaultLocale = lib.mkForce "C.UTF-8";

  home-manager.users.${username}.imports = [
    ../modules/home/shell
    ../modules/home/git.nix
  ];

  users.users.${username} = {
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = [config.sops.secrets.ssh_key_pub.path];
  };
}
