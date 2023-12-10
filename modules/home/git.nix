{pkgs, ...}: {
  home.packages = with pkgs; [
    git
    lazygit
  ];

  programs.git = {
    enable = true;
    userName = "Storm";
    userEmail = "31986015+washedupdeveloper@users.noreply.github.com";
    ignores = [".direnv/"];
    extraConfig = {
      pull.rebase = true;
      commit.gpgsign = true;
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      user.signingkey = "~/.ssh/id_ed25519.pub";
    };
  };
}
