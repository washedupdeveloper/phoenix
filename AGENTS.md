# AGENTS.md

How to work in this repository. `README.md` maps `docs/`; `docs/adr/` records
decisions and the alternatives that were rejected. This file is the part needed
*before* editing.

## Verify

```bash
nix flake check --keep-going   # the gate (builds; see below)
nix fmt -- --ci                # formatting only -- treefmt runs nixfmt
nix develop                    # nixd, statix, deadnix, nixfmt, clan-cli
```

`nix fmt` formats and nothing else. **statix and deadnix are pre-commit
hooks, not treefmt formatters**, so they run on commit and a green `nix fmt`
says nothing about them.

**The whole gate runs on commit.** The pre-commit hook for `nix flake check`
refuses a commit unless the linters, the machine toplevel, the topology, the
unit groups and the VM tests all pass, so nothing is committed unchecked and
`nix flake check` is the only command needed. The hook is guarded on
`NIX_BUILD_TOP` — `nix flake check` runs these hooks again through
`checks.pre-commit`, so without the guard the gate would call itself. Changing
the hooks needs `nix develop` to reinstall them.

`nix flake check` is the gate, and it **builds**: `modules/flake/checks.nix`
derives `flake.checks` from `nixosConfigurations`, so every machine's toplevel
is built rather than merely evaluated. Without it a machine that evaluates but
fails to build would pass — the one failure a config repository most needs
caught.

`nix flake check` is also where the tests run, in three tiers.
`modules/flake/tests.nix` contributes `unit-<group>` (the *value* of an option,
milliseconds), `build-<group>` (the *file* the option rendered, seconds) and
`e2e-<name>` (what a running machine does with it, minutes, via
`pkgs.testers.runNixOSTest`). **Python is the price of the third tier and
nothing else** — an assertion that can be made against a rendered file must not
be made by booting a machine to look at it. `docs/testing.md` covers what each
tier can and cannot prove, and the two environment requirements the VM tests
depend on.

## Layout

| Path | Axis | Holds |
| --- | --- | --- |
| `flake.nix` | — | inputs, `nixConfig`, the `perSystem` block |
| `clan.nix` | clan | meta, machines, inventory (services and instances) |
| `modules/flake/` | per-system | flake-parts modules: `perSystem.*` and `flake.*` outputs |
| `modules/clanServices/` | per-machine | local clan services (`base-system`, `wsl`) |
| `modules/home/` | per-user | home-manager modules |
| `machines/<name>/` | per-machine | that machine's NixOS configuration |
| `topology.nix` | — | the physical model for nix-topology |
| `tests/` | per-system | test definitions, imported by `modules/flake/tests.nix` |

The axis is the point. `modules/flake/` is instantiated **once per system** and
contributes flake outputs; everything else is instantiated **per machine**. A
per-machine concern placed in `modules/flake/` is the mistake this split exists
to make visible — it would be evaluated once, for every machine at the same
time.

## Invariants

Each of these is a trap that yields a plausible-looking wrong result.

- **`nixConfig` stays literal.** Nix reads it before evaluating anything else
  and rejects a `let`-bound value with "expected a set but got a thunk". Keep
  each substituter adjacent to its key.
- **`_module.args.pkgs` must agree with `clan.pkgs`.** They are two wirings of
  the same package set; if they disagree, the devshell and the clan CLI
  disagree about `allowUnfree`.
- **`module.input = "self"` for a local clan service.** Official modules use
  `"clan-core"`. A null input resolves to clan-core, so a local service
  silently loads the wrong module.
- **The user identity is defined once**, in `modules/home/default.nix`, and
  reaches git and jj through `extraSpecialArgs`. Restating it in a tool module
  is how the two copies drifted before.
- **`networking.firewall.*` is inert here.** nixos-wsl disables the firewall
  unit, so a rule documents intent and does not filter. Do not read a rule as
  protection, and do not file a port finding from the config alone — check
  whether the unit is even running. This behaviour is set by the **nixos-wsl
  pin in `flake.lock`**, not by anything here, so a `nix flake update` can
  change it silently.
- **A new machine is a tag, not a list.** `user-nixolotl` and `home-manager` are
  assigned to clan's reserved `all` tag, which every machine carries
  automatically. Enumerating machines on those instances instead produces a
  machine that builds, boots, and has no account or no dotfiles — and nothing
  says so, because every other check reads a value that exists either way.
  `docs/adding-a-machine.md` has the full procedure and the assertion that
  catches each omission.
- **The cache lists exist twice** — `flake.nix`'s `nixConfig` (for other
  evaluators) and `base-system`'s `nix.settings` (for this machine). They are
  not required to match, but a cache added to one and not the other is inert on
  the machine that needs it.

## Conventions

**Priority order when sources disagree:** Clan.lol → flake-parts → Nix3. Clan
governs; its guidance is read from the revision pinned in `flake.lock`, not from
the website. A conflict is a signal that a lower-priority source is being
applied where it does not belong — not a coin to flip.

**Inline comments** state what is not evident and would cause a mistake: a
non-obvious requirement, a workaround, or why a line is written the surprising
way. `README.md` carries the full convention, including what does not belong
inline.

**No dead code.** A commented-out block is either annotated with why it is kept,
or deleted — git has it. An unannotated block is indistinguishable from one
someone forgot to remove.
