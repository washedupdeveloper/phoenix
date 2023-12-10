{pkgs, ...}: {
  imports = [
    ./fish.nix
    ./starship.nix
  ];

  home.packages = with pkgs; [
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
