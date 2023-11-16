{
  pkgs,
  variables,
  ...
}: {
  imports = [
    ./modules/shell.nix
    ./modules/jsts.nix
    ./modules/elixir.nix
    ./modules/vscode
  ];

  home.username = variables.system.username;
  home.homeDirectory = "/home/${variables.system.username}";
  home.stateVersion = variables.system.homeStateVersion or "23.05";
  home.packages = with pkgs; [
    git
    curl
    wget
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
      ignores = [".direnv/"];
      # TODO: Figure out SSH vs GPG
      # signing = {
      #   signByDefault = true;
      #   key = variables.git.signingKey;
      # };
      extraConfig = {
        init.defaultBranch = "main";
        github.user = variables.git.github.username;
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

    # ssh = {
    #   enable = true;
    #   extraConfig = ''
    #     AddKeysToAgent yes
    #   '';
    # };
  };

  # services.gpg-agent = {
  #   enable = true;
  #   enableSshSupport = true;
  #   pinentryFlavor = "tty";
  # };
}
