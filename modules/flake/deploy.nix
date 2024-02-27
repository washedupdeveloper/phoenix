{
  self,
  inputs,
  username,
  ...
}: let
  deployConfig = name: host: system: cfg: {
    hostname = host;
    profiles.system = {
      user = "root";
      sshUser = username;
      path = inputs.deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
      magicRollback = cfg.magicRollback or true;
      sshOpts = cfg.sshOpts or [];
    };
  };
in {
  flake.deploy.nodes = {
    racknerd = deployConfig "racknerd" "vps" "x86_64-linux" {};
    rpi = deployConfig "rpi" "rpi" "aarch64-linux" {};
    laptop = deployConfig "laptop" "laptop" "x86_64-linux" {
      magicRollback = false;
      sshOpts = ["-t"];
    };
  };
  flake.checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;
}
