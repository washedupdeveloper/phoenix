# phoenix

| Document | Covers |
| --- | --- |
| [`adr/`](./docs/adr/) | Decisions, with the options rejected and why. |
| [`flake-internals.md`](./docs/flake-internals.md) | The mechanisms inline comments point at: `nixConfig`, the two pkgs wirings, input `follows`, the topology check. |
| [`shell-integrations.md`](./docs/shell-integrations.md) | Which shell the fish-only integrations target, and the load-bearing key-binding spellings. |
| [`experimental-features.md`](./docs/experimental-features.md) | Enabled features, the `\|>` semantics, and the constraints on enabling them. |
| [`recommendations.md`](./docs/recommendations.md) | Outstanding work, ordered Clan.lol → flake-parts → Nix3. |
| [`testing.md`](./docs/testing.md) | The three test tiers, why the tier follows the assertion, and the VM environment requirements. |
| [`adding-a-machine.md`](./docs/adding-a-machine.md) | The steps a second machine needs and the failure each prevents. |

## Priority order

When sources disagree, the earlier one wins:

1. **Clan.lol** — this is a clan, and clan's guidance governs even when a
   flake-parts or Nix3 idiom looks cleaner. Read from the revision pinned in
   `flake.lock`, not the website.
2. **flake-parts** — where clan is silent: `perSystem`, `_module.args.pkgs`, module
   splitting, `imports`.
3. **Nix3** — syntax and CLI behaviour underneath both.

A conflict means checking whether a lower-priority source is being applied where it
does not belong, not flipping a coin.

## Inline comment convention

A comment earns its place only if the code cannot be understood without it: a
non-obvious requirement, a workaround, or why a line is written the surprising way.
One or two lines is the shape to aim for; the test is whether every line is
load-bearing, not how many there are.

When the reasoning outgrows the code, the comment becomes a pointer —
`See docs/flake-internals.md` — and the reasoning goes there.

Not inline: restating what the code says; what an option or default does (that is
upstream's documentation, and a second copy drifts); the evidence trail, which ages
badly; anything inferable from the surrounding lines.
