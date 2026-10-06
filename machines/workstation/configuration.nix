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

  # Build parallelism is capped per machine, not in `base-system`: how much
  # headroom a host has is a property of that host. Raised from the original
  # guardrail (max-jobs 2 / cores 4) to 6 x 2 = 12 threads, half of the host's
  # 24. See docs/adr/0003.
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
