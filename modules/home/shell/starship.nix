{pkgs, ...}: {
  home.packages = with pkgs; [
    starship
  ];

  programs.starship = {
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
}
