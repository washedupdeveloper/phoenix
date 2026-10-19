# Experimental features

Priority when guidance conflicts: **Clan.lol, then flake-parts, then Nix3.**

## `pipe-operators` (nix 2.35.2)

- `a |> f` is `f a`; `f <| a` is also `f a`. Left-associative: `x |> f |> g` is `g (f x)`.
- Application binds tighter: `f 1 |> g` is `g (f 1)`; the right side must be a function, so `1 |> f + 1` parses but fails at evaluation with `cannot coerce a function to a string`.
- Multi-argument: `3 |> add 4` is `add 4 3`.

Use it on whole-value chains (`builtins.listToAttrs (map f slugs)`), not where the data goes last: `lib.genAttrs config.systems f` takes the *names* first. No module uses it; `base-system` keeps it enabled for the clan.

## All 19 features

| Feature | On | Why |
| --- | --- | --- |
| `nix-command` | yes | the `nix` CLI; clan-core sets it |
| `flakes` | yes | needed for any flake; clan-core sets it |
| `pipe-operators` | yes | `\|>` / `<\|`; from `base-system` |
| `ca-derivations`, `dynamic-derivations`, `impure-derivations`, `fetch-closure` | no | content-addressing family; changes store semantics |
| `recursive-nix` | no | needs daemon config |
| `local-overlay-store`, `read-only-local-store` | no | store layout changes |
| `verified-fetches` | no | no signature setup here |
| `blake3-hashes`, `git-hashing` | no | no consumer |
| `parse-toml-timestamps` | no | nothing reads TOML timestamps |
| `auto-allocate-uids`, `cgroups` | no | daemon config + root |
| `daemon-trust-override` | no | security-relevant; deliberately off |
| `external-builders` | no | single-machine homelab |
| `configurable-impure-env` | no | widens impure evaluation |
| `repl-flake` | gone | removed in nix 2.22, folded into `flakes` |

## Where it is enabled

| Context | Where |
| --- | --- |
| Interactive shell in the repo | devshell `NIX_CONFIG`, `flake.nix` |
| The machine's `nix.conf` | `nix.settings.experimental-features`, `modules/clanServices/base-system` |
| Caller accepting the flake config | `nixConfig.extra-experimental-features`, `flake.nix` |
| Bare `nix`, config declined | nothing -- needs `nix.conf` or `NIX_CONFIG` |

**A flake cannot enable the feature for `flake.nix` itself, only for modules it imports** -- `flake.nix` is parsed *before* `nixConfig` is read, imported modules after:

```console
$ env -u NIX_CONFIG nix eval --accept-flake-config --json '.#x'   # -> [3,4]
$ env -u NIX_CONFIG nix eval --json '.#x'
error: experimental Nix feature 'pipe-operators' is disabled
```

`nix.conf` is therefore needed only by a caller that declines the flake config, or for a `|>` in `flake.nix` itself. `direnv` (`use flake`) covers the interactive case if the login shell matches the hook; see [`shell-integrations.md`](./shell-integrations.md).

**`flake.nix` and its `nixConfig` must be literal attribute sets** -- a top-level `let ... in` or `let`-bound `nixConfig` is rejected with `error: file '/path/flake.nix' must be an attribute set` / `error: expected a set but got a thunk at flake.nix:7:3`, so the list is written twice.

The clan CLI runs its own `nix eval` without `--accept-flake-config`, so with no ambient config any `|>` in an imported module fails:

```text
$ clan vars list workstation --flake .
Reason: experimental Nix feature 'pipe-operators' is disabled
    at .../modules/<module>.nix:NN:C
```

`base-system` sets it in `/etc/nix/nix.conf`, so on a machine the plain call works; elsewhere pass it through. `clan machines list` and `clan show` never evaluate the machine config:

```console
clan vars list workstation --flake . --option accept-flake-config true
```

## The `nix.conf` concatenation trap

clan-core sets, at normal priority (`nixosModules/clanCore/nix-settings.nix`):

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

List options concatenate, so a second normal-priority definition is *appended*: repeating the defaults gives `experimental-features = nix-command flakes nix-command flakes pipe-operators` (harmless, but reads as a bug), while `lib.mkDefault` on yours makes it **lose** to clan's, silently dropping the feature -- the machine then cannot evaluate this repo's own Nix code. So `base-system` contributes only the extra feature:

```nix
experimental-features = [ "pipe-operators" ];   # merges to nix-command flakes pipe-operators
```
