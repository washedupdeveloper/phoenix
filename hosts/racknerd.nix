{
  lib,
  pkgs,
  config,
  modulesPath,
  username,
  ...
}: {
  imports = [(modulesPath + "/profiles/qemu-guest.nix")];

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

  users.users.root.openssh.authorizedKeys.keys = [config.sops.secrets.ssh_key_pub.path];

  boot = {
    cleanTmpDir = true;
    loader.grub.devices = ["/dev/vda1"];
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
