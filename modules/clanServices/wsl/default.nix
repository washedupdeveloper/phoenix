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

          # systemd-binfmt was disabled here on the claim that binfmt_misc's status
          # file is read-only under WSL, so it could not apply binfmt.d rules.
          # Measured 2026-10-20: it applies them and exits 0 -- flushing the
          # pre-existing rules fails with EROFS, which systemd treats as a warning --
          # and the `aarch64-linux` entry it registers is what makes
          # `boot.binfmt.emulatedSystems` work on this guest. `interop.register` above
          # stops being inert with it: WSLInterop has to stay declared in binfmt.d or
          # `.exe` execution is at the mercy of that same flush (verified working
          # after the switch that enabled this service).

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

          # nixos-wsl enables this for WSLg's GPU acceleration. Nothing here runs a
          # GUI program and the stack is ~0.8 GiB of the closure. Delete to restore.
          hardware.graphics.enable = lib.mkForce false;
        };
    };
  };
}
