# Hermes agent provisioning

How the agent's skills are packaged, refreshed and loaded. The elaboration
behind the inline comments in `modules/hermes.nix`, `modules/flake-refresh.nix`
and `modules/caveman-skills.nix`.

## Packaging: one derivation, two consumers

Hermes indexes a skill as a direct child directory carrying a `SKILL.md`, so
`modules/caveman-skills.nix` copies only those directories. The rest of
caveman's `skills/` -- `registry.json`, the `*.mjs` helpers, `native/` and
`generated/` -- is caveman's own build input and must not reach the loader as
if it were a skill. Requiring `<child>/SKILL.md` excludes all of it in one rule
rather than by enumerating names, so a later upstream addition is handled
without an edit.

The derivation is `callPackage`d from two places: `perSystem.packages.caveman-skills`,
which the refresh job builds, and `modules/hermes.nix`, which points Hermes at
it. Two derivations would mean the job builds one thing and the running
configuration uses another -- drift nobody notices until a switch.

## Loading: three separate mechanisms

| Mechanism | Setting | Cost |
| --- | --- | --- |
| External search path | `skills.external_dirs = [ "${cavemanSkills}" ]` | none until a skill is loaded |
| Always-on injection | `skills.auto_load = [ "caveman" ]` | paid in every session's system prompt |
| On-demand bundle | one YAML per bundle under `modules/skill-bundles/` | none until invoked |

Only the style mode is pinned in `auto_load`. An auto-loaded skill is injected
**in full** into every session on every surface, so pinning a whole directory is
the classic mistake -- it spends the tokens to save output on one unit. The rest
stay on demand behind `/caveman-commit`, `/caveman-review`, `/surgical-patch`,
and `/caveman off` (or "normal mode") escapes the style for one session.

The skills live in the Nix store and are scanned alongside `~/.hermes/skills`.
Nothing is written into the profile's own skills directory, so the two never
shadow each other.

Bundles are `home.file`-linked rather than symlinked by hand, so the repository
stays the only place a bundle is edited. Hermes reads every `*.yaml` under
`<hermesHome>/skill-bundles/`, so a file here becomes `/<slug>` with no
imperative `hermes bundles create`.

A bundle slug must not match a skill name in its own set: the bundle wins the
collision and the skill becomes unreachable under its own name.

## The weekly refresh job

`modules/flake-refresh.nix` is a `callPackage`-able script that
`modules/hermes.nix` wires into `systemd.user.timers.flake-refresh`. It walks the
inputs that track a branch (`caveman`, `nixos-wsl`, `hermes-agent`), advancing
and verifying each, and writes `~/.local/state/flake-refresh/report.md`.

Design rules, each a bug avoided:

- **The report is written on every run that reaches a verdict, including the
  no-op path.** A report only on change is indistinguishable from a job that
  never ran, and "already current" is the common case.
- **The lock is snapshotted and restored per input.** A failure rolls back only
  that input, so one bad revision does not discard the others' good updates.
  Nobody is watching, so the job must be strictly non-regressing: a bad upstream
  revision left locked turns one failed update into a broken `nh os switch` days
  later.
- **Only the new revision is fatal.** Building the previous one, to diff
  against, is a nicety that may fail on a garbage-collected path, so it is
  `$(cmd 2>/dev/null || true)` with a guarded consumer. Under `set -e` a bare
  `$(cmd)` would abort the job over a failure that does not matter.
- **Verification is evaluation, not building** -- except `caveman`, whose
  `.#caveman-skills` is cheap and isolated. The other two feed the machine
  configuration, so the job evaluates `nixosConfigurations.workstation` and
  stops there. A build failure surfaces at `nh os switch`, and the report says
  so rather than implying more coverage than it has.
- **`PATH` is pinned with `lib.makeBinPath`, and `set -euo pipefail` is set.** A
  systemd unit gets no login shell.
- **Failures are captured, not just reported.**
  `if ! log=$(nix flake update <input> 2>&1)` puts the stderr in the report
  instead of sending the reader to the journal for it.
- **Activation stays manual.** The report names the next action (`nh os switch`).

Backticks in the generated script belong in single-quoted strings. A literal
backtick inside double quotes is command-substituted, and a backslash written
before a backtick in a Nix `''` string is a literal backslash rather than an
escape -- so an "escaped" backtick reaches the report with the backslash still
attached to it.

## Scope pitfall: which `config`

`clan.nix` imports only the home-manager module, so `modules/hermes.nix` is
evaluated as a **NixOS** module and a bare `config.services.hermes-agent` does
not exist there. The home-manager options are one level down, which is why
`hermesHome` is read as

```nix
config.home-manager.users.${username}.services.hermes-agent.hermesHome
```

rather than repeating the default. `home.file` must also sit inside the
`home-manager.users.<name>` attribute set -- that subtree is an HM module, so HM
options are valid there and nowhere else in the file.

## The API key

`clan.core.vars.generators.hermes` prompts for the key once (`persist = false`),
writes it to a `0400` file owned by the user, and `environmentFiles` points the
service at that path. The key is never in the Nix store in plaintext.

## Container backend

`virtualisation.podman` with `dockerCompat` provides the runtime for Hermes'
`docker` terminal backend, and `HERMES_DOCKER_BINARY` points at it. The mounts
are fixed at container creation, so a running sandbox reflects the host as of
creation time -- after a `nixos-rebuild switch` it still shows the pre-switch
skills and config until the container is recreated.
