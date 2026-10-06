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
    useDHCP = false;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  programs.nix-ld.enable = true;
  services.locate.enable = true;

  nix.gc.automatic = false;

  # These are per-host facts, not clan baseline: how much headroom a host has,
  # and how fast its link is, are properties of that host. Build parallelism was
  # raised from the original guardrail (max-jobs 2 / cores 4) to 6 x 2 = 12
  # threads, half of the host's 24 -- see docs/adr/0003.
  #
  # `download-buffer-size` is Nix's internal curl buffer, and it exists only to
  # stop substitutions stalling when a transfer outruns Nix's processing (the
  # "download buffer is full" warning). Nix 2.35 defaults it to 1 MiB; 500 MiB is
  # ~500x that, and above the 64 MiB that still warned on gigabit links. It is
  # allocated per transfer and `http-connections` defaults to 25, so raise it
  # only if that warning actually appears.
  nix.settings = {
    max-jobs = 6;
    cores = 2;
    download-buffer-size = 524288000;
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

  networking.firewall.allowedTCPPorts = [ 1883 ]; # mosquitto
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
