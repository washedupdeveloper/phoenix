# ADR-0003: Build parallelism on the workstation machine

**Status:** Superseded — the cap is gone; see Outcome.
**Date:** 2026-10-03 (outcome 2026-10-19)
**Deciders:** nixolotl

## Context

`nh os switch` on `workstation` repeatedly ended with the Windows host powering off
and the next boot landing in firmware setup. The flake cannot be the cause: no
`boot.loader`, no `kernelParams`, no swap or zram, no shutdown unit, and
NixOS-WSL sets `system.boot.installBootLoader` to `true`, so a switch has no
firmware step.

A switch can still add load, and the heaviest build this flake had ever asked for
landed the same week: `programs.hermes-agent.desktop.enable` pulls in
`hermes-desktop`, which builds the Electron renderer and compiles `node-pty` from
source.

## Decision

Cap build parallelism in the machine's own configuration, not in `base-system`:
`max-jobs = 2`, `cores = 4`. The value is a **diagnostic**, not a performance
setting — if the host still powers off under a build that cannot saturate it, load
is exonerated and the fault is the host.

Machine-local because a build-parallelism limit is a statement about one host's
spare capacity, not a clan baseline. `base-system` carries timezone, locale, SSH
policy and the caches; `nixpkgs.hostPlatform`, `topology.self` and
`programs.nh.flake` are already machine-local. A cap inherited by a future Pi or
ThinkPad would be wrong for every machine but one.

Rejected: a shell alias or `nh` configuration, which covers only invocations a
human typed — not a cron job or a script.

Known limitation: `cores` sets `NIX_BUILD_CORES`, which make and ninja honour, but
a derivation spawning its own parallelism (npm, some Rust builds) may not. It
reduces the peak rather than bounding it.

## Outcome

The cap is gone. `nix.settings` sets neither key, because on NixOS both defaults
already mean "use the machine":

| setting | NixOS module default | resolves to |
| --- | --- | --- |
| `max-jobs` | `"auto"` | `nproc` — 12 here |
| `cores` | `0` | `NIX_BUILD_CORES=nproc` — 12 here |

The diagnostic was spent: the power-off was traced to host firmware, and the host
has been up for days since. Measured on the activated system with 12 derivations
each sleeping 5 s: **6 s** at the defaults, 12 s at the old cap, 62 s at
`max-jobs = 1`.

Two traps, both silent, both plausible:

- **`cores = 1` is a downgrade from the default of `0`.** Zero is the "use all
  cores" value; `1` forces every parallel-capable build (cargo, `make -j`, gcc)
  onto one thread. The conservative-looking number is the aggressive one.
- **The bare `nix.conf` default for `max-jobs` is `1`, the NixOS module's is
  `"auto"`.** Both true, different layers. Deleting the setting on NixOS does not
  serialize builds; on bare Nix it would. Only the module default governs this
  machine.

Worst case is now 12 jobs × 12 threads, though most nixpkgs derivations ignore
`NIX_BUILD_CORES` (`enableParallelBuilding` is opt-in), so the realistic load is
one thread per job. Bound a parallel, memory-hungry build at the invocation with
`--cores 8`. Peak memory is set by `.wslconfig` (`memory=16GB`, `swap=8GB`);
`autoMemoryReclaim=gradual` returns idle page cache to Windows and does not raise
that ceiling.

## Unrelated, and not the cause of the power-off

`X3D Gaming Mode` was powering down one of the 9900X3D's two CCDs and disabling
SMT, so the VM presented 6 cores / 6 threads instead of 12 / 24. Disabling the mode
restored the full count and silenced WSL's `wsl2.processors cannot exceed the
number of logical processors` warning, which fired because `.wslconfig` sets
`processors=12` and the firmware was reporting 6. A separate firmware symptom,
fixed separately.
