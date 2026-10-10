{
  config,
  lib,
  username,
  homeManagerModule,
  ...
}:
let
  # The user identity, defined ONCE. git and jj both read it, so changing an
  # email cannot land in one tool and miss the other -- which is what two
  # verbatim copies of it guaranteed.
  identity = {
    name = lib.mkDefault (
      with lib.strings; toUpper (substring 0 1 username) + substring 1 (-1) username
    );
    email = lib.mkDefault "31986015+washedupdeveloper@users.noreply.github.com";
  };
  # git-only, so it stays out of the shared blob: jj has no `user.signingkey`
  # (its signing is `signing.backend` plus `signing.key`), and passing git's
  # key through the shared attrset gave jj a setting it does not understand.
  gitSigningKey = lib.mkDefault "~/.ssh/id_ed25519.pub";
in
{
  imports = [ homeManagerModule ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit username identity gitSigningKey; };
    users.${username} = {
      # The per-user module set, on the home-manager axis. It used to live in
      # clan.nix's importer as an inline lambda, which split one concern
      # across two files.
      imports = [
        ./git.nix
        ./jj.nix
        ./shell.nix
      ];
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
