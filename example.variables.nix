{
  system = {
    architecture = "x86_64-linux"; # e.g. "x86_64-linux"
    username = "storm";
    hostname = "nixos";
    stateVersion = "23.05"; # e.g. "23.11"
  };

  git = {
    # git stuff here, important to be precise if signing commits
    username = "Storm";
    email = "123456789+washedupdeveloper@users.noreply.github.com";
    github.username = "washedupdeveloper"; # github username
  };

  region = {
    timeZone = "UTC"; # e.g. "UTC"
    locale = "C.UTF-8"; # e.g. "C.UTF-8"
  };
}