# ADR-0003: Capping build parallelism on the workstation machine

**Status:** Accepted
**Date:** 2026-10-03
**Deciders:** nixolotl

## Context

`nh os switch` on `workstation` repeatedly ended with the Windows host powering
off and the next boot landing in firmware setup. The flake is not the cause and
cannot be: it declares no `boot.loader`, no `kernelParams`, no swap or zram, and
no unit that reboots or shuts down the host. NixOS-WSL runs the Microsoft
kernel and sets `system.boot.installBootLoader` to `true`, so a switch has no
firmware step at all.

A switch can still *add load*, and the heaviest thing this flake has ever asked
the machine to build landed the same week: `programs.hermes-agent.desktop.enable`
pulls in `hermes-desktop`, which builds the Electron renderer, compiles
`node-pty` from source against `electron.headers`, and stages native
dependencies. That build ran on a VM that was, separately, reporting only
6 vCPUs and 6 threads.

That second problem is diagnosed and fixed, and it is worth recording that it
was *not* the power-off: the host firmware had `X3D Gaming Mode` enabled, which
powers down one of the 9900X3D's two CCDs and disables SMT, leaving 6 cores /
6 threads instead of 12 / 24. WSL passed the reduced count straight through as
`nr_cpus=6`. Disabling the mode restored 12 cores / 24 threads, and the WSL
`wsl2.processors cannot exceed the number of logical processors` warning
disappeared with it. That warning compares the configured count against the
count Windows reports, and `.wslconfig` does configure one -- `processors=12`,
half the host's 24. With the firmware reporting 6, the configured 12 exceeded
it and the warning fired; restoring 12 logical processors satisfied it.
*Corrected on 2026-10-11: this paragraph previously claimed `.wslconfig` had no
`processors` key, which it has had since it was written.*

So the load is not the whole story, and the host is still under investigation
for the power-off itself (memory profile, firmware, WHEA). The cap below is a
guardrail for the interval, not a fix.

## Decision

1. **Cap build parallelism on the machine, not in the clan.** `nix.settings`
   gains `max-jobs = 2` and `cores = 4` in
   `machines/workstation/configuration.nix`: at most 8 concurrent compile
   threads out of 24, leaving the rest of the VM and the Windows host headroom
   while the power-off is unexplained. *Raised on 2026-10-04 to `max-jobs = 6`
   and `cores = 2` — still 12 threads, half the host's 24 — once the power-off
   had been traced to the host firmware rather than to build load; the live
   numbers are in that file, this paragraph is the record.*
2. **The knob is deliberately low and deliberately tunable.** It is a
   diagnostic guardrail, not a performance setting. Raise it once the host is
   stable.
3. **The cap has to be applied by a switch, which is the risky operation.**
   The first build after this change should pass the limits on the command
   line rather than relying on the ones being installed:

   ```console
   nix build .#nixosConfigurations.workstation.config.system.build.toplevel \
     --max-jobs 6 --cores 2 --keep-going
   nh os switch
   ```

   Splitting build from activation also makes a failure unambiguous: dying
   during the build is load, dying during activation is something else.

## Options Considered

### Option A: `nix.settings` in `base-system` (rejected)

`base-system` is the clan's baseline and every machine gets it.

| Dimension | Assessment |
| --- | --- |
| Reach | Every machine, including ones that do not exist yet |
| Correctness | Low -- the cap encodes this host's headroom, not a clan-wide policy |
| Cost of being wrong | High -- a future Pi or ThinkPad would silently inherit a cap chosen for a WSL guest under investigation |

**Pros:** one place, and the setting is in `nix.settings` where a reader looks
for it.

**Cons:** it is a per-host fact in a per-clan module. A Raspberry Pi and a
ThinkPad have entirely different headroom, and neither should be slowed by a
number picked for a Windows host that was crashing. A cap that is wrong for
every machine but one is worse than no cap.

### Option B: `nix.settings` in the machine's own configuration (chosen)

| Dimension | Assessment |
| --- | --- |
| Reach | Exactly one machine |
| Correctness | High -- the value travels with the host it describes |
| Cost of being wrong | Low -- one file to edit, and the next machine sets its own |

**Pros:** the cap sits next to the machine it is about, and the comment points
at this ADR for the reasoning.

**Cons:** the setting is invisible from `base-system`, so a reader comparing
machines has to look at each. Acceptable: machine-local settings are supposed to
live in machine-local files.

### Option C: cap only in the shell, via an alias or `nh` configuration

`nh` and `nixos-rebuild` accept `--max-jobs` / `--cores`, and a shell alias
could pass them every time.

| Dimension | Assessment |
| --- | --- |
| Reach | Interactive invocations only |
| Reliability | Low -- anything that does not go through the alias is uncapped |

**Pros:** nothing to activate, so it applies before the risky switch.

**Cons:** it protects the one path that a human typed and nothing else. The
build that actually crashed the box came from a switch, which a shell alias
would cover -- but a cron job, a `nix build` from a script, or an interactive
session that forgot the alias would not be. The declarative cap is the durable
one; the command-line form is the bootstrap, and the decision keeps both.

## Trade-off Analysis

The real question is scope, and the two candidates answer it differently.
`base-system` is the clan's definition of a baseline machine; a build-parallelism
limit is not a baseline, it is a statement about one host's spare capacity. The
repository already draws that line elsewhere -- `nixpkgs.hostPlatform`,
`topology.self`, `services.mosquitto` and the `programs.nh.flake` path are all
machine-local, while `base-system` carries timezone, locale, SSH policy and the
binary caches.

There is also an asymmetry in the cost of getting it wrong. Putting the cap in
`base-system` and later finding it too low for a Pi means every machine carries
a number nobody re-examined; putting it in the machine means a new machine
simply does not have one until someone decides it should.

The honest limitation: `cores` sets `NIX_BUILD_CORES`, which make and ninja
respect, but a derivation that spawns its own parallelism -- an npm or Node
build, some Rust builds -- may not honour it. This reduces the peak rather than
bounding it, and it is a guardrail against a crashing host, not a resource
policy.

## Consequences

- `nh os switch` and `nixos-rebuild switch` on `workstation` build at most six
  derivations at a time, two cores each. The daemon reads `/etc/nix/nix.conf`,
  so the cap applies to every invocation, not just the ones a human typed.
- A command-line `--max-jobs` or `--cores` still overrides it, which is what
  the bootstrap in Decision (3) relies on.
- Nothing changes for any other machine, including the Pi and the ThinkPad that
  ADR-0001 plans: they will not have the setting at all until one is added
  deliberately.
- The cap outlives its reason if nobody revisits it. It is in the machine's own
  file precisely so that it is found when that machine is next worked on.
- This does not explain or fix the power-off. If the host turns out to be
  stable at stock memory settings, the cap can be raised or removed, and the
  finding belongs in a later ADR rather than in this one.

## Action Items

1. [x] Cap declared in `machines/workstation/configuration.nix`.
2. [ ] Apply it with an explicitly capped build, then confirm the rendered
   `nix.conf` carries the two keys:
   `grep -E '^(max-jobs|cores)' /etc/nix/nix.conf`.
3. [ ] Get the host's power-off explained -- firmware/BIOS date, whether a
   BIOS update or CMOS clear happened this week, memory profile (EXPO on or
   off), and the Kernel-Power (41), unexpected-shutdown (6008) and WHEA events
   from the System log. A BIOS reset would explain both the game mode returning
   to its default and the memory profile reverting, which is the leading
   candidate for the shutdown.
4. [ ] Once the host is stable at stock, decide whether the cap stays, rises,
   or goes.
