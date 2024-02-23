{
  lib,
  device,
  swapSizeInGb,
  ...
}: {
  devices = {
    disk = {
      main = {
        type = "disk";
        inherit device;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              type = "EF00";
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"];
                subvolumes = {
                  "/rootfs" = {
                    mountpoint = "/";
                  };
                  "/home" = {
                    mountOptions = ["compress=zstd"];
                    mountpoint = "/home";
                  };
                  "/nix" = {
                    mountOptions = ["compress=zstd" "noatime"];
                    mountpoint = "/nix";
                  };
                  "/var" = {
                    mountOptions = ["compress=zstd"];
                    mountpoint = "/var";
                  };
                  "/swap" = lib.optionalAttrs (swapSizeInGb != null) {
                    mountpoint = "/.swapvol";
                    swap = {
                      swapfile.size = "${swapSizeInGb}G";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
