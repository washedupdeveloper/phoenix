{
  config,
  variables,
  ...
}: {
  sops = {
    defaultSopsFile = ../../secrets/home.yaml;
    age.keyFile = "/home/${variables.system.username}/.config/sops/age/keys.txt";
    secrets.ssh_password = {};
  };
}
