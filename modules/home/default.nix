{
  config,
  username,
  homeManagerModule,
  ...
}:
{
  imports = [ homeManagerModule ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit username; };
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
