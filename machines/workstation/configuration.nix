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

  # `nix.settings.max-jobs` / `cores` stay unset on purpose: the NixOS defaults
  # mean "use the machine", and `cores = 1` is a downgrade, not a safety margin.
  # Traps and measurement: docs/adr/0003.
  #
  # `download-buffer-size` is likewise unset: Nix 2.33 fixed the warning at source.

  # `aarch64-linux` is in the flake's `systems`, so the gate has to BUILD aarch64
  # derivations on this host -- without a builder for that platform nix refuses with
  # "a 'aarch64-linux' ... is required to build ... but I am a 'x86_64-linux'".
  # qemu-user through the kernel's binfmt_misc, registered by systemd-binfmt on
  # activation; the module also adds the platform to `nix.settings.extra-platforms`.
  # Measured: the same rebuilt check takes 8.6s against 8.3s native (the aarch64 leg is
  # evaluation and trivial builders, so emulation is not what it costs); see
  # docs/testing.md for the tier split that keeps a compiled kernel off it.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

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

    # Mirrored networking: the guest's eth0 presents the host's address, so there is
    # no guest-specific address to record and the host's is a 3-hour DHCP lease
    # (../../topology.nix). The link is what the diagram needs.
    interfaces.eth0 = {
      network = "lan";
      virtual = true;
      type = "ethernet";
      gateways = [ "192.168.68.1" ];
    };

    # `details` only, recomputed null-safely for every listener. The extractor reads
    # `l.address or "[::]"`, which falls back only when the attribute is ABSENT --
    # nixpkgs declares it `nullOr str` defaulting to `null`, so a listener that sets
    # no address interpolates null and the whole topology fails to evaluate
    # (`cannot coerce null to a string`, docs/adr/0002). Overriding `details` with
    # `mkForce` stops the extractor's own thunk from being evaluated, so `name`,
    # `icon` and `id` still come from the extractor and only this field is ours.
    services.mosquitto.details = lib.mkForce (
      lib.listToAttrs (
        lib.imap0 (i: l: {
          name = "listen[${toString i}]";
          value.text = "${if l.address == null then "[::]" else l.address}:${toString l.port}";
        }) config.services.mosquitto.listeners
      )
    );
  };

  # --- CI -------------------------------------------------------------------------
  #
  # The gate runs here and nowhere else, because the e2e tier needs `/dev/kvm` and
  # GitHub-hosted runners have none: they would skip the VM tests while reporting
  # green over a smaller gate than a commit runs locally. The workflow that asks for
  # this runner is `.github/workflows/gate.yml`, and its label is `kvm`.
  #
  # The token is asked for rather than written down: a fine-grained PAT with
  # `Administration: read and write` on the repository. `persist` stores the answer as
  # the secret var `token` -- equivalent to `cp $prompts/token $out/token`, so this
  # generator needs no script:
  #
  #   clan vars generate workstation --generator github-runner-token
  #   clan vars generate workstation --generator github-runner-token --regenerate
  #
  # The second form replaces a revoked token. Until a real one is generated the
  # runner starts and fails to register, which is visible in
  # `journalctl -u github-runner-gate` and is the only symptom.
  clan.core.vars.generators.github-runner-token.prompts.token = {
    description = "GitHub fine-grained PAT (Administration: read and write) for the runner";
    type = "hidden";
    persist = true;
  };

  services.github-runners.gate = {
    enable = true;
    url = "https://github.com/washedupdeveloper/phoenix";
    name = "workstation-gate";
    tokenFile = config.clan.core.vars.generators.github-runner-token.files.token.path;
    extraLabels = [ "kvm" ];
    # The PAT outlives a single registration, so an existing runner of the same name
    # is replaced on start; without it a restart fails against the stale registration
    # it left behind. Nothing is lost: a runner holds no state between jobs.
    replace = true;
  };
}
