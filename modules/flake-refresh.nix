# The weekly refresh job for the flake inputs that track a branch. Advances each
# locked revision, verifies it, and reports what moved, restoring the lock when a
# revision does not verify. Activation stays manual.
# Design rules: docs/hermes-agent-provisioning.md.
{
  pkgs,
  lib,
  username,
}:
pkgs.writeShellScript "flake-refresh" ''
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
  state=/home/${username}/.local/state/flake-refresh
  lock=$flake/flake.lock
  report=$state/report.md
  host=workstation

  # Inputs that track a branch rather than a tag, so a locked revision only moves
  # when something runs `nix flake update`. `caveman` is the one whose contents
  # this repository inspects; the others are verified by evaluating the machine
  # configuration they feed.
  inputs="caveman nixos-wsl hermes-agent"

  mkdir -p "$state"
  cd "$flake"

  # `// empty` matters on the first run, before any switch has locked the input:
  # plain `jq -r` prints the literal string `null`.
  locked_rev() { jq -r --arg i "$1" '.nodes[$i].locked.rev // empty' "$lock"; }
  skill_names() { find "$1" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort; }

  # Evaluation, deliberately: it catches the renamed and removed options a branch
  # bump actually tends to break, at a fraction of the cost of building the
  # machine. A build failure is not caught here, and the report says so.
  #
  # `--accept-flake-config` is required, not cosmetic: these modules use `|>`,
  # which the flake's own `nixConfig` enables. Without the flag the job would
  # silently depend on the host's nix.conf having `accept-flake-config = true`.
  verify() {
    case "$1" in
      caveman) nix build --accept-flake-config --no-link --print-out-paths .#caveman-skills ;;
      *) nix eval --accept-flake-config --raw ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath" ;;
    esac
  }

  verify_desc() {
    case "$1" in
      caveman) echo "build .#caveman-skills" ;;
      *) echo "eval nixosConfigurations.$host" ;;
    esac
  }

  sections=$state/.sections
  : > "$sections"
  moved=no
  failed=no

  for input in $inputs; do
    section=$state/.section.$input
    : > "$section"
    printf -- '## %s\n\n' "$input" >> "$section"

    old_rev=$(locked_rev "$input")
    snap=$state/flake.lock.$input.before
    cp "$lock" "$snap"

    # The skill diff is a nicety, the refresh is the job: a garbage-collected or
    # unbuildable previous revision must not stop it.
    old_out=""
    if [ "$input" = caveman ]; then
      old_out=$(nix build --accept-flake-config --no-link --print-out-paths .#caveman-skills 2>/dev/null || true)
    fi

    if ! update_log=$(nix flake update "$input" 2>&1); then
      cp "$snap" "$lock"
      failed=yes
      {
        printf -- '- result: **failed** -- `nix flake update %s` errored\n' "$input"
        echo "- lock: restored, this input did not move"
        echo
        echo '```'
        echo "$update_log"
        echo '```'
        echo
      } >> "$section"
      cat "$section" >> "$sections"
      continue
    fi

    new_rev=$(locked_rev "$input")
    if [ -n "$old_rev" ]; then shown_old=$old_rev; else shown_old=unlocked; fi
    if [ -n "$new_rev" ]; then shown_new=$new_rev; else shown_new=unknown; fi
    printf -- '- upstream: `%s` -> `%s`\n' "$shown_old" "$shown_new" >> "$section"

    if [ "$old_rev" = "$new_rev" ]; then
      printf -- '- result: already current\n\n' >> "$section"
      cat "$section" >> "$sections"
      continue
    fi

    moved=yes
    printf -- '- verify: %s\n' "$(verify_desc "$input")" >> "$section"

    if ! new_out=$(verify "$input" 2>"$state/verify.err"); then
      cp "$snap" "$lock"
      failed=yes
      {
        echo "- result: **failed** -- the new revision does not verify"
        echo "- lock: restored, this input did not move"
        echo
        echo '```'
        cat "$state/verify.err"
        echo '```'
        echo
      } >> "$section"
      rm -f "$state/verify.err"
      cat "$section" >> "$sections"
      continue
    fi
    rm -f "$state/verify.err"

    if [ "$input" = caveman ]; then
      added=""
      removed=""
      changed=""
      if [ -n "$old_out" ] && [ -d "$old_out" ]; then
        added=$(comm -13 <(skill_names "$old_out") <(skill_names "$new_out") | tr '\n' ' ')
        removed=$(comm -23 <(skill_names "$old_out") <(skill_names "$new_out") | tr '\n' ' ')
        for name in $(skill_names "$new_out"); do
          if [ -d "$old_out/$name" ] && ! diff -rq "$old_out/$name" "$new_out/$name" >/dev/null 2>&1; then
            changed="$changed $name"
          fi
        done
      else
        echo "- note: the previous revision could not be built, so the per-skill diff was skipped" >> "$section"
      fi
      {
        echo "- result: ok"
        printf -- '- skills: %s\n' "$(skill_names "$new_out" | wc -l)"
        echo "- added:''${added:- none}"
        echo "- removed:''${removed:- none}"
        echo "- changed:''${changed:- none}"
        echo
      } >> "$section"
    else
      printf -- '- result: ok\n\n' >> "$section"
    fi

    cat "$section" >> "$sections"
  done

  # Written on every run that reaches a verdict, including a no-op: a report only
  # on change cannot be told apart from a job that never ran.
  {
    echo "# flake input refresh"
    echo
    printf -- '- date: %s\n' "$(date -Iseconds)"
    printf -- '- inputs: %s\n' "$inputs"
    echo
    cat "$sections"
    if [ "$failed" = yes ]; then
      echo 'At least one input failed to verify and was rolled back. The rest of'
      echo 'the lock is as it was.'
    elif [ "$moved" = no ]; then
      echo 'Every input is already at its current revision. Nothing to do.'
    else
      echo '`flake.lock` is updated. Nothing is activated until you run'
      echo '`nh os switch`, and the machine configuration was evaluated but not'
      echo 'built -- a build failure would only show up at that switch.'
    fi
  } > "$report"

  rm -f "$sections" "$state"/.section.* "$state"/flake.lock.*.before

  if [ "$failed" = yes ]; then
    echo "flake refresh: at least one input failed; see $report" >&2
    exit 1
  fi
  echo "flake refresh: report written to $report"
''
