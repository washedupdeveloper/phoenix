{ config, username, ... }:
{
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
      settings.model = {
        provider = "custom";
        base_url = "https://api.surplusintelligence.ai/v1";
        default = "deepseek-v4.1-flash";
      };
    };
  };
}
