{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    fish
    starship
    fd
    lsd
    file
    fzf
    bat
    ripgrep
    direnv
  ];

  programs = {
    bat.enable = true;
    lsd.enable = true;
    lsd.enableAliases = true;

    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting
        bind -k nul -M insert 'accept-autosuggestion'
        sops -d ${config.sops.secrets.ssh_password.path} | ssh-add ~/.ssh/id_ed25519
      '';
      shellAliases = {
        cat = "bat -p";
        find = "fd";
        gc = "nix store gc";
        # lsd aliases enabled as per lsd.enableAliases
      };
    };

    starship = {
      enable = true;
      settings = {
        add_newline = false;
        nix_shell = {
          symbol = " ";
          format = "[$symbol]($style) ";
        };
        hostname.format = "[$hostname]($style):";
        username.format = "[$user]($style)@";
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    fzf = {
      enable = true;
      fileWidgetOptions = ["--preview 'bat --color=always {}'"];
    };
  };
}
