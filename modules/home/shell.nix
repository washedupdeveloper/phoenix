{ pkgs, ... }:
{
  home.packages = [
    pkgs.kubecolor
    pkgs.ripgrep
    pkgs.nerd-fonts.meslo-lg
  ];

  programs = {
    nix-your-shell = {
      enable = true;
      enableFishIntegration = true;
      nix-output-monitor.enable = true;
    };
    fish = {
      enable = true;
      shellAliases = {
        cat = "bat -p";
        find = "fd";
        gc = "nix store gc";
        kubectl = "kubecolor";
        nix = "nom";
      };
    };
    fd.enable = true;
    starship = {
      enable = true;
      settings = {
        add_newline = true;
        nix_shell = {
          symbol = " ";
          format = "$symbol ";
        };
        hostname.format = "$hostname:";
        username.format = "$user@";
      };
    };
    bat.enable = true;
    eza.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableFishIntegration = true;
    };
    # fzf = {
    #   enable = true;
    #   enableFishIntegration = true;
    #   fileWidget.options = [ "--preview 'bat --color=always {}'" ];
    # };
    atuin = {
      enable = true;
      enableFishIntegration = true;
    };
    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
    delta = {
      enable = true;
      enableGitIntegration = true;
    };
  };
}
