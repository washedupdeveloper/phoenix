# Flake internals

The mechanisms in `flake.nix`, `clan.nix` and `modules/nix-topology.nix` that are
not obvious from reading them. Each section is the elaboration behind a short
inline comment.

## `nixConfig`: caches, plus `pipe-operators` for the imported modules

`nixConfig.extra-substituters` and `extra-trusted-public-keys` are declared so a
third-party evaluator -- a CI runner, another machine -- can substitute this
flake's inputs by accepting the flake config. The keys match what
`modules/clanServices/base-system` already trusts, and both machines set
`nix.settings.accept-flake-config`, so nothing new is being asked for.

A flake's `nixConfig` is opt-in for the caller, which is why the devshell also
exports `NIX_CONFIG`. Accepting it is a trust decision: accepting a flake's
config means accepting its substituters and its keys.

`extra-experimental-features = [ "pipe-operators" ]` reaches the *imported
modules*, which nix evaluates after it has read `nixConfig`, but not `flake.nix`
itself: nix parses that file first, so a `|>` written there can never be
self-enabled. That is why the feature is declared in four places rather than
one -- see [`experimental-features.md`](./experimental-features.md).

## Two pkgs wirings that must agree

`perSystem` has two separate package sets, and they are easy to confuse.

`perSystem._module.args.pkgs` is what `perSystem` itself uses -- the devshell,
any `packages.*`, anything else evaluated in that scope. Setting it to
`import inputs.nixpkgs { config.allowUnfree = true; }` is the documented way to
give `perSystem` a nixpkgs with a non-default config.

`perSystem.clan.pkgs` is what clan uses for the per-system instantiations it
keeps internally: `clanInternals.machines`, which is what the vars generators
are built from, and what `clan machines` / `clan vars` read through the CLI.
Clan falls back to a plain `nixpkgs.legacyPackages` when this is unset.

Leaving the second one out is the interesting failure: the devshell would allow
unfree packages and the clan CLI would not, and the two would disagree about
what the same flake builds. Verified that setting it has the intended effect --
`clanInternals.machines.x86_64-linux.workstation` reports
`nixpkgs.pkgs.config.allowUnfree = true`.

It does **not** change `nixosConfigurations`. Clan builds those with
`nixosSystem` without passing pkgs, so the deployed system keeps deriving its
pkgs from `nixpkgs.hostPlatform` and the `nixpkgs.*` options. Confirmed by the
`system.build.toplevel` derivation path being byte-identical with and without
this line. This is also the pairing clan's own `templates/clan/flake-parts/`
shows.

No overlay for nix-topology is needed anywhere: its flake module defaults
`perSystem.topology.pkgs` to `pkgs.extend (import ./pkgs/default.nix)`, which is
the same overlay it exports.

## `systems` is a build contract

A system listed here is a promise that every `perSystem` output evaluates for
it, and `nix flake check --all-systems` will try to build them. So a system
earns its place by having a machine behind it. `x86_64-linux` is the only one
today; `aarch64-linux` joins when the Pi does.

The alternative -- `inputs.systems` / `nix-systems`, as clan-core itself uses --
brings roughly eleven systems including `aarch64-darwin`. That is a lot of
unused surface for a homelab.

## Input `follows`

Each input here is consumed as a flake **module** -- `nixosModules.default`,
`flakeModule`, `flakeModules.default` -- which is evaluated against this flake's
pkgs and flake-parts. None is consumed as a package built against its own
nixpkgs, so each can follow the pinned copies instead.

`flake.lock` went from 34 nodes to 24. The collapses:

| Input | Follows | Removes |
| --- | --- | --- |
| `nixos-wsl` | `nixpkgs` | its own nixpkgs |
| `devshell` | `nixpkgs` | its own nixpkgs |
| `git-hooks` | `nixpkgs` | its own nixpkgs |
| `nix-topology` | `nixpkgs`, `flake-parts` | its own nixpkgs and flake-parts |
| `clan-core` | `flake-parts`, `treefmt-nix` | two duplicates |

