{
  perSystem =
    { pkgs, ... }:
    {
      devshells.atomvm = {
        packages = with pkgs; [
          esptool
          beamPackages.elixir # bundles mix
          beamPackages.erlang
          beamPackages.rebar3
          screen
        ];
      };
    };
}
