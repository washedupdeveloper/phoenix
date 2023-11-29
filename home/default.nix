{
  pkgs,
  variables,
  ...
}: {
  imports = [
    ./modules/code/vscode-extensions.nix
    ./modules/code/elixir
    ./modules/code/go
    ./modules/code/javascript
    ./modules/shell
    ./modules/git.nix
    ./modules/sops.nix
  ];

  home.username = variables.system.username;
  home.homeDirectory = "/home/${variables.system.username}";
  home.stateVersion = variables.system.homeStateVersion or "23.05";
  home.packages = with pkgs; [
    curl
    wget
    zip
    unzip
  ];

  programs.home-manager.enable = true;
  services.ssh-agent.enable = true;
}
