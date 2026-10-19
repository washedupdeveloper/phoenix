{
  config,
  lib,
  username,
  homeManagerModule,
  ...
}:
let
  # Defined once: git and jj both read it, so an email change cannot land in one
  # tool and miss the other.
  identity = {
    name = lib.mkDefault (
      with lib.strings; toUpper (substring 0 1 username) + substring 1 (-1) username
    );
    email = lib.mkDefault "31986015+washedupdeveloper@users.noreply.github.com";
  };
  # git-only: jj has no `user.signingkey`, and sharing it gave jj a setting it ignores.
  gitSigningKey = lib.mkDefault "~/.ssh/id_ed25519.pub";
in
{
  imports = [ homeManagerModule ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit username identity gitSigningKey; };
    users.${username} = {
      # Per-user modules, on the home-manager axis.
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
