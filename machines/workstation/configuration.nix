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
    # Load-bearing, not cosmetic: the address comes from WSL mirrored
    # networking on the Windows host, and leaving useDHCP at its default
    # would make nixpkgs generate a Match-all DHCP client that competes
    # with the host for the lease.
    useDHCP = false;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  programs.nix-ld.enable = true;

  # Overrides base-system's `nix.gc.automatic = mkDefault true`, which makes
  # its gc.dates and gc.options inert here: `programs.nh.clean` below does
  # the same job with a keep-policy, and running both would duplicate it.
  nix.gc.automatic = false;

  # These are per-host facts, not clan baseline: how much headroom a host has,
  # and how fast its link is, are properties of that host.
  #
  # Build parallelism is left entirely to the defaults, because on NixOS the
  # defaults already mean "use the machine":
  #
  #   nix.settings.max-jobs  module default = "auto"  -> nproc (12 here)
  #   nix.settings.cores     module default = 0       -> NIX_BUILD_CORES=nproc
  #
  # Setting either one restates a default, and the previous hardcoded pair was
  # actively wrong in the second field: `cores = 1` is a DOWNGRADE from 0, forcing
  # every parallel-capable build (cargo, make -j, gcc) to one thread. `cores = 0`
  # is the "use all cores" value, not the conservative one.
  #
  # The trap worth recording, because it is where a careful reader goes wrong: the
  # bare nix.conf default for max-jobs is 1, so "delete the setting" looks like it
  # would serialize builds. On NixOS it does not -- the module injects "auto". Both
  # statements are true and they are about different layers; only the module one
  # governs this machine.
  #
  # Worst case is therefore 12 jobs x 12 threads. Most nixpkgs derivations ignore
  # NIX_BUILD_CORES (enableParallelBuilding is opt-in), so the realistic load is
  # one thread per job. For a build that is both parallel and memory-hungry
  # (Electron, rust), bound it at the invocation, which is the only place that
  # knows: `--cores 8`. Peak memory is still capped by `.wslconfig`
  # (memory=16GB, swap=8GB); `autoMemoryReclaim=gradual` returns idle page cache
  # to Windows, it does not raise that ceiling, so it is not headroom to spend.
  #
  # The history matters more than the number: this was `2 x 4`, then `6 x 2`, as a
  # DIAGNOSTIC guardrail while the host was powering off under load. The power-off
  # was traced to host firmware rather than to build load, and the host has been up
  # for days since, so the guardrail's reason has expired. Do not confuse that with
  # the separate core-count fault: `X3D Gaming Mode` was powering down a CCD and
  # disabling SMT, which is why the VM once presented 6 cores / 6 threads. That was
  # a different symptom, fixed by disabling the mode -- see docs/adr/0003, whose
  # Context says so explicitly.
  #
  # What remains is the memory ceiling above, which is a fact about the VM.
  #
  # `download-buffer-size` is deliberately NOT set. Nix 2.33 fixed the root
  # cause of the "download buffer is full" warning with libcurl write pausing
  # and lowered the default to 1 MiB, stating it is no longer recommended to
  # raise it. The pinned Nix is 2.35.2.

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 4";
    flake = "/home/${username}/projects/phoenix";
  };

  # The broker credential lives in the clan vars store, not in this file: the
  # generator below mints it once and only the hash is deployed, handed to
  # mosquitto through systemd credentials. No secret is ever committed.
  # Retrieve the plaintext for the device with
  #   clan vars get workstation mosquitto-plant-monitor/plant-monitor-password
  # Docs: https://clan.lol/docs/26.05/guides/vars/vars-custom-generators
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

  # The broker stays reachable from the LAN -- the plant monitor is a separate
  # device -- and 1883 is written as an `eth0` rule rather than a bare
  # `allowedTCPPorts` entry, because `networkingMode=mirrored` in .wslconfig
  # makes this guest share the Windows host's interfaces and the bare form would
  # cover all of them.
  #
  # THIS RULE DOES NOTHING TODAY. nixos-wsl disables the unit outright
  # (`systemd.services.firewall.enable = false` in its `modules/systemd`), so
  # `networking.firewall.*` is inert on any WSL machine and this guest runs no
  # firewall at all. The exposure is accepted deliberately: the broker belongs
  # to a proof of concept and forcing the firewall on over nixos-wsl would risk
  # the guest's networking for one service's port. The rule is kept in the
  # narrow form so it is already correct if that changes:
  #   systemd.services.firewall.enable = lib.mkForce true;
  #
  # Three things that acceptance does not say, recorded so it is not narrower
  # than what it covers:
  #   - It is not only the broker. With the unit off every listener is open, and
  #     `base-system` asks for sshd as well (`services.openssh.openFirewall`
  #     yields `allowedTCPPorts = [ 22 ]`): :22 and :1883 both accept from
  #     anywhere the host is reachable.
  #   - The credential does not protect the wire. The listener sets no
  #     `cafile`/`certfile`/`keyfile`, so MQTT is cleartext and the password is
  #     readable in transit. It bounds an active guesser, not a passive
  #     listener.
  #   - "LAN" means whatever the Windows host is exposed to. Mirrored
  #     networking shares the host's interfaces, so the reach is the host's
  #     reach -- including any interface it bridges or VPNs.
  networking.firewall.interfaces.eth0.allowedTCPPorts = [ 1883 ];
  services = {
    # `prunePaths` REPLACES the nixpkgs default rather than extending it, so the
    # default entries are restated here -- keep them in step with
    # nixos/modules/misc/locate.nix. /mnt holds the host's volumes as 9p mounts
    # (c, d, e, f), and indexing those from the guest is slow and useless.
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

  # A NixOS-WSL guest, not a physical box: the CPU/GPU in the diagram belong to
  # the Windows host running it (see ../../topology.nix).
  topology.self = {
    parent = "windows-host";
    guestType = "wsl";
    hardware.info = "NixOS-WSL (WSL2)";

    # `networkingMode=mirrored` on the host: the guest shares the host's
    # interfaces, so this NIC carries its own address on the LAN rather than one
    # on a NAT segment. WSL assigns it, not the guest -- see `useDHCP = false`
    # above.
    interfaces.wsl0 = {
      network = "lan";
      virtual = true;
      type = "ethernet";
      addresses = [ "192.168.68.108/24" ];
      gateways = [ "192.168.68.1" ];
    };

    # Overrides only the rendered text, to work around an upstream nix-topology
    # bug in its mosquitto extractor. Not a description of the service; the
    # broker's own configuration is unchanged. See docs/adr/0002.
    services.mosquitto = lib.mkForce {
      name = "Mosquitto";
      icon = "services.mosquitto";
      details."listen[0]".text = "1883";
    };
  };
}
