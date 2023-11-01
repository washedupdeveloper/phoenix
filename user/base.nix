{ pkgs, variables, ...}:
{
  imports = [
    ./modules/shell.nix
    ./modules/jsts.nix
    ./modules/elixir.nix
  ];

  home.username = variables.system.username;
  home.homeDirectory = "/home/${variables.system.username}";
  home.stateVersion = variables.system.stateVersion;
  home.packages = with pkgs; [
    zip
    unzip
    vim
    neovim
  ];

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      userName = variables.git.username;
      userEmail = variables.git.email;

      ignores = [ ".direnv/" ];

      # TODO: Figure out SSH vs GPG
      # signing = {
      #   signByDefault = true;
      #   key = variables.git.signingKey;
      # };

      extraConfig = {
        init.defaultBranch = "main";
        github.user = variables.github.username;
        # tag.gpgSign = true;
        safe.directory = "*";
      };
    };

    # gpg = {
    #   enable = true;
    #   settings = {
    #     keyid-format = "long";
    #   };
    # };

    ssh = {
      enable = true;
      extraConfig = ''
        AddKeysToAgent yes
      '';
    };
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentryFlavor = "tty";
  };
}
