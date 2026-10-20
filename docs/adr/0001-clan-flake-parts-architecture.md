# ADR-0001: Clan + flake-parts architecture for the phoenix flake

**Status:** Accepted
**Date:** 2026-09-17
**Deciders:** nixolotl

## Context

The flake already used Clan + flake-parts but had drifted: a `git-hooks.nix` module
was never wired in, a `nil` hook pointed at the wrong package, a `modules/lib.nix`
helper was imported but unused, and shared machine config was plumbed through Clan's
generic `importer` instead of typed `clanService` modules. `vars/` carried a
`user-password-root` tree with no matching instance, plus a stale `root-password/`.

Goals: current Clan (26.05) and flake-parts idioms, structured for eventual
multi-architecture machines (a Pi on `aarch64-linux`, a ThinkPad on bare-metal
`x86_64-linux`), with only the WSL `workstation` implemented today.

## Decision

1. **Deployment.** `workstation` is both the Clan CLI host and a managed machine
   (self-managed): no `deploy.targetHost`, updated in place with
   `nixos-rebuild switch --flake .#workstation`. Future machines get
   `deploy.targetHost = "root@<ip>"` and are managed from workstation over SSH.
2. **Users and SSH keys** stay on Clan's inventory services — `sshd` for host keys,
   certs and root's `authorizedKeys`; `users` for accounts and passwords
   (vars-backed). No hardcoded `openssh.authorizedKeys.keys` in machine configs.
3. **Module authoring.** `base-system` and `wsl` are real `clan.service` modules,
   registered via `clan.modules` and referenced by name/tag like official services.
   Only `base-system` exposes typed `interface.options`
   (`timeZone`/`locale`/`keyMap`/`editor`/`extraLocale`); `wsl` declares none and
   ignores per-instance settings, since the single WSL machine is its only consumer
   — it earns an interface when a second, differently-configured machine needs one.
   `home-manager` wiring stays on the generic `importer`: bespoke to this flake, so
   a `clan.service` wrapper would add ceremony with no payoff.

## Options Considered

| | `importer` + plain NixOS modules | real `clan.service` modules |
| --- | --- | --- |
| Complexity | low | medium — manifest, interface, perInstance |
| Reuse | low — settings hardcoded per module | high — typed settings per instance |
| Consistency with clan-core | low | high |

Chosen: split per service. `clan.service` for the shared baseline and hardware
concerns, `importer` for single-machine glue. Applying the typed form everywhere
would be overkill — `interface.options` only pays for itself once a second consumer
with different settings exists. Applying the plain form everywhere means redoing
this the moment the Pi and ThinkPad land.

## Consequences

- Adding a machine on a new architecture: add the system to `systems`, add
  `machines/<name>/configuration.nix` (+ `hardware-configuration.nix`), tag it
  `all` (and `wsl` if applicable), give it `deploy.targetHost`.
- Overriding a base-system setting per machine is a one-line
  `roles.default.settings.<option>` in `clan.nix`, not a module edit.
- Pre-commit checks are active: the first `git commit` reformats and relints.

## Action Items

All resolved or tracked elsewhere. Evidence recorded here so the file needs no rerun:

1. [x] `nix flake check` passes.
2. [x] `clan vars generate workstation` — a no-op, as expected: exit 0, no output, and
   `git status` clean afterwards. `vars/per-machine/workstation/` carries the same twelve
   files before and after, and `user-password-root/` is the tree `user-root` reads.
3. [x] `sudo nixos-rebuild switch --flake .#workstation` — done, and still current:
   `/run/current-system` equals the toplevel this tree builds
   (`nixos-system-workstation-26.11.20260929.b6c8664`), so the machine runs this flake.
4. [x] `vars/` audited: `root-password/` and `mycelium/` no longer exist and were
   never tracked; `hermes/` had no generator behind it and was removed. Remaining
   per-machine trees: `mosquitto-plant-monitor/`, `openssh/`, `openssh-cert/`,
   `state-version/`, `user-password-nixolotl/`, `user-password-root/`.
5. [x] Pi/ThinkPad: not hardware that exists yet, so the work is tracked as work —
   `systems`, the machine skeleton and `deploy.targetHost` are
   [`../recommendations.md`](../recommendations.md) 1.6, 1.7 and 2.1. A decision record is
   the wrong home for a to-do list that grows.

## Follow-up

The `topology` output was broken and unchecked; see
[ADR-0002](./0002-topology-modelling.md). Outstanding review items are in
[`../recommendations.md`](../recommendations.md); the mechanisms behind them —
`nixConfig`, the two pkgs wirings, input `follows`, the topology check — are in
[`../flake-internals.md`](../flake-internals.md).
