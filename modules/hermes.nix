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

    # Every run that reaches a verdict rewrites the report, including a run
    # that changes nothing. A report written only on a change cannot be told
    # apart from a job that never ran. The body arrives on stdin.
    write_report() {
      {
        echo "# caveman skills refresh"
        echo
        printf -- '- date: %s\n' "$(date -Iseconds)"
        printf -- '- upstream: `%s` -> `%s`\n' "$shown_old" "$shown_new"
        echo
        cat
      } > "$report"
    }

    old_rev=$(locked_rev)
    # Not fatal: the diff is a nicety, the refresh is the job. A garbage
    # collected or otherwise unbuildable previous revision must not stop it.
    old_out=$(nix build --no-link --print-out-paths .#caveman-skills 2>/dev/null || true)

    cp "$lock" "$state/flake.lock.before"

    if ! update_log=$(nix flake update caveman 2>&1); then
      cp "$state/flake.lock.before" "$lock"
      if [ -n "$old_rev" ]; then shown_old=$old_rev; else shown_old=unlocked; fi
      shown_new=unknown
      {
        echo '`nix flake update caveman` failed. `flake.lock` was restored, so'
        echo 'nothing changed. Its output follows.'
        echo
        echo '```'
        echo "$update_log"
        echo '```'
      } | write_report
      echo "caveman skills: nix flake update failed; see $report" >&2
      exit 1
    fi

    new_rev=$(locked_rev)
    if [ -n "$old_rev" ]; then shown_old=$old_rev; else shown_old=unlocked; fi
    if [ -n "$new_rev" ]; then shown_new=$new_rev; else shown_new=unknown; fi

    if [ "$old_rev" = "$new_rev" ]; then
      echo 'Upstream is already at this revision. Nothing to do.' | write_report
      echo "caveman skills: already current at $old_rev"
      exit 0
    fi

    build_err=$state/build.err
    if ! new_out=$(nix build --no-link --print-out-paths .#caveman-skills 2>"$build_err"); then
      cp "$state/flake.lock.before" "$lock"
      {
        echo 'The new revision does not build. `flake.lock` was restored, so'
        echo 'nothing changed and the next switch is unaffected.'
        echo
        echo '```'
        cat "$build_err"
        echo '```'
      } | write_report
      echo "caveman skills: $new_rev does not build, flake.lock restored" >&2
      exit 1
    fi
    rm -f "$build_err"

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
    } | write_report

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
        # Only the style mode is pinned. An auto-loaded skill is injected in
        # full into every session's system prompt, so pinning the other
        # nineteen would cost far more context than they save. The rest stay
        # on demand: `/caveman-commit`, `/caveman-review`, `/surgical-patch`.
        # `/caveman off` (or "normal mode") escapes it for one session.
        skills.auto_load = [ "caveman" ];
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
