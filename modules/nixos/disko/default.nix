{
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.modules.disko;
  fileSystems = {
    ext4 = import ./ext4.nix;
    btrfs = import ./btrfs.nix;
  };
in
  with lib; {
    imports = [inputs.disko.nixosModules.default];
    options.modules.disko = {
      enable = mkEnableOption "disko module";
      device = mkOption {
        type = types.str;
        default = null;
      };
      swapSizeInGb = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      fileSystem = mkOption {
        type = types.enum (attrNames fileSystems);
        default = "ext4";
      };
    };

    config = mkIf cfg.enable {
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
      disko = fileSystems.${cfg.fileSystem} {
        inherit lib;
        inherit (cfg) device swapSizeInGb;
      };
    };
  }
