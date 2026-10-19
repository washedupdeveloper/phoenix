{
  config,
  lib,
  pkgs,
  username,
  ...
}:
{
  networking = {
    hostName = "workstation";
    # Mirrored networking supplies the address from the Windows host; a default
    # DHCP client would compete with it for the lease.
    useDHCP = false;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  programs.nix-ld.enable = true;

  # Overrides base-system's mkDefault; `programs.nh.clean` below does the same job
  # with a keep-policy, and running both would duplicate it.
  nix.gc.automatic = false;

  # Build parallelism is deliberately unset: the NixOS defaults (`max-jobs =
  # "auto"`, `cores = 0`) already resolve to nproc. Setting `cores = 1` would force
  # every parallel-capable build onto a single thread.
  #
  # `download-buffer-size` is likewise unset: Nix 2.33 fixed the warning at source.

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 4";
    flake = "/home/${username}/projects/phoenix";
  };

  # The broker credential lives in the clan vars store: this generator mints it and
  # only the hash is deployed. Plaintext for the device:
  #   clan vars get workstation mosquitto-plant-monitor/plant-monitor-password
  clan.core.vars.generators.mosquitto-plant-monitor = {
    files.plant-monitor-password.deploy = false;
    files.plant-monitor-password-hash.neededFor = "services";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.mosquitto
      pkgs.xkcdpass
    ];

    script = ''
      # `-U` hashes a plaintext `user:password` file in place. The `-b` form
      # would put the secret in argv instead, where /proc/<pid>/cmdline stays
      # world-readable for the life of the process. The plaintext file is built
      # by redirection, so it never becomes an argument either. `umask` comes
      # first so that file is 0600 for the moment it exists.
      umask 077
      xkcdpass --numwords 6 --delimiter - --count 1 | tr -d "\n" > "$out"/plant-monitor-password
      { printf 'plant_monitor:'; cat "$out"/plant-monitor-password; printf '\n'; } > "$out"/plant-monitor-passwd
      mosquitto_passwd -U "$out"/plant-monitor-passwd
      cut -d: -f2 "$out"/plant-monitor-passwd > "$out"/plant-monitor-password-hash
      rm "$out"/plant-monitor-passwd
    '';
  };

  # Inert on WSL: nixos-wsl sets `systemd.services.firewall.enable = false`, so
  # this rule is not enforced and every listener is open -- :22 from base-system and
  # :1883 here -- to whatever the Windows host is exposed to, mirrored networking
  # meaning the host's reach. Accepted for a proof-of-concept broker. MQTT is
  # cleartext (no cafile/certfile), so the password bounds a guesser, not a passive
  # listener. Written as an eth0 rule so it is already correct if the unit is forced
  # on: `systemd.services.firewall.enable = lib.mkForce true;`
  networking.firewall.interfaces.eth0.allowedTCPPorts = [ 1883 ];
  services = {
    # `prunePaths` replaces the nixpkgs default rather than extending it, so the
    # default entries are restated here. /mnt holds the host's 9p volumes.
    locate = {
      enable = true;
      prunePaths = [
        "/mnt"
        "/tmp"
        "/var/tmp"
        "/var/cache"
        "/var/lock"
        "/var/run"
        "/var/spool"
        "/nix/store"
        "/nix/var/log/nix"
      ];
    };

    mosquitto = {
      enable = true;
      listeners = [
        {
          port = 1883;
          users.plant_monitor = {
            hashedPasswordFile =
              config.clan.core.vars.generators.mosquitto-plant-monitor.files.plant-monitor-password-hash.path;
            acl = [ "readwrite plants/#" ];
          };
        }
      ];
    };
  };

  # A WSL guest: the CPU/GPU in the diagram belong to the Windows host (../../topology.nix).
  topology.self = {
    parent = "windows-host";
    guestType = "wsl";
    hardware.info = "NixOS-WSL (WSL2)";

    # WSL assigns this address, not the guest -- hence `useDHCP = false` above.
    interfaces.wsl0 = {
      network = "lan";
      virtual = true;
      type = "ethernet";
      addresses = [ "192.168.68.108/24" ];
      gateways = [ "192.168.68.1" ];
    };

    # Overrides rendered text only, working around a nix-topology mosquitto bug
    # (docs/adr/0002). The broker's own configuration is unchanged.
    services.mosquitto = lib.mkForce {
      name = "Mosquitto";
      icon = "services.mosquitto";
      details."listen[0]".text = "1883";
    };
  };
}
