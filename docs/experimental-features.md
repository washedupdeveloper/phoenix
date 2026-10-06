# Experimental features

Which Nix experimental features this repository enables, why, and why the rest
are not. Priority order when guidance conflicts: **Clan.lol, then flake-parts,
then Nix3.**

## `pipe-operators`, and the `|>` semantics

Verified against nix 2.35.2:

- `a |> f` is `f a`; `f <| a` is also `f a`. Left-associative, so
  `x |> f |> g` is `g (f x)`.
- **Function application binds tighter than `|>`.** `f 1 |> g` is `g (f 1)`, and
  the right side must be a function: `1 |> f + 1` parses but fails at evaluation
  with `cannot coerce a function to a string`.
- Multi-argument functions work naturally: `3 |> add 4` is `add 4 3`.

Where it earns its place: chains of whole-value transformation that otherwise
read inside-out -- `builtins.listToAttrs (map f slugs)` becomes the order you
would say it out loud. No module in this repository uses it today; the feature
stays enabled because `base-system` sets it for the clan.

Where it does not: anything whose argument order puts the data last.
`lib.genAttrs config.systems f` takes the *names* first, so piping inverts it.
The one pipe this repository ever carried left with `modules/hermes.nix`
(`ed0e372`), and it was a considered result, not a house style; a pipe on every
expression would be the same mistake as a comment on every line.

## The full list

Everything nix 2.35.2 recognises -- 19 features, probed from the binary rather
than recalled (two rows below pair related features):

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

`repl-flake` is absent because it no longer exists: removed in nix 2.22, folded
into `flakes`.

## Where it is enabled

Four contexts, so four places:

| Context | Where |
| --- | --- |
| Your interactive shell in the repo | the devshell's `NIX_CONFIG`, `flake.nix` |
| The machine's `nix.conf` | `nix.settings.experimental-features`, `modules/clanServices/base-system` |
| A caller that accepts the flake config | `nixConfig.extra-experimental-features`, `flake.nix` |
| A bare `nix` with no config accepted | nothing -- needs `nix.conf` or `NIX_CONFIG` |

**A flake cannot enable the feature for `flake.nix` itself, but it can for the
modules it imports.** `flake.nix` is parsed *before* `nixConfig` is read, so a
`|>` written there can never be self-enabled -- a hard bootstrap limit. An
imported module is evaluated *after*, so `nixConfig.extra-experimental-features`
does cover it, for any caller that accepts the flake config:

```console
$ env -u NIX_CONFIG nix eval --accept-flake-config --json '.#x'
[3,4]                                    # the flake's own nixConfig enabled it

$ env -u NIX_CONFIG nix eval --json '.#x'
error: experimental Nix feature 'pipe-operators' is disabled
```

So "needs `nix.conf`" applies only to a caller that declines the flake config, or
to a `|>` placed in `flake.nix` itself. The devshell's `NIX_CONFIG` covers the
interactive case, and `direnv` (`use flake`) puts you in it -- provided the
login shell is the one the direnv hook was installed for, which is a separate
precondition; see [`shell-integrations.md`](./shell-integrations.md).

**`flake.nix` and its `nixConfig` must be literal attribute sets.** A top-level
`let ... in` and a `let`-bound `nixConfig` are both rejected:

```text
error: file '/path/flake.nix' must be an attribute set
error: expected a set but got a thunk at flake.nix:7:3
```

So the feature list cannot be hoisted into a shared binding at the flake root. It
is written twice instead, and each copy points at the other.

## Tooling that does not accept the flake config

The clan CLI runs its own `nix eval` calls and does not pass
`--accept-flake-config`, so with no ambient config it fails on any `|>` in an
imported module:

```text
$ clan vars list workstation --flake .
Reason: experimental Nix feature 'pipe-operators' is disabled
    at .../modules/<module>.nix:NN:C
```

On a machine this is moot: `base-system` sets `accept-flake-config = true` in
`/etc/nix/nix.conf`, so the plain invocation works. Elsewhere, pass it through:

```console
clan vars list workstation --flake . --option accept-flake-config true
```

`clan machines list` and `clan show` never evaluate the machine config, and are
unaffected either way.

## The `nix.conf` concatenation trap

clan-core sets, at normal priority (`nixosModules/clanCore/nix-settings.nix`):

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

List options merge by concatenation, so a second normal-priority definition is
*appended*. Two consequences:

- Repeating the two defaults yields
  `experimental-features = nix-command flakes nix-command flakes pipe-operators`.
  Harmless -- nix ignores the repeat -- but it reads as a bug.
- `lib.mkDefault` on your own definition makes it **lose** to clan's
  normal-priority one, silently dropping the feature. The machine then comes up
  unable to evaluate this repository's own Nix code.

So `base-system` contributes only the extra feature:

```nix
experimental-features = [ "pipe-operators" ];
```

which merges to `nix-command flakes pipe-operators`. Verified by reading the
generated `nix.conf` out of the derivation.
