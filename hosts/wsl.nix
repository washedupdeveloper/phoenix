{
  self,
  inputs,
  ...
}: {
  environment.systemPackages = [inputs.deploy-rs.packages."x86_64-linux".default];

  home-manager.users.${self.username}.imports = [
    ../modules/home/code/elixir
    ../modules/home/code/golang
    ../modules/home/code/javascript
    ../modules/home/code/vscode-extensions.nix
    ../modules/home/shell
    ../modules/home/git.nix
  ];

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = self.username;
    startMenuLaunchers = true;
    nativeSystemd = true;
    interop.register = true;
  };

  fileSystems."/home/${self.username}/.ssh" = {
    device = "C:\\Users\\${self.username}\\.ssh";
    fsType = "drvfs";
    options = ["rw" "noatime" "uid=1000" "gid=100" "case=off" "umask=0077" "fmask=0177"];
  };

  # for building raspberry pi builds
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
}
