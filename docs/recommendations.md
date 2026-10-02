# Recommendations

Forward-looking changes for the `phoenix` flake, in the priority order the
project cares about: Clan.lol, then flake-parts, then Nix3.

Everything below was checked against the actual option declarations at the
revisions pinned in `flake.lock` -- clan-core's `flakeModules/` and `modules/`,
nix-topology's `options/`, `nixos/modules/` and `flake-module.nix`,
flake-parts' `modules/`, devshell's `flake-module.nix`, git-hooks.nix's
`modules/hooks.nix` and `README.md` -- and against clan-core's own
`templates/clan/flake-parts/`, which is the shape Clan recommends for a
flake-parts clan. Where a claim comes from a doc rather than a declaration, the
file is named. Anything that was verified and deliberately left alone is
recorded under "Considered and rejected" so it does not get re-litigated.

## Applied on this branch

| # | Change |
| --- | --- |
| 1 | `modules/nix-topology.nix` pointed `topology.modules` at `config.nixosConfigurations`, which does not exist in that scope, so the whole output failed to evaluate. Repointed at the root `topology.nix`, which nothing imported. |
| 2 | Filled out the topology: uplink, home router, Windows host with its wired NIC and Hyper-V switch, the WSL machine as its guest, both networks. |
| 3 | `perSystem.clan.pkgs = pkgs` so clan's internal instantiations use the same pkgs as the devshell; dropped a redundant nix-topology overlay. |
| 4 | Added `description` and a `nixConfig` carrying the binary caches and `pipe-operators`. |
| 5 | Stopped tracking the generated `.pre-commit-config.yaml`; ignored `result-*`. |
| 6 | Collapsed duplicate inputs (34 to 24 lock nodes) and added `checks.<system>.topology`. |
| 7 | Generalised the weekly refresh job over every branch-tracking input. |

Row 6 covers `nixos-wsl`, `devshell`, `git-hooks` and `nix-topology` following
the pinned `nixpkgs`, `hermes-agent` following `home-manager` and `flake-parts`,
and clan-core's own `flake-parts` and `treefmt-nix`. Each followed node was at
the *same revision* as the one being followed, so nothing changed about what any
input evaluates with. The only duplicate left is `flake-compat`, which is two
genuinely different upstream repositories.

## 1. Clan.lol

### 1.1 Decide on `clan` vs `flake.clan`

`clan-core/flakeModules/clan.nix` opens with

```nix
# Backwards compatibility
imports = [ (lib.mkRenamedOptionModule [ "clan" ] [ "flake" "clan" ]) ];
```

so the top-level `clan` option is, as far as the option tree is concerned, a
renamed alias of `flake.clan`. In practice both spellings work and no warning
is emitted for the current one: clan-core's own `flake.nix` and its official
`templates/clan/flake-parts/flake.nix` both still write `clan = { ... }`, which
is what this repository does.

Recommendation: keep `clan` for now -- matching the official template is worth
more than anticipating the alias removal -- but know that the migration is a
one-line `clan = {` to `flake.clan = {` and nothing else moves. Watch for an
`Obsolete option 'clan' is used` trace appearing in `nix flake check` output.

### 1.2 Give the local clanServices a `README.md` and a `roles/` directory

`modules/inventoryClass/inventory.nix` documents what a clan service module
"must" have: a `README.md` carrying a `description`, a `features = [ "inventory" ]`
frontmatter entry, and a `roles/` subdirectory with one `{role}.nix` per role.
The current modules are single `default.nix` files with the manifest and the
single `default` role inlined.

This is not required for what the repository does today.
`lib/resolve-module/default.nix` resolves `module.input = "self"` straight out
of your own `clan.modules`, which is why the current shape builds and deploys.
It does matter for clan's docs and schema generation, and for anyone who ever
consumes these modules as a flake input rather than by name. Worth doing when a
second consumer appears, not before.

### 1.3 `machine.tags` is fine as written

`inventory.machines.<name>.tags` carries a computed definition
(`builtins.attrNames (filterAttrs ... config.tags)`) alongside whatever the
machine sets. Because the option is `types.listOf types.str`, which merges by
concatenation, the explicit `[ "all" "workstation" "wsl" ]` does **not**
displace the computed `nixos` tag. Verified:

```console
$ nix eval --json '.#clanInternals.inventoryClass.inventory.machines.workstation.tags'
["all","workstation","wsl","nixos"]
```

