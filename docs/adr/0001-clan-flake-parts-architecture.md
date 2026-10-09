# ADR-0001: Clan + flake-parts architecture for the phoenix flake

**Status:** Accepted
**Date:** 2026-09-17
**Deciders:** nixolotl

## Context

The existing `phoenix` flake already used Clan + flake-parts, but had drifted:
a `git-hooks.nix` module was never actually wired into the flake (and had a
bug even if it had been), a `nil` pre-commit hook pointed at the wrong
package, a `modules/lib.nix` helper was imported but never used, and shared
machine config (`baseSystem.nix`, `wsl.nix`) was plumbed in through Clan's
generic `importer` service rather than typed, reusable `clanService` modules.
Separately, `vars/` contained a `user-password-root` tree with no matching
`inventory.instances` entry, and an older `root-password/` tree that predates
the current `users` service naming.

The rebuild's goals: current Clan (26.05) and flake-parts idioms, structured
for eventual multi-architecture machines (a Raspberry Pi on `aarch64-linux`,
a ThinkPad on bare-metal `x86_64-linux`), while only the NixOS-WSL
`workstation` machine is actually implemented today.

## Decision

1. **Deployment model:** `workstation` is both the Clan CLI host and a
   managed machine (self-managed). It has no `deploy.targetHost` — it is
   updated in place with `nixos-rebuild switch --flake .#workstation`.
   Future machines (Pi, ThinkPad) get `deploy.targetHost = "root@<ip>"` and
   are managed *from* workstation over SSH.
2. **User/SSH-key management:** stays on Clan's inventory services — `sshd`
   for host keys, certs, and root's `authorizedKeys`; `users` for account +
   password management (vars-backed). No hardcoded
   `users.users.<name>.openssh.authorizedKeys.keys` in machine configs.
3. **Module authoring:** `base-system` and `wsl` are authored as real
   `clan.service` modules, registered locally via `clan.modules` and
   referenced by name/tag like official clan-core services. Only
   `base-system` exposes typed `interface.options`
   (`timeZone`/`locale`/`keyMap`/`editor`/`extraLocale`); `wsl` declares no
   interface and ignores per-instance settings, since the single WSL machine
   is its only consumer — it earns one when a second, differently-configured
   machine needs it. `home-manager` wiring stays on the generic `importer`
   service — it's bespoke to this flake, not reused elsewhere, and a full
   `clan.service` wrapper would add ceremony with no payoff.

## Options Considered

### Option A: `importer` + plain NixOS modules

| Dimension | Assessment |
| --- | --- |
| Complexity | Low |
| Reusability for future machines | Low — settings hardcoded per module |
| Consistency with clan-core's services | Low |

**Pros:** least code, fastest to write.

**Cons:** the moment the Pi wants a different timezone or the ThinkPad has
no WSL bind-mount, you're back to editing the shared module instead of
setting an option.

### Option B: real `clan.service` modules (chosen for base-system/wsl)

| Dimension | Assessment |
| --- | --- |
| Complexity | Medium — manifest + interface + perInstance boilerplate |
| Reusability for future machines | High — typed settings per instance |
| Consistency with clan-core's services | High — same shape as official services |

**Pros:** matches the "the clan way" mandate; settings are discoverable and
type-checked; scales cleanly to more machines.

**Cons:** more boilerplate than `importer` for config that's genuinely
one-off.

## Trade-off Analysis

Applying Option B everywhere (including home-manager wiring) would be
overkill: it's not reused, not shared with other machines, and the typed
`interface.options` mechanism only pays for itself when a *second* consumer
with *different* settings shows up. Applying Option A everywhere would mean
redoing this exercise again the moment the Pi/ThinkPad land. Splitting per
service — B for genuinely shared/cross-machine baseline and hardware
concerns, A for single-machine glue — gets the reusability where it matters
without the ceremony where it doesn't.

## Consequences

- Adding a machine on a new architecture: add the system to `flake.nix`'s
  `systems`, add `machines/<name>/configuration.nix`
  (+ `hardware-configuration.nix`), tag it `all` (and `wsl` only if
  applicable), and give it `deploy.targetHost`.
- Overriding base-system settings per machine is now a one-line
  `roles.default.settings.<option>` in `clan.nix`, not a module edit.
- `git-hooks.nix` pre-commit checks are now actually active — expect the
  first `git commit` to reformat/relint the tree.

## Action Items

1. [x] `nix flake check` passes. (`direnv reload` is a local convenience and is
   not part of the check.)
2. [ ] `clan vars generate workstation` — should be a no-op except for
   confirming `user-root` picks up the existing `user-password-root` vars.
   Not run as part of this work: it needs the machine, not a sandbox.
3. [ ] `sudo nixos-rebuild switch --flake .#workstation` (or via `nom` for
   nicer output) to apply.
4. [x] `vars/` audited. Neither the `root-password/` tree nor the `mycelium/`
   tree this ADR flagged as possibly stale exists in the tree any more, and
   neither was ever tracked by git, so there is nothing to remove. The
   `hermes/` tree that survived that audit turned out to have no generator
   behind it — no `clan.core.vars.generators` entry could reproduce it — and
   was removed. The remaining per-machine trees are
   `mosquitto-plant-monitor/`, `openssh/`, `openssh-cert/`,
   `state-version/`, `user-password-nixolotl/` and `user-password-root/`.
5. [ ] When the Pi/ThinkPad are ready: add `aarch64-linux` to `systems`,
   scaffold `machines/<name>/`, decide `deploy.targetHost`.

## Follow-up work

The `topology` output this ADR's tree carried was not evaluated by
`nix flake check` and had been broken since it was written; see
[ADR-0002](./0002-topology-modelling.md). The general shape of the flake was
reviewed against the Clan, flake-parts and Nix3 documentation afterwards, and
the outstanding items are listed in [`../recommendations.md`](../recommendations.md).

The mechanisms behind the decisions taken in that review -- `nixConfig`, the two
pkgs wirings, the input `follows` and the topology check -- are written up in
[`../flake-internals.md`](../flake-internals.md). Inline comments in the Nix
files are deliberately short pointers into these documents; the convention is
stated in [`../../README.md`](../../README.md).
