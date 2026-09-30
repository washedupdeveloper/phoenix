{
  pkgs,
  settings,
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

  topology.self = {
    hardware.info = "AMD Ryzen 9 9900X3D / RX 9070 XT";
    interfaces.wsl0 = {
      network = "lan";
      type = "veth";
    };
  };
}
