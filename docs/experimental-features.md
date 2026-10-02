# Experimental features

Which Nix experimental features this repository enables, why, and why the rest
are not. Priority order when guidance conflicts: **Clan.lol, then flake-parts,
then Nix3.**

## The one that matters: `pipe-operators`

`|>` and `<|` are why `pipe-operators` is enabled at all. Semantics, verified
against nix 2.35.2 rather than recalled:

- `a |> f` is `f a`, and `f <| a` is also `f a`. Left-associative, so
  `x |> f |> g` is `g (f x)`.
- **Function application binds tighter than `|>`.** `f 1 |> g` parses as
  `g (f 1)`. That is usually what you want, but it means the right-hand side
  needs parentheses whenever it is not a bare function: `1 |> f + 1` parses, but
  fails at evaluation with `cannot coerce a function to a string`, and
  `1 |> (f + 1)` is not valid either -- pipe only accepts a function on the
  right.
- Multi-argument functions work naturally: `3 |> add 4` is `add 4 3`.

Where it earns its place: a chain of whole-value transformations that currently
reads inside-out. `modules/hermes.nix` turns a list of bundle slugs into
`home.file` entries, which as nesting is `builtins.listToAttrs (map f slugs)`
and as a pipe is the same order you would say it out loud.

Where it does not: anything whose argument order puts the data last.
`lib.genAttrs config.systems f` takes the *names* first, so piping would invert
it and read worse than the call. Pipes are used in one place in this repository
and the rest is left alone on purpose -- a pipe on every expression is the same
mistake as a comment on every line.

## The full list

Everything nix 2.35.2 recognises — 19 features, probed from the binary rather
than a list recalled from documentation (two rows below pair related features):

| Feature | Enabled | Why |
| --- | --- | --- |
| `nix-command` | yes | The `nix` CLI. Set by clan-core; required. |
| `flakes` | yes | Required to evaluate any flake. Set by clan-core. |
| `pipe-operators` | yes | `\|>` and `<\|`. Contributed by `base-system`, see below. |
| `ca-derivations` | no | Content-addressed derivations. Not adopted upstream; would change store semantics. |
| `recursive-nix` | no | Nix-in-Nix. Needs the daemon configured for it; nothing here builds with it. |
| `dynamic-derivations` | no | Depends on `ca-derivations`. |
| `impure-derivations` | no | Same family; breaks reproducibility by design. |
| `fetch-closure` | no | Only meaningful with content addressing. |
| `local-overlay-store` | no | Experimental store layout; would require repartitioning. |
| `read-only-local-store` | no | Only useful for a store shared read-only. |
| `verified-fetches` | no | Requires a signature setup nothing here has. |
| `blake3-hashes` / `git-hashing` | no | Alternative hash schemes; no consumer. |
| `parse-toml-timestamps` | no | Narrow parser change; nothing reads TOML timestamps. |
| `auto-allocate-uids` / `cgroups` | no | Build isolation, needs daemon-side config and root. |
| `daemon-trust-override` | no | Security-relevant; deliberately off. |
| `external-builders` | no | Remote builder protocol; single-machine homelab. |
| `configurable-impure-env` | no | Widens what impure evaluation may read; not needed. |

Note `repl-flake` is **not** in the list: it was removed in nix 2.22, folded into
`flakes`.

## How it is enabled, and the three constraints

Four places, because they are four different contexts:

| Context | Where |
| --- | --- |
| Your interactive shell in the repo | the devshell's `NIX_CONFIG`, `flake.nix` |
| The machine's `nix.conf` | `nix.settings.experimental-features`, `modules/clanServices/base-system` |
| A caller that accepts the flake config | `nixConfig.extra-experimental-features`, `flake.nix` |
| A bare `nix` with no config accepted | nothing -- needs `nix.conf` or `NIX_CONFIG` |

**A flake cannot enable the feature for `flake.nix` itself, but it can for the
modules it imports.** This distinction is the whole point, and getting it wrong
is easy:

- `flake.nix` is parsed *before* `nixConfig` is read, so a `|>` written in
  `flake.nix` can never be self-enabled. That is a hard bootstrap limit.
- A `|>` in an **imported** module is evaluated *after* `nixConfig` applies, so
  the flake can and does enable it -- `nixConfig.extra-experimental-features`
  above, which works for any caller that accepts the flake config
  (`--accept-flake-config`, or `accept-flake-config = true`, which the machines
  here set).

Verified both ways on a scratch flake, with the pipe in an imported file:

```console
$ env -u NIX_CONFIG nix eval --accept-flake-config --json '.#x'
[3,4]                                    # the flake's own nixConfig enabled it

$ env -u NIX_CONFIG nix eval --json '.#x'
error: experimental Nix feature 'pipe-operators' is disabled
```

So the entry requirement is narrower than "always needs `nix.conf`": it applies
only to a caller that declines the flake config, or to a `|>` placed in
`flake.nix` itself. The devshell's `NIX_CONFIG` covers the interactive case, and
`direnv` (`use flake`) puts you in it.

**`flake.nix` and its `nixConfig` must be literal attribute sets.** Both a
top-level `let ... in` and a `let`-bound `nixConfig` are rejected:

```text
error: file '/path/flake.nix' must be an attribute set
error: expected a set but got a thunk at flake.nix:7:3
```

So the feature list cannot be hoisted into a shared binding at the flake root.
It is written twice instead, and each copy points at the other.

## The `nix.conf` concatenation trap

`nix.settings.experimental-features` is a list, and clan-core already sets

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

at normal priority (`nixosModules/clanCore/nix-settings.nix`). List options
merge by concatenation, so a second normal-priority definition is *appended*.
Two consequences, both learned the hard way:

- Repeating the two defaults gives the duplicated line
  `experimental-features = nix-command flakes nix-command flakes pipe-operators`.
  Harmless -- nix ignores the repeat -- but it reads as a bug.
- Wrapping the definition in `lib.mkDefault` makes it **lose** to clan's
  normal-priority definition, which silently drops the feature. The machine
  comes up without `pipe-operators` and this repository's own Nix code no longer
  evaluates on it.

So `base-system` contributes only the extra feature:

```nix
experimental-features = [ "pipe-operators" ];
```

which merges to `nix-command flakes pipe-operators`. Verified by reading the
generated `nix.conf` out of the derivation.
