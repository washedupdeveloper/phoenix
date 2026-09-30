{
  perSystem =
    { pkgs, ... }:
    {
      devshells.atomvm = {
        packages = with pkgs; [
          esptool
          elixir # bundles mix
          erlang
          rebar3
          screen
        ];
      };
    };
}
