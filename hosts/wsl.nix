{
  pkgs,
  config,
  inputs,
  username,
  ...
}: {
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    ../modules/nixos/podman
    ../modules/nixos/k3s
  ];
  home-manager.users.${username} = {
    imports = [../modules/home/git.nix];

    enableNodeJs = true;
    enableNodeJsPkgs = true;
    enableGolang = true;
    enableElixir = true;
  };

  environment.systemPackages = with pkgs; [deploy-rs];
  networking.hostName = "wsl";

  programs.fish.interactiveShellInit = ''
    set fish_greeting
    bind -k nul -M insert 'accept-autosuggestion'
    set -Ux GIT_ASKPASS ""
    ssh-add ~/.ssh/id_ed25519
  '';

  modules = {
    podman.enable = true;
    # k3s.enable = true;
  };
  services.k3s = {
    enable = true;
    role = "server";
    # disableAgent = true;
    tokenFile = config.sops.secrets.k3s_token.path;
    extraFlags = toString [
      "--node-name ${config.networking.hostName}"
      "--node-ip 100.70.39.20"
    ];
  };

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    wslConf.user.default = username;
    defaultUser = username;
    startMenuLaunchers = true;
    nativeSystemd = true;
    interop.register = true;
    useWindowsDriver = true;
  };

  fileSystems."/home/${username}/.ssh" = {
    device = "C:\\Users\\${username}\\.ssh";
    fsType = "drvfs";
    options = ["rw" "noatime" "uid=1000" "gid=100" "case=off" "umask=0077" "fmask=0177"];
  };

  # for building raspberry pi builds
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
}
