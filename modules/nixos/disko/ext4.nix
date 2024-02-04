{
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
                type = "filesystem";
                format = "ext4";
                swap = {
                  swapfile = {
                    size = "${swapSizeInGb}G";
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
