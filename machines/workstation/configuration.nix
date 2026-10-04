{
  lib,
  username,
  ...
}:
{
  networking.hostName = "workstation";

  nixpkgs.hostPlatform = "x86_64-linux";

  # TEMPORARY default password, until the sops/vars secret store is provisioned.
  # Overrides the clan users-service password, whose var cannot be decrypted
  # yet: the machine's age key does not match the recipient the vars were
  # encrypted to. Remove this block once the vars decrypt again.
  users.users.nixolotl.hashedPasswordFile = lib.mkForce null;
  users.users.nixolotl.hashedPassword = "REDACTED-PASSWORD-HASH";

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

  networking.firewall.allowedTCPPorts = [ 1883 ]; # mosquitto
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        port = 1883;
        users.plant_monitor = {
          hashedPassword = "$7$101$Q0iK4Y2rnqvGfNyr$wi2LMXu5qzpigQaA1zcvB+vWWJ/azq/IH6Fpfmmee5IsM+/c1uh8STyzMJ55sOpwTQJp9UghQMC51ALgG6IqJw==";
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
