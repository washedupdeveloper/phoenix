{
  pkgs,
  config,
  inputs,
  username,
  ...
}: {
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    ../modules/nixos/k3s
    ../modules/nixos/podman
  ];
  home-manager.users.${username} = {
    imports = [../modules/home/git.nix];

    enableGlobalNodeJs = true;
    enableGlobalNodeJsPkgs = true;
    enableGlobalGolang = true;
    enableGlobalElixir = true;
  };

  networking.hostName = "wsl";

  environment.systemPackages = with pkgs; [deploy-rs];

  programs.fish.interactiveShellInit = ''
    set fish_greeting
    bind -k nul -M insert 'accept-autosuggestion'
    set -Ux GIT_ASKPASS ""
    ssh-add ~/.ssh/id_ed25519
  '';

  services.k3s-self = {
    enable = true;
    enableHelm = true;
    extraFlags = [
      "--node-name ${config.networking.hostName}"
      # "--disable servicelb"
      # "--disable traefik"

      # "--disable local-storage"
      # "--disable metrics-server"
      # "--disable-kube-proxy"
      # "--service-cidr cidr_address_here"
      # "--cluster-cidr cidr_address_here"
      # "--cluster-dns cluster_dns_here";
    ];
  };

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = username;
    startMenuLaunchers = true;
    nativeSystemd = true;
    interop.register = true;
  };

  fileSystems."/home/${username}/.ssh" = {
    device = "C:\\Users\\${username}\\.ssh";
    fsType = "drvfs";
    options = ["rw" "noatime" "uid=1000" "gid=100" "case=off" "umask=0077" "fmask=0177"];
  };

  # for building raspberry pi builds
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
}
