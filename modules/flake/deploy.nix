{
  self,
  inputs,
  ...
}: let
  deployConfig = name: host: system: {
    hostname = host;
    profiles.system = {
      user = "root";
      sshUser = self.username;
      path = inputs.deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
    };
  };
in {
  flake.deploy.nodes = {
    racknerd = deployConfig "racknerd" "vps" "x86_64-linux";
    rpi = deployConfig "rpi" "192.168.0.183" "aarch64-linux";
  };
  flake.checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;
}
