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
  services.locate.enable = true;

  # Overrides base-system's `nix.gc.automatic = mkDefault true`, which makes
  # its gc.dates and gc.options inert here: `programs.nh.clean` below does
  # the same job with a keep-policy, and running both would duplicate it.
  nix.gc.automatic = false;

  # These are per-host facts, not clan baseline: how much headroom a host has,
  # and how fast its link is, are properties of that host. Build parallelism was
  # raised from the original guardrail (max-jobs 2 / cores 4) to 6 x 2 = 12
  # threads, half of the host's 24 -- see docs/adr/0003.
  #
  # `download-buffer-size` is deliberately NOT set. Nix 2.33 fixed the root
  # cause of the "download buffer is full" warning with libcurl write pausing
  # and lowered the default to 1 MiB, stating it is no longer recommended to
  # raise it. The pinned Nix is 2.35.2.
  nix.settings = {
    max-jobs = 6;
    cores = 2;
  };

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
      xkcdpass --numwords 6 --delimiter - --count 1 | tr -d "\n" > "$out"/plant-monitor-password
      mosquitto_passwd -c -b "$out"/plant-monitor-passwd plant_monitor "$(cat "$out"/plant-monitor-password)"
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
  # to a proof of concept, it still requires the vars-backed credential, and
  # forcing the firewall on over nixos-wsl would risk the guest's networking for
  # a LAN-only port. The rule is kept in the narrow form so it is already
  # correct if that changes:
  #   systemd.services.firewall.enable = lib.mkForce true;
  networking.firewall.interfaces.eth0.allowedTCPPorts = [ 1883 ];
  services.mosquitto = {
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

  # A NixOS-WSL guest, not a physical box: the CPU/GPU in the diagram belong to
  # the Windows host running it (see ../../topology.nix).
  topology.self = {
    parent = "windows-host";
    guestType = "wsl";
    hardware.info = "NixOS-WSL (WSL2)";

    interfaces.wsl0 = {
      network = "wsl-nat";
      virtual = true;
      type = "ethernet";
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
