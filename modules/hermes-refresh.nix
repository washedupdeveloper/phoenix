# The weekly caveman refresh job. Advances the locked revision, builds it, and
# reports what moved, restoring the lock if the new revision does not build.
# Activation stays manual. Design rules: docs/hermes-agent-provisioning.md.
{
  pkgs,
  lib,
  username,
}:
pkgs.writeShellScript "caveman-skills-refresh" ''
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

  # `// empty` matters on the first run, before any switch has locked the
  # input: plain `jq -r` prints the literal string `null`.
  locked_rev() { jq -r '.nodes.caveman.locked.rev // empty' "$lock"; }
  skill_names() { find "$1" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort; }

  # Written on every run that reaches a verdict, including a no-op: a report
  # only on change cannot be told apart from a job that never ran.
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
  # Non-fatal: the diff is a nicety, the refresh is the job.
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
''
