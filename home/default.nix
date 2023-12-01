{
  pkgs,
  variables,
  ...
}: {
  imports = [
    ./modules/sops.nix
    ./modules/code/elixir
    ./modules/code/go
    ./modules/code/javascript
    ./modules/code/vscode-extensions.nix
    ./modules/shell
    ./modules/git.nix
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
