{
  config,
  lib,
  ...
}: let
  cfg = config.services.disko;
  fileSystems = {
    ext4 = import ./ext4.nix;
    btrfs = import ./btrfs.nix;
  };
in {
  options.services.disko = {
    enable = lib.mkEnableOption "disko service";
    device = lib.mkOption {type = lib.types.str;};
    swapSizeInGb = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    fileSystem = lib.mkOption {
      type = lib.types.enum (lib.attrNames fileSystems);
      default = "ext4";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.device != null;
        message = "The 'device' option in 'services.disko' must be set.";
      }
      {
        assertion = lib.hasAttr cfg.fileSystem fileSystems;
        message = "The 'fileSystem' option in 'services.disko' must be a valid filesystem.";
      }
    ];
    disko = lib.optionalAttrs cfg.enable (fileSystems.${cfg.fileSystem} {inherit lib device swapSizeInGb;});
  };
}
