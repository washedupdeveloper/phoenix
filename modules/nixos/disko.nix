{
  device ? "/dev/sda1",
  swapSizeInGb ? "8",
  ...
}: {
  disko.devices = {
    disk = {
      vdb = {
        type = "disk";
        inherit device;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "128M";
              type = "EF00";
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
                  "/nix" = {
                    mountOptions = ["compress-force=lz4" "noatime" "noxattr" "noacl"];
                    mountpoint = "/nix";
                  };
                  "/home" = {
                    mountOptions = ["compress-force=lz4"];
                    mountpoint = "/home";
                  };
                  "/var" = {
                    mountOptions = ["compress-force=lz4"];
                    mountpoint = "/var";
                  };
                  "/tmp" = {
                    mountOptions = ["compress-force=lz4"];
                    mountpoint = "/tmp";
                  };
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    swap = {
                      swapfile.size = "${swapSize}G";
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
