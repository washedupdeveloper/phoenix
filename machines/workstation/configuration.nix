{
  lib,
  username,
  ...
}:
{
  networking.hostName = "workstation";

  nixpkgs.hostPlatform = "x86_64-linux";

  programs.nix-ld.enable = true;
  services.locate.enable = true;

  nix.gc.automatic = false;

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

  # This machine is a NixOS-WSL guest, not a physical box: the CPU/GPU in the
  # diagram belong to the Windows host that runs it (see ./topology.nix).
  topology.self = {
    # `parent` is what makes nix-topology draw this node as a guest of the
    # Windows host rather than as a free-standing machine. `guestType` is a
    # free-form string -- "microvm" and "nixos-container" are the built-in
    # values -- and only feeds the default hardware info.
    parent = "windows-host";
    guestType = "wsl";
    hardware.info = "NixOS-WSL (WSL2)";

    interfaces.wsl0 = {
      # The other end of this link is `windows-host.interfaces.wsl-switch`.
      network = "wsl-nat";

      # The NIC is virtual, and its link type is ordinary ethernet. "veth" is
      # not a nix-topology interface type, so naming it here only costs the
      # interface its icon.
      virtual = true;
      type = "ethernet";
    };

    services.mosquitto = lib.mkForce {
      name = "Mosquitto";
      icon = "services.mosquitto";
      details."listen[0]".text = "1883";
    };
  };
}
