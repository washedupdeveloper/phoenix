{
  _class = "clan.service";
  manifest = {
    name = "wsl";
    description = "NixOS-WSL specific configuration (interop, launchers).";
    categories = [ "System" ];
    readme = ''
      Layers NixOS-WSL specifics onto machines tagged "wsl".
    '';
  };

  roles.default = {
    description = "The single WSL-machine role.";

    perInstance = _: {
      nixosModule =
        {
          pkgs,
          lib,
          config,
          username,
          nixosWslModule, # from `clan.specialArgs` in flake.nix
          ...
        }:
        let
          usbipAutoAttachBin = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/dorssel/usbipd-win/v5.3.0/Usbipd/WSL/x64/usbip-auto-attach";
            hash = "sha256-o+TxM/YyMIfWYCK28KbInzYK3aGxV4gu8T3fx6TVh/w=";
            executable = true;
          };
        in
        {
          imports = [ nixosWslModule ];

          environment.systemPackages = with pkgs; [
            coreutils
            usbutils
          ];

          systemd.services."usbip-auto-attach@".script = lib.mkForce ''
            busid="$1"
            ip="${config.wsl.usbip.snippetIpAddress}"
            echo "Starting auto attach for busid $busid on $ip."
            exec ${usbipAutoAttachBin} "$ip" --busid "$busid" --usbip-path "${pkgs.linuxPackages.usbip}/bin/usbip"
          '';

          # WSL exposes binfmt_misc with a read-only status file, so systemd's
          # binfmt service can never apply binfmt.d rules and fails at boot.
          # Nothing here registers binary formats, so it is disabled.
          systemd.services.systemd-binfmt.enable = false;

          wsl = {
            enable = true;
            defaultUser = username;
            wslConf = {
              user.default = username;
              automount.root = "/mnt";
              network.generateResolvConf = true;
            };
            startMenuLaunchers = true;
            interop.register = true;
            useWindowsDriver = true;
            usbip.enable = true;
            usbip.autoAttach = [ "3-9" ];
          };

          services.resolved.enable = lib.mkForce false;
        };
    };
  };
}
