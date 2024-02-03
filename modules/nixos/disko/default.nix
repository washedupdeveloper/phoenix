{
  lib,
  config,
  ...
}: let
  cfg = config.local.disko;

  importDisk = name:
    lib.mkIf cfg.enable
    && (cfg.partitionScheme == name) {
      disko =
        import ./.
        + "${name}.nix" {
          device = cfg.device;
          swapSizeInGb = cfg.swapSizeInGb;
        };
    };
in {
  options.local.disko = {
    enable = lib.mkEnableOption "disko partitioning";
    device = lib.mkOption {
      types = with lib.types; nullOr str;
      default = null;
    };
    partitionScheme = lib.mkOption {
      types = with lib.types; nullOr str;
      default = null;
    };
    swapSizeInGb = lib.mkOption {
      types = with lib.types; nullOr str;
      default = null;
    };
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.device == null;
          message = "device must be set";
        }
        {
          assertion = cfg.partitionScheme == null;
          message = "partitionScheme must be set";
        }
      ];
    })
    # (importDisk "btrfs")
    (importDisk "ext4")
  ];
}
