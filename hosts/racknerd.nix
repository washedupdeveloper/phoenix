{
  self,
  lib,
  config,
  modulesPath,
  ...
}: {
  # overwrites, set by default in modules/flake/system.nix
  networking.hostName = lib.mkForce "nixos-racknerd";
  time.timeZone = lib.mkForce "UTC";
  i18n.defaultLocale = lib.mkForce "C.UTF-8";

  users.users.${self.username} = {
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = [self.sshPubKey];
  };

  users.users.root.openssh.authorizedKeys.keys = [self.sshPubKey];

  imports = [(modulesPath + "/profiles/qemu-guest.nix")];

  boot = {
    tmp.cleanOnBoot = true;
    loader.grub.devices = ["/dev/vda"];
    initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi"];
    initrd.kernelModules = ["nvme"];
  };

  fileSystems."/" = {
    device = "/dev/vda2";
    fsType = "ext4";
  };

  zramSwap.enable = false;
  swapDevices = [{device = "/dev/vda3";}];
}
