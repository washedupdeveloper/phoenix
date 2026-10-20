# Flake internals

## `nixConfig`: caches, plus `pipe-operators`

`extra-substituters` / `extra-trusted-public-keys` are for *other* evaluators that
accept the flake config. `modules/clanServices/base-system` trusts nix-community,
pre-commit-hooks and numtide but **not** `cache.clan.lol`, so this machine needs
neither that config nor `accept-flake-config`, and never substitutes from clan's cache.
`accept-flake-config` stays at nix's default (`false`) on purpose: it means trusting a
flake's substituters and keys, which should not happen silently; the devshell exports
`NIX_CONFIG` instead.

`nixConfig` also carries `extra-experimental-features = [ "pipe-operators" ]`, which
reaches the *imported modules* — evaluated after `nixConfig` is read — but not
`flake.nix`, parsed first, so a `|>` there can never be self-enabled. Hence three
declarations; see [`experimental-features.md`](./experimental-features.md).

## Two pkgs wirings that must agree

`perSystem._module.args.pkgs` is what `perSystem` uses — devshell, `packages.*`;
`import inputs.nixpkgs { config.allowUnfree = true; }` is the documented non-default
config. `perSystem.clan.pkgs` is what clan uses for `clanInternals.machines` — the vars
generators, and what `clan machines` / `clan vars` read; unset, clan falls back to
`nixpkgs.legacyPackages`. Omit the second and the devshell allows unfree while the CLI
does not. Verified: `clanInternals.machines.x86_64-linux.workstation` reports
`nixpkgs.pkgs.config.allowUnfree = true`. It does **not** change
`nixosConfigurations`: clan builds those with `nixosSystem` without pkgs, so the system
still derives pkgs from `nixpkgs.hostPlatform` and the `nixpkgs.*` options, and the
`system.build.toplevel` path is byte-identical either way.

## `systems` is a build contract

A listed system promises every `perSystem` output evaluates for it, and
`nix flake check --all-systems` builds them — so a system needs a machine behind it.
`x86_64-linux` today; `aarch64-linux` with the Pi.

## Input `follows`

Each input is a flake **module** (`nixosModules.default`, `flakeModule`,
`flakeModules.default`) evaluated against this flake's pkgs and flake-parts, never a
package built against its own nixpkgs, so each can follow the pinned copies:
`nixos-wsl`, `devshell` and `git-hooks` follow `nixpkgs`; `nix-topology` follows
`nixpkgs` and `flake-parts`; `clan-core` follows `flake-parts` and `treefmt-nix`.
Every followed node was at the *same revision*, so no input's evaluation changed.
clan-core documents the treefmt-nix case: `inputs.clan-core.inputs.treefmt-nix.follows`
must name a non-empty input that exports no flakeModule. `hermes-skills` is the one
remaining duplicate nixpkgs: it is consumed as a package tree, not as a module, and only
`packages.hermes-harness-audit` builds anything from its own pkgs.

`hermes-agent` is the exception to that framing: it *is* a package, and its `nixpkgs` is
followed deliberately. Upstream's own overlay (`hermes-agent.overlays.default`) is a pure
alias for the package its own nixpkgs built, so no overlay can move it onto another
nixpkgs — the only seam that does is the input's `nixpkgs`. clan-core's nixpkgs input is
the `nixpkgs-unstable` channel, so following it builds the agent, its uv2nix venv and its
runtime tools with the machine's own nixpkgs: one nixpkgs, one Python, one glibc.

The cost is real and it is why the follow was absent before: the derivation stops matching
anything in the binary cache, so the venv is rebuilt locally (157 derivations, ~70 MiB
fetched, on the first build). `nix flake update clan-core` moves it forward with the rest
of the machine; there is no separate nixpkgs to keep current.

## Why the topology output is also a check

`nix flake check` knows a fixed set of output names; anything else produces `warning:
unknown flake output 'topology'` and is skipped — not evaluated, not built. A
`topology` output that fails to evaluate therefore passes silently. This diagram broke
exactly so: the wiring read `topology.modules = [ config.nixosConfigurations ]`, which
does not exist at flake-parts top level (it is `config.flake.nixosConfigurations`), so
it had never evaluated; the only symptom was a dangling `result` symlink.
`modules/flake/nix-topology.nix` re-exposes `config.flake.topology.<system>.config.output`
as `checks.<system>.topology`, verified by injecting a dangling connection (any future
custom flake output needs a `checks` entry for the same reason):

```text
$ nix flake check --no-build
- topology: nodes.home-router.interfaces.bogus.physicalConnections refers to an
  unknown node/interface nodes.no-such-node.interfaces.nope
```

## `topology.modules` takes modules, not machines

nix-topology defaults `perSystem.topology.nixosConfigurations` to
`lib.filterAttrs (_: x: x.config ? topology) self.nixosConfigurations`, so every
machine importing `nix-topology.nixosModules.default` joins the diagram unasked.
`topology.modules` is for *additional topology modules* — here the root `topology.nix`,
holding what no single machine can derive. Passing `nixosConfigurations` is redundant
and wrong: a bare attrset of NixOS configurations is evaluated as a topology module and
its attribute names become unknown options. Verified: `main.svg` carries the router,
both networks and the guest link.

## `module.input` and clan-core's contradicting default

`clan.modules.<name>` registers a local `clan.service`; instances reference it with
`module.input = "self"`, required because the resolver sends `null` to *clan-core*, not
to local modules:

```nix
input = if moduleSpec.input == null then { clan.modules = clanCoreModules; } else flakeInputs.${moduleSpec.input} or inputError;
```

clan-core's option says `default = null`, `defaultText` "Name of the input. Default to
'null' which means the module is local" — contradicting the resolver. Setting
`module.input = null` on the local `base-system` instance gives `error: clan-core
doesn't provide clan-module with name 'base-system'.` `clan.nix` is right, clan-core's
`defaultText` is wrong. Worth reporting upstream:
[`recommendations.md`](./recommendations.md).

## The mosquitto workaround

`machines/workstation/configuration.nix` force-overrides the mosquitto description
nix-topology derives: the extractor interpolates a listen address nixpkgs declares as
`nullOr str`, an upstream bug. Why here, not in the broker: [ADR-0002](./adr/0002-topology-modelling.md).
