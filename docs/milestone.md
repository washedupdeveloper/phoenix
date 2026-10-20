# The fleet milestone

What "done" means for this repository, settled with the owner on 2026-10-20, and what
stands between here and it. Item-level work stays in
[`recommendations.md`](./recommendations.md) and is referenced by number, not copied;
the per-machine procedure stays in [`adding-a-machine.md`](./adding-a-machine.md). This
document holds the target and the order, and nothing else.

## The target

Three machines, all declared in this flake, all built by `nix flake check`, and all
reachable over SSH with their own secrets:

| machine | architecture | what it is |
| --- | --- | --- |
| `workstation` | `x86_64-linux` | Already exists: a WSL guest on the Windows host, self-managed, no `deploy` block. It keeps the services it has today. |
| `pi` | `aarch64-linux` | A Raspberry Pi 4 Model B. Bare minimum on purpose: it boots, it joins the overlay, and it runs nothing else. It is the always-on overlay peer, so a machine that is not at home can still reach the machines that are. |
| `thinkpad` | `x86_64-linux` | A bare-metal laptop, switched locally, LUKS full-disk, secrets in sops on disk. It carries mycelium, power and suspend settings, fingerprint login, file sync and the devshell toolchain — not just boot, an account and dotfiles. |

Decisions taken with the target. Each one is a constraint on the work below, not a
preference to re-litigate:

- **The transport is clan's mycelium service.** Machines are reachable by overlay
  address, and nothing is exposed to the internet to make that work.
- **The Pi is the always-on peer, not a service host.** The MQTT broker stays on
  `workstation`. Mycelium's hosted public nodes are discovery and NAT traversal; they do
  not make an offline machine reachable, which is the whole reason this role exists and
  why it can be the Pi's only job.
- **Remote machines are deployed to; the workstation is switched.** `clan deploy` over
  SSH for `pi` and `thinkpad`, local `switch` for `workstation`.
- **CI gates every change and runs at home.** A self-hosted runner on `workstation`,
  because the e2e tier needs `/dev/kvm` and GitHub-hosted runners do not have it. Pull
  requests with that job required before merge.
- **A service that needs a secret becomes a clan service with its own vars generator**,
  declared per machine. `mosquitto` is the first one that has to move.

## What is already in place

Stated so the gap is sized correctly rather than pessimistically. The gate's three tiers,
the topology model, the sops/age layout with per-machine keys, the tag-driven account and
`sshd-with-certs` instances, and `docs/adding-a-machine.md`'s procedure with the failure
each step prevents all generalize to N machines today. The unit groups are written over
"every machine" and "every home", so a new machine joins the existing assertions instead
of needing new ones. The fleet is not a rewrite.

## The gaps, in order

### 1. The build contract — no hardware needed

A Pi cannot even be declared before this. `test_every_machine_runs_on_a_declared_system`
compares each machine's `nixpkgs.hostPlatform.system` against `systems` in `flake.nix`,
which is `[ "x86_64-linux" ]`:

- add `aarch64-linux` to `systems` ([`adding-a-machine.md`](./adding-a-machine.md) step 6);
- decide how an `aarch64-linux` toplevel gets built on an `x86_64-linux` host, because
  the gate builds what it asserts. `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` on
  `workstation` keeps the gate self-contained — the property CI depends on — and the part
  to verify is the binfmt registration, not the emulation, since the kernel underneath
  the WSL guest is Windows'. The alternative, registering the Pi as a remote builder, is
  faster and makes the gate depend on a machine that is not always up;
- `clan.templates` for the machine skeleton (`recommendations.md` 1.7), before the second
  machine is written by hand;
- per-machine `description` and `icon` (1.5), and `deploy.targetHost` for the machines
  that need one (1.6).

### 2. CI, before the fleet grows — no hardware needed

- `.github/workflows/gate.yml`, with the gate as the job. The runner is
  `services.github-runners.<name>` on `workstation`, its `tokenFile` a new sops var, its
  labels `[ "self-hosted" "kvm" ]`, and its account in the `kvm` group — the e2e tier
  needs `/dev/kvm`, and that is the only place it exists.
- Branch protection on `main` requiring that job on pull requests.
- The job runs `nix flake check --keep-going`, the same command as the local hook, so a
  green PR and a green commit mean the same thing.
- `origin/main` is 12 commits behind this tree, so nothing can be a pull request until
  those land. Pushing is the owner's call, not a side effect of this plan.

### 3. The Pi — when the board is in hand

- New input `nixos-raspberrypi` (`github:nvmd/nixos-raspberrypi/main`, plus its cachix),
  and it arrives as a **module**, not as a system builder: clan owns the
  `nixpkgs.lib.nixosSystem` call, so board support goes in through
  `clan.specialArgs.nixos-raspberrypi` plus
  `imports = [ nixos-raspberrypi.nixosModules.raspberry-pi-4.base ]` in the machine. That
  flake's RPi-optimised overlays are applied globally only by its own `lib.nixosSystemFull`
  helper, which this call site cannot use, so what the base module takes from the flake
  has to be read rather than assumed.
- mycelium as a service instance, in the same `module.name` / `module.input = "clan-core"`
  form the `sshd` instance already proves, with its `peer` role assigned by tag. Its vars
  come from its own generator: `key` is a secret, `ip` and `pubkey` are public, and the
  service exports every peer's address.
- `deploy.targetHost`: the LAN address first. The overlay address would be better and is
  only known after `clan vars generate pi`; whether that public var is readable at
  evaluation time is unverified, so start with what is knowable.
- Boot: `boot.loader.raspberry-pi` comes from the flake, and the firmware partition is
  written on activation. Declarative disk layout (disko) against a hand-installed card is
  a hardware-time decision, made deliberately.

### 4. The ThinkPad — when the hardware is in hand

- LUKS and the bootloader module follow the same disk decision; the hardware config is
  generated on the machine, because the model decides the GPU and the fingerprint
  specifics and nothing here can guess them.
- mycelium peer — reachable through the Pi when away from home — power and suspend
  settings, fingerprint login, file sync, and the devshell toolchain.
- `deploy.targetHost` must be the overlay address here, not a LAN name: the machine roams,
  so a LAN address is wrong the first time it leaves the house.

### 5. Services become clan services

- `mosquitto` first, and it keeps running on `workstation`: the instance declares where it
  runs and its password becomes a generator's file instead of a hand-run command. The two
  places that move with it are the hand-enabled block in the machine's configuration and
  the topology `details` override that
  [ADR-0002](./adr/0002-topology-modelling.md) decision D records.
- Every later service follows the same shape. That rule is what keeps `vars/` and the
  generators from drifting apart, which is the failure the vars store's secrets exist to
  prevent.

## Deferred on purpose

- **Disk layout** — disko against hand-installed, for both machines, at hardware time.
- **Backups.** Offered as the Pi's first job and not chosen: the Pi is a peer first.
- **The Pi's growth path.** The stated intention is that it eventually manages the home
  network (DNS and its neighbours). Building for that now would be a guess, and the
  milestone does not depend on it.
- **Whether services stay on `workstation`** once the fleet is real.

## What "reached" means

All three machines are declared, `nix flake check` builds all three on the runner for the
merge that carries the last of them, and a `clan deploy` has changed something on `pi` and
on `thinkpad` over SSH without a local switch. Until the last of those is true, the fleet
is declared and not deployed.
