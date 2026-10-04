{
  config,
  pkgs,
  username,
  cavemanSrc,
  ...
}:
let
  # Same derivation as `.#caveman-skills`.
  cavemanSkills = pkgs.callPackage ./caveman-skills.nix { inherit cavemanSrc; };

  # This file is evaluated as a NixOS module, so the Hermes options are one level
  # down. Read the path from the option that owns it rather than repeating the
  # default. See docs/hermes-agent-provisioning.md.
  hermesHome = config.home-manager.users.${username}.services.hermes-agent.hermesHome;

  # Built by modules/flake-refresh.nix; see docs/hermes-agent-provisioning.md.
  flakeRefresh = pkgs.callPackage ./flake-refresh.nix { inherit username; };
in
{
  # Rootless Podman: container runtime for Hermes' "docker" terminal backend.
  users.users.${username}.extraGroups = [ "podman" ];
  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose
  };

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
    # The Electron app and its XDG launcher entry; it starts its own
    # `hermes serve` backend rather than sharing a service. See
    # docs/hermes-agent-provisioning.md.
    programs.hermes-agent = {
      enable = true;
      desktop.enable = true;
    };
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
            "/home/${username}/.hermes/pastes:/root/.hermes/pastes:ro"
          ];
        };
        # Store-backed, scanned alongside ~/.hermes/skills; nothing is written
        # into the profile's own skills directory.
        skills.external_dirs = [ "${cavemanSkills}" ];
        # Only the style mode is pinned -- an auto-loaded skill costs tokens in
        # every session. The rest stay on demand. See
        # docs/hermes-agent-provisioning.md.
        skills.auto_load = [ "caveman" ];
      };
    };

    # One YAML per bundle becomes `/<slug>` with no imperative `hermes bundles
    # create`. Keep each slug clear of every skill name: the bundle wins the
    # collision and shadows the skill.
    home.file =
      [
        "caveman-build"
        "caveman-fix"
        "caveman-git"
        "caveman-recon"
        "caveman-refactor"
      ]
      |> map (slug: {
        name = "${hermesHome}/skill-bundles/${slug}.yaml";
        value.source = ./skill-bundles/${slug}.yaml;
      })
      |> builtins.listToAttrs;

    # Weekly. The new revisions go live on the next `nh os switch`.
    systemd.user.services.flake-refresh = {
      Unit.Description = "Refresh the branch-tracking flake inputs";
      Service = {
        Type = "oneshot";
        ExecStart = "${flakeRefresh}";
      };
    };

    systemd.user.timers.flake-refresh = {
      Unit.Description = "Weekly flake input refresh";
      Timer = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "2h";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
