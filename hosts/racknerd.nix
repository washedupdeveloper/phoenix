{
  lib,
  config,
  modulesPath,
  username,
  ...
}: {
  # overwrites, set by default in modules/system.nix
  networking.hostName = lib.mkForce "nixos-racknerd";
  time.timeZone = lib.mkForce "UTC";
  i18n.defaultLocale = lib.mkForce "C.UTF-8";

  users.users.${username} = {
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBCMD78tzMBKjffq9l65ho/6SDUrZu2gXeA6EpU5U/l 31986015+washedupdeveloper@users.noreply.github.com"];
  };

  users.users.${username} = {
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = [config.sops.secrets.ssh_key_pub.path];
  };

  users.users.root.openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBCMD78tzMBKjffq9l65ho/6SDUrZu2gXeA6EpU5U/l 31986015+washedupdeveloper@users.noreply.github.com"];

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
