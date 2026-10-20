# Recommendations

Forward-looking changes for the `phoenix` flake, in priority order: Clan.lol, flake-parts, Nix3. Checked
against the pinned option declarations (clan-core, nix-topology, flake-parts, devshell, git-hooks.nix) and
clan-core's `templates/clan/flake-parts/`; doc-sourced claims name the file. Verified-and-unchanged items sit
under "Considered and rejected".

## Applied on this branch

| # | Change |
| --- | --- |
| 1 | `modules/flake/nix-topology.nix` pointed `topology.modules` at `config.nixosConfigurations`, which does not exist in that scope, so the whole output failed to evaluate. Repointed at the root `topology.nix`, which nothing imported. |
| 2 | Filled out the topology: uplink, home router, Windows host with its wired NIC and Hyper-V switch, the WSL machine as its guest, both networks. |
| 3 | `perSystem.clan.pkgs = pkgs` so clan's internal instantiations use the devshell's pkgs; dropped a redundant nix-topology overlay. |
| 4 | Added `description` and a `nixConfig` carrying the binary caches and `pipe-operators`. |
| 5 | Stopped tracking the generated `.pre-commit-config.yaml`; ignored `result-*`. |
| 6 | Collapsed duplicate inputs (34 → 24 lock nodes) and added `checks.<system>.topology`. |
| 7 | Dropped the hand-copied DHCP addresses from the topology and renamed the guest interface `wsl0` → `eth0`: the lease is 3 h and mirrored networking gives the guest the host's address, so both values were stale or duplicated. See [ADR-0002](./adr/0002-topology-modelling.md). |

Row 6 makes `nixos-wsl`, `devshell`, `git-hooks`, `nix-topology`, clan-core's `flake-parts` and `treefmt-nix`
follow the pinned `nixpkgs`; each followed node sat at the same revision, so nothing changed about what any
input evaluates with. The one remaining duplicate, `flake-compat`, is two different upstream repos.

## 1. Clan.lol

- **1.1 Keep `clan`, not `flake.clan`.** `flakeModules/clan.nix` makes `clan` a renamed alias of `flake.clan`
  (`mkRenamedOptionModule`), but no warning fires and clan-core's `flake.nix` and template both still write
  `clan = { ... }`, as this repo does. Matching the template beats anticipating the alias removal, and the
  migration is a one-line rename. Watch for `Obsolete option 'clan' is used` in `nix flake check`.
- **1.2 Give clanServices a `README.md` and `roles/` when a second consumer appears.** `inventory.modules`
  documents a `README.md` with `description` and `features = [ "inventory" ]` frontmatter plus one
  `roles/{role}.nix` per role; ours inline both in one `default.nix`. Not needed today (`module.input = "self"`
  resolves out of `clan.modules`), but it matters for docs/schema generation and for flake-input consumers.
- **1.3 `machine.tags` is fine as written.** The computed `filterAttrs` definition merges with the machine's
  own tags by concatenation (`types.listOf types.str`), so the explicit `[ "all" "workstation" "wsl" ]` does
  not displace the computed `nixos` tag — verified: it evals to `["all","workstation","wsl","nixos"]`.
  `inventory.tags.workstation` is equally valid and tags without editing the machine.
- **1.4 Keep `extraModules` as paths.** `service-module.nix` wraps every *string* entry in `lib.warn "String
  types for 'extraModules' will be deprecated - ${s}"` and sends paths through `lib.setDefaultModuleLocation`;
  the role option's docs still show the string form, so the docs lag the code. Do not "correct" the paths.
- **1.5 Add per-machine `description`.** `inventory.machines.<name>` also takes `description` and `icon`, both
  feeding the CLI and UI; a description per machine cheaply improves `clan machines list`.
- **1.6 Give future machines a `deploy.targetHost`.** Per ADR-0001, restated because it is the first thing
  forgotten: a remote machine needs `deploy.targetHost` (and `deploy.buildHost` if built elsewhere) before
  `clan deploy` has anything to do. `workstation` correctly has none — it is self-managed.
