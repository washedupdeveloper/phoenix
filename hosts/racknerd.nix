{
  pkgs,
  config,
  modulesPath,
  username,
  sshPubKey,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/installer/scan/not-detected.nix")
    ../modules/nixos/podman
  ];

  networking.hostName = "racknerd";
  time.timeZone = "UTC";
  i18n.defaultLocale = "C.UTF-8";

  users = {
    users.root.openssh.authorizedKeys.keys = [sshPubKey];
    users.${username} = {
      hashedPasswordFile = config.sops.secrets.user_password.path;
      openssh.authorizedKeys.keys = [sshPubKey];
    };
  };

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
