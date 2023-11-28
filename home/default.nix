{
  pkgs,
  config,
  inputs,
  variables,
  ...
}: {
  imports = [
    ./modules/code/vscode-extensions.nix
    ./modules/code/elixir
    ./modules/code/go
    ./modules/code/javascript
    ./modules/shell
  ];

  sops = {
    defaultSopsFile = ../secrets/system.yaml;
    age.keyFile = "/home/${variables.system.username}/.config/sops/age/keys.txt";
    secrets.ssh_password = {};
  };

  home.username = variables.system.username;
  home.homeDirectory = "/home/${variables.system.username}";
  home.stateVersion = variables.system.homeStateVersion or "23.05";
  home.packages = with pkgs; [
    git
    curl
    wget
    zip
    unzip
  ];

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      userName = variables.git.username;
      userEmail = variables.git.email;
      ignores = [".direnv/"];
      extraConfig = {
        commit.gpgsign = true;
        gpg.format = "ssh";
        gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        user.signingkey = "~/.ssh/id_ed25519.pub";
      };
    };
  };

  services.ssh-agent.enable = true;
}
