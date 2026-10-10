{
  lib,
  identity,
  gitSigningKey,
  ...
}:
{
  programs.git = {
    enable = true;
    ignores = [ ".direnv/" ];
    settings = {
      pull.rebase = lib.mkDefault true;
      commit.gpgsign = lib.mkDefault true;
      gpg.format = lib.mkDefault "ssh";
      gpg.ssh.allowedSignersFile = lib.mkDefault "~/.ssh/allowed_signers";
      user = identity // {
        signingkey = gitSigningKey;
      };
    };
  };
}