In every case the followed node was at the *same revision* as the one being
followed, so nothing about what any input evaluates with changed. clan-core's
`flake.nix` anticipates the treefmt-nix one by name:

```nix
# Make treefmt-nix optional
# This only works if you set inputs.clan-core.inputs.treefmt-nix.follows
# to a non-empty input that doesn't export a flakeModule
```

The one duplicate left is `flake-compat`: two genuinely different upstream
repositories (`NixOS/flake-compat` and `edolstra/flake-compat`), so there is
nothing to follow.

## Why the topology output is also a check

`nix flake check` knows a fixed set of output names. Anything else produces

```text
checking flake output 'topology'...
warning: unknown flake output 'topology'
```

and is skipped entirely -- not evaluated, not built. So a `topology` output that
fails to evaluate passes `nix flake check` silently.

That is exactly how this repository's diagram came to be broken: the wiring read
`topology.modules = [ config.nixosConfigurations ]`, but `config.nixosConfigurations`
does not exist at flake-parts top level (the flake output is
`config.flake.nixosConfigurations`). The output had never once evaluated, and
the only visible symptom was a dangling `result` symlink at the repository root.

`modules/nix-topology.nix` re-exposes `config.flake.topology.<system>.config.output`
as `checks.<system>.topology`, so the diagram is evaluated and built by
`nix flake check`. Verified by injecting a dangling connection and re-running:

```text
$ nix flake check --no-build
error:
Failed assertions:
- topology: nodes.home-router.interfaces.bogus.physicalConnections refers to an
  unknown node/interface nodes.no-such-node.interfaces.nope
```

Any future custom flake output should be paired with a `checks` entry for the
same reason.

## `topology.modules` takes modules, not machines

nix-topology already defaults `perSystem.topology.nixosConfigurations` to

```nix
lib.filterAttrs (_: x: x.config ? topology) self.nixosConfigurations
```

so every machine that imports `nix-topology.nixosModules.default` joins the
diagram on its own, with no wiring. `topology.modules` is for *additional
topology modules* -- here, the repository root's `topology.nix`, which holds the
things that cannot be derived from a single machine.

Passing `nixosConfigurations` to it instead is both redundant and wrong: a bare
attrset of NixOS configurations is evaluated as a topology module, and their
attribute names become unknown options.

The wiring is verified: `topology.x86_64-linux.config.nodes` returns
`home-router`, `internet`, `windows-host` and `workstation`, and the rendered
`main.svg` carries the router, both networks and the guest relationship.

## `module.input` and clan-core's contradicting default

`clan.modules.<name>` registers a locally-authored `clan.service`, and instances
reference it with `module.input = "self"`. `"self"` is required and not
optional, because the resolver sends `null` to *clan-core* rather than to local
modules:

```nix
input = if moduleSpec.input == null then { clan.modules = clanCoreModules; } else flakeInputs.${moduleSpec.input} or inputError;
```

clan-core's own option declares `default = null` with the `defaultText` "Name of
the input. Default to 'null' which means the module is local", which contradicts
the resolver. Verified by setting `module.input = null` on the locally-defined
`base-system` instance:

```text
error: clan-core doesn't provide clan-module with name 'base-system'.
```

So the comment in `clan.nix` is correct and clan-core's `defaultText` is the
thing that is wrong. Worth reporting upstream; see
[`recommendations.md`](./recommendations.md).

## The mosquitto workaround

`machines/workstation/configuration.nix` force-overrides the mosquitto service
description that nix-topology derives. That is not a description of the service:
it works around an upstream bug where the extractor interpolates a listen
address that nixpkgs declares as `nullOr str`. The full analysis, and why the
workaround is here rather than in the broker's configuration, is in
[ADR-0002](./adr/0002-topology-modelling.md).
