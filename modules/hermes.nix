{
  config,
  lib,
  pkgs,
  username,
  cavemanSrc,
  ...
}:
let
  # The same derivation the flake exposes as `.#caveman-skills`, so the refresh
  # job and the running configuration can never disagree about what it is.
  cavemanSkills = pkgs.callPackage ./caveman-skills.nix { inherit cavemanSrc; };

  # Move the locked caveman revision forward, prove it builds, and write down
  # what moved. The lock is restored when the new revision does not build, so
  # a bad upstream commit cannot break the next `nh os switch`. Activation
  # stays manual: nothing here rewrites a live configuration.
  refreshCavemanSkills = pkgs.writeShellScript "caveman-skills-refresh" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.nix
        pkgs.git
        pkgs.jq
        pkgs.coreutils
        pkgs.diffutils
        pkgs.findutils
      ]
    }:$PATH

    set -euo pipefail

    flake=/home/${username}/projects/phoenix
    state=/home/${username}/.local/state/caveman-skills
    lock=$flake/flake.lock
    report=$state/report.md

    mkdir -p "$state"
    cd "$flake"

    # Empty when the lock has no caveman node yet -- the first run after this
    # input is added, before any switch has locked it.
    locked_rev() { jq -r '.nodes.caveman.locked.rev // empty' "$lock"; }
    skill_names() { find "$1" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort; }

    old_rev=$(locked_rev)
    # Not fatal: the diff is a nicety, the refresh is the job. A garbage
    # collected or otherwise unbuildable previous revision must not stop it.
    old_out=$(nix build --no-link --print-out-paths .#caveman-skills 2>/dev/null || true)

    cp "$lock" "$state/flake.lock.before"
    nix flake update caveman
    new_rev=$(locked_rev)

    if [ "$old_rev" = "$new_rev" ]; then
      echo "caveman skills: already current at $old_rev"
      exit 0
    fi

    if ! new_out=$(nix build --no-link --print-out-paths .#caveman-skills); then
      cp "$state/flake.lock.before" "$lock"
      {
        echo "# caveman skills refresh"
        echo
        printf -- '- date: %s\n' "$(date -Iseconds)"
        printf -- '- upstream: `%s` -> `%s`\n' "$old_rev" "$new_rev"
        echo
        printf 'The new revision does not build. `flake.lock` was restored to\n'
        printf '`%s`; nothing changed and the next switch is unaffected.\n' "$old_rev"
      } > "$report"
      echo "caveman skills: $new_rev does not build, flake.lock restored" >&2
      exit 1
    fi

    added=""
    removed=""
    changed=""
    note=""
    if [ -n "$old_out" ] && [ -d "$old_out" ]; then
      added=$(comm -13 <(skill_names "$old_out") <(skill_names "$new_out") | tr '\n' ' ')
      removed=$(comm -23 <(skill_names "$old_out") <(skill_names "$new_out") | tr '\n' ' ')
      for name in $(skill_names "$new_out"); do
        if [ -d "$old_out/$name" ] && ! diff -rq "$old_out/$name" "$new_out/$name" >/dev/null 2>&1; then
          changed="$changed $name"
        fi
      done
    else
      note="The previous revision could not be built, so the per-skill diff was skipped."
    fi

    {
      echo "# caveman skills refresh"
      echo
      printf -- '- date: %s\n' "$(date -Iseconds)"
      printf -- '- upstream: `%s` -> `%s`\n' "$old_rev" "$new_rev"
      printf -- '- skills: %s\n' "$(skill_names "$new_out" | wc -l)"
      echo
      echo "added:''${added:- none}"
      echo
      echo "removed:''${removed:- none}"
      echo
      echo "changed:''${changed:- none}"
      echo
      if [ -n "$note" ]; then
        echo "$note"
        echo
      fi
      echo '`flake.lock` is updated and the new set is built, but `config.yaml`'
      echo 'still points at the previous store path. Run `nh os switch` to'
      echo 'activate, then start a new Hermes session.'
    } > "$report"

    echo "caveman skills: $old_rev -> $new_rev"
    echo "caveman skills: report written to $report"
  '';
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
            "/home/${username}/.hermes/pastes:/root/.hermes/pastes:ro"
          ];
        };
        # The caveman skills live in the Nix store and are scanned alongside
        # ~/.hermes/skills. Nothing is written into the profile's own skills
        # directory, so the two never shadow each other.
        skills.external_dirs = [ "${cavemanSkills}" ];
      };
    };

    # Weekly: advance the locked caveman revision, build it, and record what
    # changed. The new skills go live on the next `nh os switch`.
    systemd.user.services.caveman-skills-refresh = {
      Unit.Description = "Refresh caveman agent skills from upstream";
      Service = {
        Type = "oneshot";
        ExecStart = "${refreshCavemanSkills}";
      };
    };

    systemd.user.timers.caveman-skills-refresh = {
      Unit.Description = "Weekly caveman agent skills refresh";
      Timer = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "2h";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
