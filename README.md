# phoenix docs

| Document | Covers |
| --- | --- |
| [`adr/`](./docs/adr/) | Decisions, with the options that were rejected and why. |
| [`flake-internals.md`](./docs/flake-internals.md) | The non-obvious mechanisms the inline comments point at: `nixConfig`, the two pkgs wiring, input `follows`, the topology check. |
| [`shell-integrations.md`](./docs/shell-integrations.md) | Which shell the fish-only integrations (direnv, `nix-your-shell`, starship) are written for, why the login shell has to match, and the fish key-binding spellings that are load-bearing. |
| [`experimental-features.md`](./docs/experimental-features.md) | Which Nix experimental features are enabled and why, the `\|>` semantics, and the constraints on enabling them. |
| [`recommendations.md`](./docs/recommendations.md) | Outstanding work, ordered Clan.lol -> flake-parts -> Nix3. |

## Priority order

When the three sources disagree, the earlier one wins:

1. **Clan.lol** -- this is a clan, and clan's published guidance governs. If
   clan says to do something a certain way, do that, even when a flake-parts or
   Nix3 idiom looks cleaner. Clan's docs are read from the pinned revision in
   `flake.lock`, not from the website.
2. **flake-parts** -- where clan is silent, the flake-parts idiom decides:
   `perSystem`, `_module.args.pkgs`, module splitting, `imports`.
3. **Nix3** -- syntax and CLI behaviour underneath both: experimental features,
   the new CLI, the flake output set.

A conflict is a signal to check whether the lower-priority source is being
applied where it does not belong, not a coin to flip.

## Inline comment convention

An inline comment earns its place only if the code cannot be understood without
it. Concretely, it states what is **not evident** and **would cause a mistake**
if unknown: a non-obvious requirement, a workaround, or the reason a line is
written the surprising way. One or two lines, at a glance.

When the reasoning needs more room, the comment becomes a pointer -- `See
docs/flake-internals.md` -- and the reasoning goes here.

What does not belong inline:

- restating what the code already says;
- what an option, function or default does; that is upstream's documentation,
  and a second copy of it drifts;
- the evidence trail ("verified with ...", "the lock carried ..."), which ages
  badly and is unreadable at the point of use;
- anything the reader can infer from the surrounding lines.

Rationale, evidence, worked examples and rejected alternatives live in `docs/`.
