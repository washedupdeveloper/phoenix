{
  lib,
  identity,
  ...
}:
{
  programs = {
    jujutsu = {
      enable = true;
      settings = {
        user = identity;
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