- **1.7 Consider `clan.templates` for the machine skeleton.** Standing up the Pi or the ThinkPad becomes
  `clan template` instead of copying `machines/workstation/configuration.nix` by hand and forgetting the
  `nix-topology` import. Do it with the second machine.
- **1.8 Run the clan CLI against the flake.** `clan machines list`, `clan vars list workstation`,
  `clan vars generate workstation` — the last should be a no-op on a settled machine; a diff means generators
  and committed `vars/` have drifted. ADR-0001's possibly-stale `root-password/` and `mycelium/` trees are
  resolved: neither exists in the working tree and neither was ever tracked.
- **1.9 clan-core's `module.input` doc contradicts its resolver.** The `defaultText` says `null` means "the
  module is local", but the resolver treats `null` as clan-core (`if moduleSpec.input == null then
  { clan.modules = clanCoreModules; } else ...`); setting it to `null` on the local `base-system` fails with
  `clan-core doesn't provide clan-module with name 'base-system'`. The comment in `clan.nix` is correct —
  leave it alone.

## 2. flake-parts

- **2.1 Add `aarch64-linux` to `systems` when the Pi exists.** `systems` is a build contract — every
  `perSystem` output must evaluate for each entry and `nix flake check --all-systems` builds them — so
  `x86_64-linux` is alone: the only architecture with a machine behind it. `inputs.systems`
  (`github:nix-systems/default/future-26.11`) would bring ~11 systems including darwin. Stay explicit.
- **2.2 Keep `perSystem.devshells` lowercase.** devshell declares the lowercase option and maps it to
  `devShells` itself; renaming bypasses the mapping and loses `devshell.startup` and `devshell.env`.
- **2.3 One module per concern under `modules/` is the right shape.** flake-parts takes plain `imports`,
  which is what `modules/flake/*.nix` are. `flake.modules` and `partitions` are for flakes whose inputs or
  eval cost have become a problem; neither applies.
- **2.4 Use `withSystem`, not a second nixpkgs, when cross-building.** Another architecture's outputs must be
  built via `withSystem`; a `perSystem` module must not reach into another system's `pkgs`. No `pkgsFor`.
- **2.5 Expose `flake.overlays` / `flake.nixosModules` only if consumed.** Nothing consumes this flake. If
  another ever imports `phoenix` (to reuse `modules/clanServices/base-system`, say), declare them so it need
  not use `builtins.getFlake` and a store path.

## 3. Nix3

- **3.1 `nix flake check` only validates outputs it recognises.** Anything outside its fixed set of names
  prints `warning: unknown flake output '...'` and is skipped — the lesson from the topology bug, and why
  `checks.<system>.topology` exists. `clan`/`clanInternals` are clan's own; pair future outputs with a check.
- **3.2 `nix flake check --all-systems` once a second system is declared**, in CI: it exercises the `systems` list.
- **3.3 Keep floating on `nixos-wsl`.** It tracks a branch, and the weekly refresh job that advanced and
  verified it (`caveman`, `hermes-agent`; removed with the Hermes provisioning) is gone, so floating is
  manual: `nix flake update nixos-wsl` then `nh os switch`. A tag stops surprise changes and surprise fixes;
  this input ships fixes.
- **3.4 `nix fmt` is wired; add a pre-push drift hook.** treefmt provides `formatter` and `checks.treefmt`
  (named `treefmt`, not `formatting` — verified in `checks.x86_64-linux`), and the pre-commit hook runs it on
  staged files. A pre-push `nix fmt -- --fail-on-change` catches drift in files written but never staged.
- **3.5 What belongs in git.** `flake.lock` is committed — a flake without a lock is not reproducible.
  `.pre-commit-config.yaml` is ignored per the git-hooks.nix README, and `result` / `result-*` were already
  ignored. `vars/` (public halves plus encrypted secrets) and `sops/` stay tracked: clan expects both.
- **3.6 `nixConfig` carries caches and `pipe-operators`.** The caches and keys serve a third-party evaluator
  that accepts the flake config; this machine does not (`accept-flake-config` stays `false` in `base-system`)
  and sets them at system level. Accepting a flake's config is a trust decision, not a free win.
  `pipe-operators` covers imported modules but never `flake.nix` itself, which nix parses before reading
  `nixConfig`; see [`experimental-features.md`](./experimental-features.md).
