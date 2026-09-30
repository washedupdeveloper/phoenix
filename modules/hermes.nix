{ config, username, ... }:
{
  # Rootless Podman: container runtime for Hermes' "docker" terminal backend.
  virtualisation.podman.enable = true;

  clan.core.vars.generators.hermes = {
    prompts.api-key = {
      description = "Surplus Intelligence API key";
      type = "hidden";
      persist = false;
    };
    files.env = {
      owner = username;
      mode = "0400";
    };
    script = ''
      printf 'OPENAI_API_KEY=%s\n' "$(cat $prompts/api-key)" > $out/env
    '';
  };

  home-manager.users.${username} = {
    programs.hermes-agent.enable = true;
    services.hermes-agent = {
      enable = true;
      environmentFiles = [ config.clan.core.vars.generators.hermes.files.env.path ];
      environment.HERMES_DOCKER_BINARY = "/run/current-system/sw/bin/podman";
      settings = {
        model = {
          provider = "custom";
          base_url = "https://api.surplusintelligence.ai/v1";
          default = "deepseek-v4.1-flash";
        };
        terminal = {
          backend = "docker";
          docker_volumes = [
            "/home/${username}/projects:/workspace/projects"
            # Mask phoenix (secrets) with an empty read-only directory.
            "/var/empty:/workspace/projects/phoenix:ro"
          ];
        };
      };
    };
  };
}
