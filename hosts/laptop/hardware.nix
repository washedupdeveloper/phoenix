{
  lib,
  config,
  ...
}: {
  services.xserver.videoDrivers = ["nvidia"];

  services.printing.enable = true;
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      powerManagement.enable = false;
      # Fine-grained power management. Turns off GPU when not in use. Experimental and only works on modern Nvidia GPUs (Turing or newer).
      powerManagement.finegrained = false;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      prime = {
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

  # boot = {
  #   initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "alcor"];
  #   initrd.kernelModules = [];
  #   kernelModules = ["kvm-intel"];
  #   extraModulePackages = [];
  # };

  # fileSystems = lib.mkDefault {
  #   "/" = {
  #     device = "/dev/disk/by-uuid/a6985ab0-bcec-4f8f-8844-2ab240ae4763";
  #     fsType = "ext4";
  #   };
  #   "/boot" = {
  #     device = "/dev/disk/by-uuid/BD71-8998";
  #     fsType = "vfat";
  #   };
  # };
  # swapDevices = lib.mkDefault [
  #   {
  #     device = "/dev/disk/by-uuid/3d79940c-9ac3-40a4-8d85-22761cebfb9b";
  #     # size = 16 * 1024
  #   }
  # ];

  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
