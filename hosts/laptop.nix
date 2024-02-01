{
  self,
  lib,
  config,
  ...
}: {
  # overwrites, set by default in modules/flake/system.nix
  networking.hostName = lib.mkForce "nixos-laptop";
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  environment.etc."mdadm.conf".text = ''
    MAILADDR root
  '';

  users.users.${self.username} = {
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = [self.sshPubKey];
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      grub.devices = ["/dev/nvme0n1"];
    };
    tmp.cleanOnBoot = true;
    kernelModules = ["kvm-intel"];
    initrd.kernelModules = ["nvme"];
    initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "alcor"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/2D0D-AF74";
    fsType = "vfat";
  };

  fileSystems."/" = {
    device = "/dev/nvme0n1";
    fsType = "ext4";
  };
}
