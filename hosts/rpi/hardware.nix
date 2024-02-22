{lib, ...}: {
  networking.useDHCP = lib.mkDefault true;

  boot = {
    initrd.availableKernelModules = ["xhci_pci"];
    initrd.kernelModules = [];
    kernelModules = [];
    extraModulePackages = [];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  hardware.enableRedistributableFirmware = true;
}
