{
  config,
  lib,
  username,
  homeManagerModule,
  ...
}:
let
  # The user identity, defined ONCE. git and jj both read it, so changing an
  # email or a signing key cannot land in one tool and miss the other -- which
  # is what two verbatim copies of it guaranteed.
  identity = {
    name = lib.mkDefault (
      with lib.strings; toUpper (substring 0 1 username) + substring 1 (-1) username
    );
    email = lib.mkDefault "31986015+washedupdeveloper@users.noreply.github.com";
    signingkey = lib.mkDefault "~/.ssh/id_ed25519.pub";
  };
in
{
  imports = [ homeManagerModule ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit username identity; };
    users.${username} = {
      home = {
        inherit username;
        homeDirectory = "/home/${username}";
        inherit (config.system) stateVersion;
      };
      programs.home-manager.enable = true;
      services.ssh-agent.enable = true;
    };
  };
}