So there is nothing to fix here. The alternative -- moving the custom tags to
`inventory.tags.workstation` / `inventory.tags.wsl` -- is equally valid and
would let a machine be tagged without editing it, which is the mechanism to
reach for if tagging ever needs to happen from a single place.

### 1.4 Keep `extraModules` as paths

`lib/inventory/distributed-service/service-module.nix` wraps every *string*
entry of `extraModules` in

```nix
lib.warn "String types for 'extraModules' will be deprecated - ${s}" "${directory}/${s}"
```

and sends path entries through `lib.setDefaultModuleLocation` instead. The role
option's own documentation still shows the string form
(`extraModules = [ "modules/special.nix" ]`), so the docs lag the code. This
repository already passes paths -- do not "correct" them to match the example.

### 1.5 Machine metadata is unused

`inventory.machines.<name>` also takes `description` and `icon`, both of which
feed the CLI and the UI. Adding a `description` per machine is a cheap
improvement to `clan machines list` output and costs nothing.

### 1.6 Give future machines a `deploy.targetHost`

Already the plan in ADR-0001, restated because it is the first thing that will
be forgotten: a remote machine needs `inventory.machines.<name>.deploy.targetHost`
(and `deploy.buildHost` if it should be built elsewhere) before `clan deploy`
has anything to do. `workstation` correctly has none -- it is self-managed.

### 1.7 Consider `clan.templates` for the machine skeleton

`clan.templates` lets the flake ship its own scaffolding, so standing up the Pi
or the ThinkPad becomes `clan template` rather than copying
`machines/workstation/configuration.nix` by hand and forgetting the
`nix-topology` import. Worth doing at the same time as the second machine.

### 1.8 Run the clan CLI against the flake

The commands that read what is declared here:

```console
clan machines list
clan vars list workstation
clan vars generate workstation
```

`clan vars generate` should be a no-op for a settled machine; a diff means the
generators and the committed `vars/` tree have drifted. ADR-0001 flagged a
`root-password/` tree and a `mycelium/` tree as possibly stale -- neither exists
in the working tree now and neither was ever tracked by git, so that item is
resolved.

### 1.9 A clan-core doc bug that argues against its own code

`inventory.modules`' option text says each module must ship a `README.md` with a
`description` and a `features = [ "inventory" ]` frontmatter entry, and that this
is what makes it "usable with the inventory". That is not what the resolver
does: `lib/resolve-module/default.nix` resolves `module.input = "self"` straight
out of your own `clan.modules`, with no README involved. The README requirement
is real only for modules that go through clan's docs and schema generation --
i.e. for publishing a service, not for using one locally. See 1.2.

Related, and worth knowing before someone "fixes" `clan.nix`: clan-core's
`module.input` option declares `default = null` with the `defaultText` "Name of
the input. Default to 'null' which means the module is local" -- but the
resolver treats `null` as *clan-core*, not local:

```nix
input = if moduleSpec.input == null then { clan.modules = clanCoreModules; } else flakeInputs.${moduleSpec.input} or inputError;
```

Verified by setting `module.input = null` on the locally-defined `base-system`
instance: the build fails with

```text
error: clan-core doesn't provide clan-module with name 'base-system'.
```

So the comment in `clan.nix` is correct, and clan-core's `defaultText` is the
thing that is wrong. Leave the comment alone.

## 2. flake-parts

### 2.1 Add `aarch64-linux` to `systems` when the Pi exists

Declaring a system in `systems` means every `perSystem` output is expected to
evaluate for it, and `nix flake check --all-systems` will try to build them.
That is the correct contract and it is why the list currently has one entry:
`x86_64-linux` is the only architecture with a machine behind it. clan-core's
own template declares three, but it also has machines for them.

The alternative, if you would rather not maintain the list, is to adopt
`inputs.systems` the way clan-core does (`systems.url = "github:nix-systems/default/future-26.11"`).
That brings in roughly eleven systems including `aarch64-darwin`, which is a lot
of unused surface for a homelab. Recommend staying explicit.

### 2.2 Keep `perSystem.devshells` lowercase

`devshell/flake-module.nix` declares `perSystem.devshells` and maps it:

```nix
config.devShells = lib.mapAttrs (_name: devshell: devshell.devshell.shell) config.devshells;
```

with a description that says outright: "Not to be confused with `devShells`,
with a capital S. Yes, this is unfortunate." The lowercase option is what
numtide/devshell provides; renaming it to `devShells` would bypass the mapping
and lose `devshell.startup` and `devshell.env`. No change.