- **3.7 Keep following clan-core's nixpkgs (decided).** The top-level `nixpkgs` node is a `tarball` because
  clan-core pins nixpkgs as a channel and this flake follows it — expected, not corruption. It is a floating
  pointer with no `rev`, so `nix flake update` moves it independently of clan-core (float it or
  `--override-input nixpkgs github:NixOS/nixpkgs/<rev>`), and it is `nixpkgs-unstable` rather than
  `nixos-unstable` because clan also targets darwin. Do not swap it: clan's
  `docs/src/guides/nixpkgs-flake-input/index.md` recommends following clan-core for a CI-verified
  combination, and Option 2's precondition — a package that has not landed — does not apply.
  `clan.checks.minNixpkgsVersion` would not catch a bad swap either: it only asserts `versionAtLeast "25.11"`, and this flake is on 26.11pre.

## 4. Upstream issues worth filing

- **4.1 nix-topology: the mosquitto extractor cannot handle a null address.** `nixos/extractors/services.nix`
  builds `address = l.address or "[::]"`, but `or` fires only when the attribute is absent, while nixpkgs
  declares `services.mosquitto.listeners.*.address` as `nullOr str` defaulting to `null` — so interpolation
  dies with `cannot coerce null to a string` (nixpkgs uses `lib.toString`, not at fault). Fix upstream:
  `"${toString address}:${toString l.port}"`; this repo overrides the derived service instead, so listening
  behaviour is unchanged. Still unfixed in the pinned revision and **not yet filed** (searched
  `repo:oddlama/nix-topology mosquitto`, zero results). Draft title and body, ready to paste:

  > **Mosquitto extractor throws `cannot coerce null to a string` on the default listener**
  >
  > `nixos/extractors/services.nix` reads `address = l.address or "[::]"`, but `or` only fires when the
  > attribute is *absent*. nixpkgs declares `services.mosquitto.listeners.*.address` as `nullOr str` with
  > `default = null`, so a listener that never sets `address` (the common case) interpolates `null` into
  > `"${address}:${toString l.port}"` and the diagram build fails with `cannot coerce null to a string`.
  > `toString` handles `null`; the interpolation does not. Suggested fix:
  > `address = if l.address == null then "[::]" else l.address;` — or `toString` on both sides.
  > Reproduced with a single `services.mosquitto.enable = true;` and one default listener.
- **4.2 nix-topology: document that the per-machine half is automatic.** The installation page, where a reader
  learns about `topology.modules`, never says `topology.nixosConfigurations` already defaults to every
  `nixosConfiguration` carrying a `topology` option — the gap that produced
  `topology.modules = [ config.nixosConfigurations ]`, redundant and an eval error `nix flake check` misses.

## 5. Considered and rejected

| Candidate | Why not |
| --- | --- |
| Rename `perSystem.devshells` to `devShells` | devshell maps the lowercase option into `devShells` itself; renaming loses `devshell.startup`/`devshell.env`. |
| Change `extraModules` from paths to strings | The string form is the deprecated one and warns at eval time. |
| Add `aarch64-linux` now | No machine for it; `systems` is a build contract, not a wish list. |
| `inputs.nix-systems` for `systems` | Pulls ~11 systems including darwin for a homelab. |
| Replace clan-core's channel-tarball nixpkgs with `github:NixOS/nixpkgs/nixos-unstable` | Clan's published guidance is to follow clan-core; see 3.7. |
| Collapse `flake-compat` | Two different upstream repositories (`NixOS/flake-compat`, `edolstra/flake-compat`), so there is nothing to follow. |
| Re-add `typos` to the pre-commit hooks | The existing block was `enable = false` with empty settings. If wanted, enable it properly and expect to build a word list. |
| Replace `nil` with `nixd` in the pre-commit hooks | git-hooks.nix ships a `nil` hook and no `nixd` hook; `nixd` is in the devshell, but a custom hook buys a lint `statix` and `deadnix` largely cover. |
