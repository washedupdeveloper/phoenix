# phoenix docs

| Document | Covers |
| --- | --- |
| [`adr/`](./adr/) | Decisions, with the options that were rejected and why. |
| [`flake-internals.md`](./flake-internals.md) | The non-obvious mechanisms the inline comments point at: `nixConfig`, the two pkgs wiring, input `follows`, the topology check. |
| [`hermes-agent-provisioning.md`](./hermes-agent-provisioning.md) | How the agent's skills are packaged, refreshed and loaded. |
| [`recommendations.md`](./recommendations.md) | Outstanding work, ordered Clan.lol -> flake-parts -> Nix3. |

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