### 2.3 One module per concern under `modules/` is the right shape

flake-parts takes plain `imports` at the top level, and this repository's
`imports = [ ... ./modules/nix-topology.nix ./modules/git-hooks.nix ./modules/treefmt.nix ... ]`
is exactly that. The heavier machinery flake-parts offers -- `flake.modules`
for reusable flake-level modules, `partitions` for splitting a flake across
separate input closures -- is for flakes whose inputs or eval cost have become a
problem. Neither applies yet.

### 2.4 Use `withSystem` rather than a second nixpkgs when cross-building

The moment a second architecture lands, building its outputs from
`x86_64-linux` needs `withSystem`; a `perSystem` module must not reach into
another system's `pkgs`. This is the reason to resist the temptation of adding
`pkgsFor` helpers of your own.

### 2.5 Expose `flake.overlays` / `flake.nixosModules` only if consumed

Nothing consumes this flake today, so nothing is exposed. If another flake ever
imports `phoenix` -- to reuse `modules/clanServices/base-system`, say -- declare
`flake.nixosModules` and/or `flake.overlays.default` so it can be consumed
without `builtins.getFlake` and a store path.

## 3. Nix3

### 3.1 `nix flake check` only validates outputs it recognises

This is the lesson from the topology bug and the reason
`checks.<system>.topology` now exists. `nix flake check` knows a fixed set of
output names; anything else produces

```text
checking flake output 'topology'...
warning: unknown flake output 'topology'
```

