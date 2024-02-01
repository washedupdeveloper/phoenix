{
  self,
  lib,
  config,
  ...
}: {
  # overwrites, set by default in modules/flake/system.nix
  networking.hostName = lib.mkForce "nixos-laptop";
  environment.etc."mdadm.conf".text = ''
    MAILADDR root
  '';

  users.users.${self.username} = {
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = [self.sshPubKey];
  };

  services.openssh.settings.PasswordAuthentication = lib.mkForce true;

  # boot = {
  #   loader.grub.enable = true;
  #   tmp.cleanOnBoot = true;
  #   loader.grub.devices = ["/dev/nvme0n1"];
  #   initrd.kernelModules = ["nvme"];
  #   initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi"];
  # };
}
