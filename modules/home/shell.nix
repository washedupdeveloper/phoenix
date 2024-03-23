{
  config = {
    programs = {
      fish = {
        enable = true;
        shellAliases = {
          cat = "bat -p";
          find = "fd";
          gc = "nix store gc";
        };
      };
      starship = {
        enable = true;
        settings = {
          add_newline = false;
          nix_shell = {
            symbol = " ";
            format = "$symbol ";
          };
          hostname.format = "$hostname:";
          username.format = "$user@";
        };
      };
      bat.enable = true;
      lsd = {
        enable = true;
        enableAliases = true;
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
  };
}