and is skipped. Three outputs here are in that category: `topology` (now
covered), and `clan` / `clanInternals` (clan's own, nothing to cover). Any
future custom output should be paired with a `checks` entry for the same
reason.

### 3.2 `nix flake check --all-systems` once a second system is declared

Worth putting in CI at that point, since it is the flag that actually exercises
the `systems` list.

### 3.3 Decide whether to keep floating on the branch-tracking inputs

`caveman`, `nixos-wsl` and `hermes-agent` all track a branch rather than a tag,
and the weekly refresh job now advances and verifies each of them (applied table,
row 7). That makes floating safe against a *bad* revision, since a failure is
rolled back and reported -- but not silent: a good revision still lands on the
machine only at the next `nh os switch`.

The alternative is pinning any of them to a tag or a revision. The trade is
explicit: a tag stops surprise changes and stops surprise fixes, and all three of
these inputs are the kind that ship fixes. Recommended: keep floating.

### 3.4 `nix fmt` is wired; consider failing on drift in a pre-push hook

`treefmt` provides `formatter` and `checks.treefmt`, and the pre-commit hook
runs it on staged files. Verified: `nix flake check` reports
`checks.x86_64-linux` as `[ pre-commit topology treefmt ]`, so formatting *is*
covered by the check -- treefmt-nix names that check `treefmt`, not
`formatting`. A pre-push hook running `nix fmt -- --fail-on-change` would still
add something the check cannot: it catches drift in files that were written but
never staged, which neither the check nor the pre-commit hook sees.

### 3.5 What belongs in git

`flake.lock` is committed, which is correct -- a flake without a lock is not
reproducible. Build artifacts are not: `.pre-commit-config.yaml` is now ignored
per the git-hooks.nix README's explicit instruction, and `result` / `result-*`
were already ignored. The remaining generated-but-tracked trees are `vars/`
(public halves plus encrypted secrets -- clan expects these committed) and
`sops/` (same). Both are correct.

### 3.6 `nixConfig` carries caches and `pipe-operators`

The flake declares `nixConfig.extra-substituters` and
`extra-trusted-public-keys` so a third-party evaluator -- a CI runner, another
machine -- can substitute this flake's inputs by accepting the flake config.
Both machines here do (`nix.settings.accept-flake-config`,
`modules/clanServices/base-system`). It is worth remembering that this is a
trust decision, not a free win: accepting a flake's config means accepting its
substituters and its keys.

`extra-experimental-features = [ "pipe-operators" ]` covers the *imported
modules*, which nix evaluates after it has read `nixConfig`. It cannot cover
`flake.nix` itself, because nix parses that file before it reads `nixConfig` --
so a `|>` written there can never be self-enabled. That is the whole reason the
feature is declared in four places rather than one; see
[`experimental-features.md`](./experimental-features.md).

### 3.7 Keep following clan-core's nixpkgs (decided)

The top-level `nixpkgs` node in `flake.lock` is a `tarball`, not a GitHub
checkout, because clan-core pins nixpkgs as a channel and this flake follows it.
That is expected, not corruption. Two consequences worth knowing:

- It is a *floating* pointer. There is no `rev` to pin in the URL, so
  `nix flake update` moves nixpkgs to whatever the channel currently points at,
  independently of clan-core's own pinned revision. You can only float it or
  override it (`--override-input nixpkgs github:NixOS/nixpkgs/<rev>`).
- It is `nixpkgs-unstable`, not `nixos-unstable`. clan-core pins that
  deliberately, because clan also targets darwin and `nixos-unstable` is
  NixOS-only.

**Do not swap it for your own nixpkgs.** Clan publishes a recommendation for
this exact question, in `docs/src/guides/nixpkgs-flake-input/index.md` inside
the pinned clan-core tree:

> **Option 1: Follow clan-core (recommended)** ... This pins your flake to the
> same `nixpkgs` revision that `clan-core` pins. Every `clan-core` update brings
> a matching `nixpkgs` update, so you stay on a combination that has been
> verified end-to-end. The trade-off is that new upstream packages only reach
> you when `clan-core` bumps its input.
>
> **Option 2: Track your own nixpkgs** ... This gives you faster access to
> upstream changes, at the cost of running a combination that Clan's CI does
> not cover. Use it if you need a package or fix that has not yet landed in the
> version `clan-core` follows.

The repository already does Option 1, and Option 2's stated precondition -- a
package that has not landed yet -- does not apply. Swapping would trade a
CI-verified combination for an unverified one to gain nothing.

`clan.checks.minNixpkgsVersion` would not have caught a bad swap either way: it
asserts only `lib.versionAtLeast nixpkgs.lib.version "25.11"`, and this flake is
on 26.11pre. Nothing rescues Option 2; it is a choice against published
guidance, not a risk that gets caught.

## 4. Upstream issues worth filing

### 4.1 nix-topology: the mosquitto extractor cannot handle a null address

`nixos/extractors/services.nix` builds the listen string as

```nix
address = l.address or "[::]";
listen = if l.port == 0 then address else "${address}:${toString l.port}";
```

The `or` only fires when the attribute is absent, but nixpkgs declares
`services.mosquitto.listeners.*.address` as `nullOr str` defaulting to `null`.
The interpolation then sees null and the entire topology build dies with
`cannot coerce null to a string`. nixpkgs is not at fault: it renders the same
listener with `lib.toString`, and `lib.toString null` is `""`. The fix upstream
is `"${toString address}:${toString l.port}"`. This repository works around it by
overriding the derived service rather than giving the broker an `address`, so
its listening behaviour is unchanged.

### 4.2 nix-topology: document that the per-machine half is automatic

The installation page is where a reader learns about `topology.modules`, and it
does not say that `topology.nixosConfigurations` already defaults to every
`nixosConfiguration` carrying a `topology` option. That gap is what produced
`topology.modules = [ config.nixosConfigurations ]` -- a line that is both
redundant and an evaluation error, and that `nix flake check` cannot catch.

## 5. Considered and rejected

| Candidate | Why not |
| --- | --- |
| Rename `perSystem.devshells` to `devShells` | devshell maps the lowercase option into `devShells` itself; renaming loses `devshell.startup`/`devshell.env`. |
| Change `extraModules` from paths to strings | The string form is the deprecated one and warns at eval time. |
| Add `aarch64-linux` now | No machine for it; `systems` is a build contract, not a wish list. |
| `inputs.nix-systems` for `systems` | Pulls ~11 systems including darwin for a homelab. |
| Replace clan-core's channel-tarball nixpkgs with `github:NixOS/nixpkgs/nixos-unstable` | Clan's published guidance is to follow clan-core; see 3.7. |
| Collapse `flake-compat` | Two different upstream repositories (`NixOS/flake-compat` and `edolstra/flake-compat`), so there is nothing to follow. |
| Re-add `typos` to the pre-commit hooks | The existing block was `enable = false` with empty settings. If spell-checking is wanted, enable it properly and expect to build a word list. |
| Replace `nil` with `nixd` in the pre-commit hooks | git-hooks.nix ships a `nil` hook and no `nixd` hook. `nixd` is in the devshell already; adding it as a custom hook is possible but buys a lint that `statix` and `deadnix` largely cover. |
