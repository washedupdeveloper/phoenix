{
  pkgs,
  lib,
  username,
  ...
}: {
  home.packages = with pkgs; [lazygit];

  programs.git = let
    capitalize = s: with lib.strings; toUpper (substring 0 1 s) + substring 1 (-1) s;
  in {
    userName = lib.mkDefault capitalize username;
    userEmail = lib.mkDefault "31986015+washedupdeveloper@users.noreply.github.com";
    ignores = [".direnv/"];
    extraConfig = lib.mkDefault {
      # Does not allow merging. If just one property is replaced, the entire `extraConfig` disappears.
      pull.rebase = true;
      commit.gpgsign = true;
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      user.signingkey = "~/.ssh/id_ed25519.pub";
    };
  };
}
