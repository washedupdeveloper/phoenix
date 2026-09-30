{
  lib,
  username,
  ...
}:
{
  programs = let
    capitalize = s: with lib.strings; toUpper (substring 0 1 s) + substring 1 (-1) s;
  in {
    jujutsu = {
      enable = true;
      settings = {
        user = {
          name = lib.mkDefault (capitalize username);
          email = lib.mkDefault "31986015+washedupdeveloper@users.noreply.github.com";
          signingkey = lib.mkDefault "~/.ssh/id_ed25519.pub";
        };
        # template = {
        #   aliases = {
        #     format_short_id = lib.mkDefault "id.shortest(12)";
        #   };
        # };
        colors = {
          commit_id_prefix = lib.mkDefault { bold = true; };
        };
      };
    };
    jjui.enable = true;
  };
}
