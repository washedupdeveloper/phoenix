{
  pkgs,
  variables,
  ...
}: {
  home.packages = with pkgs; [
    git
    lazygit
  ];

  programs.git = {
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
}
