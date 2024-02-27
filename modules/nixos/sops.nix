{
  config,
  inputs,
  username,
  ...
}: {
  imports = [inputs.sops-nix.nixosModules.sops];
  sops = {
    defaultSopsFile = ../../secrets/default.yaml;
    age.keyFile = "/home/${username}/.config/sops/age/keys.txt";
    secrets = {
      user_password.neededForUsers = true;
      cache_key_priv = {
        owner = config.users.users.${username}.name;
        group = config.users.users.${username}.group;
        mode = "0770";
      };
      k3s_token = {};
    };
  };
}
