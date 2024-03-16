{pkgs, ...}: {
  home.packages = with pkgs; [
    fd
    file
    ripgrep
  ];

  programs = {
    fish = {
      enable = true;
      shellAliases = {
        cat = "bat -p";
        find = "fd";
        gc = "nix store gc";
        # lsd aliases enabled as per lsd.enableAliases in shell/default.nix
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

    bat.enable = true;
    lsd.enable = true;
    lsd.enableAliases = true;

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
