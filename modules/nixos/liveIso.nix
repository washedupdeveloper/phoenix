{inputs, ...}: {
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
  ];
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;
  users.users.root = {
    initialHashedPassword = "$y$j9T$f4LE30RF2QMBy6jiR5j3M1$/X6daMyAm0fJ9iohebi0LZjiCHrmK092WpBpdTW6Z7A";
    openssh.authorizedKeys.keys = [self.sshPubKey];
  };
}
