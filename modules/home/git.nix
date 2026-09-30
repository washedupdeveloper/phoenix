{
  lib,
  username,
  ...
}:
{
  programs.git =
    let
      capitalize = s: with lib.strings; toUpper (substring 0 1 s) + substring 1 (-1) s;
    in
    {
      enable = true;
      ignores = [ ".direnv/" ];
      settings = {
        pull.rebase = lib.mkDefault true;
        commit.gpgsign = lib.mkDefault true;
        gpg.format = lib.mkDefault "ssh";
        gpg.ssh.allowedSignersFile = lib.mkDefault "~/.ssh/allowed_signers";
        user = {
          signingkey = lib.mkDefault "~/.ssh/id_ed25519.pub";
          name = lib.mkDefault (capitalize username);
          email = lib.mkDefault "31986015+washedupdeveloper@users.noreply.github.com";
        };
      };
    };
}
