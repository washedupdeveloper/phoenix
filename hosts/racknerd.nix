{
  self,
  config,
  modulesPath,
  username,
  sshPubKey,
  ...
}: {
  imports = [(modulesPath + "/profiles/qemu-guest.nix") (modulesPath + "/installer/scan/not-detected.nix")];

  networking.hostName = "nixos-racknerd";
  time.timeZone = "UTC";
  i18n.defaultLocale = "C.UTF-8";

  services.k3s-extras = {
    enable = true;
    helmCharts = ["traefik-dashboard"];
  };

  users.users.root.openssh.authorizedKeys.keys = [sshPubKey];
  users.users.${username} = {
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = [sshPubKey];
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
