# The fleet milestone

What "done" means for this repository, settled with the owner on 2026-10-20, and what
stands between here and it. Item-level work stays in
[`recommendations.md`](./recommendations.md) and is referenced by number, not copied;
the per-machine procedure stays in [`adding-a-machine.md`](./adding-a-machine.md). This
document holds the target and the order, and nothing else.

## The target

**Readiness, not installation** (owner's statement, 2026-10-20): the test of this
milestone is that adding either new machine is *mechanical*. From a clone: create
`machines/<name>/configuration.nix` from a template, declare it once in `clan.nix`,
generate its vars, run the gate, deploy — nothing else touched, nothing researched, and
no step that works only because someone remembered it. The machines below are the test
of that readiness, not the work itself.

Three machines, all declared in this flake, all built by `nix flake check`, and all
reachable over SSH with their own secrets:

| machine | architecture | what it is |
| --- | --- | --- |
| `workstation` | `x86_64-linux` | Already exists: a WSL guest on the Windows host, self-managed, no `deploy` block. It keeps the services it has today. |
| `pi` | `aarch64-linux` | A Raspberry Pi 4 Model B. Bare minimum on purpose: it boots, it joins the overlay, and it runs nothing else. It is the always-on overlay peer, so a machine that is not at home can still reach the machines that are. |
| `thinkpad` | `x86_64-linux` | A bare-metal laptop, switched locally, secrets in sops on disk. It carries mycelium, power and suspend settings, fingerprint login, file sync and the devshell toolchain — not just boot, an account and dotfiles. Disk encryption is deliberately not in the first install; that decision is the owner's and is deferred, below. |

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
- **Disk encryption is an open decision, not a settled one.** It is deliberately absent
  from the first install, and the deferred entry below carries the consequence it leaves
  behind and the shape it will take when the owner decides. Nothing here should be read as
  a promise that a machine's disk is protected.

## What is already in place

Stated so the gap is sized correctly rather than pessimistically. The gate's three tiers,
the topology model, the sops/age layout with per-machine keys, the tag-driven account and
`sshd-with-certs` instances, and `docs/adding-a-machine.md`'s procedure with the failure
each step prevents all generalize to N machines today. The unit groups are written over
"every machine" and "every home", so a new machine joins the existing assertions instead
of needing new ones. The fleet is not a rewrite.

## The gaps, in order

### 1. The build contract — reached 2026-10-20

- **Both platforms declared.** `systems` is `[ "x86_64-linux" "aarch64-linux" ]`, and the
  aarch64 leg builds on `workstation` through `boot.binfmt.emulatedSystems` — qemu-user
  under binfmt_misc, registered by `systemd-binfmt` from `/etc/binfmt.d/nixos.conf`. This
  repository had disabled that service on a claim measurement disproved; the comment in
  `modules/clanServices/wsl/default.nix` records what was measured. Cost of the leg:
  8.6 s against 8.3 s for the same rebuilt check, because it is evaluation and trivial
  builders. The VM tier is skipped there by `modules/flake/tests.nix` — nested emulation
  proves nothing about a Pi.
- **Machine templates exist**, read by clan from `clan.templates.machine` in `clan.nix`:
  `clan machines create <name> --template .#bare-metal-x86` and `... --template
  .#raspberry-pi-4` (the `.#` selects this flake; a bare name selects clan's builtins).
  Each template carries a `platform.nix` that both its skeleton and the `systems`
  assertion read, so a declared system may lead the machine that will use it.
- **One less declaration per machine.** `username` is a global `clan.specialArgs` entry
  now, so a new machine needs the inventory block and nothing else in `clan.nix` — the
  per-machine `_module.args.username` line and the `machines` block are gone.
- **The Pi's board support is wired.** `nixos-raspberrypi` is an input whose modules reach
  machines through `clan.specialArgs`; the board module evaluates against clan's nixpkgs
  (checked: kernel `linux_rpi-bcm2711-6.18.34`, bootloader `uboot`, firmware at
  `/boot/firmware`). Its `nixpkgs` is deliberately not followed — its kernel patches are
  tested against the snapshot it locks, and clan's moves.

### 1a. How each machine gets onto its disk — the part "deploy" hides

Verified against the CLI (`clan machines --help`, `install --help`,
`init-hardware-config --help`), so the commands below are the real ones:

- **ThinkPad, x86_64.** `clan machines init-hardware-config thinkpad --target-host
  root@<ip>` writes the hardware report (nixos-facter by default) into the machine
  directory, then `clan machines install thinkpad --target-host root@<ip>` overwrites the
  target's disk. Both need the target reachable over SSH, which means booting something
  first — a NixOS installer image or the vendor's own OS. The disk layout itself is the
  deferred decision below; `clan templates apply disk ext4-single-disk thinkpad --set
  mainDisk <by-id>` is the one-liner once a layout is chosen.
- **Pi 4, aarch64.** No kexec on this board, so the SSH-install path starts from a
  flashed card: the input ships `installerImages.rpi4` (and `nixosModules.sd-image` for a
  ready system image). Flashing the installer image and running the same `clan machines
  install pi --target-host root@<pi>` is the documented route; building the machine
  *as* an SD image is the alternative, and it costs one flake output that imports
  `nixosModules.sd-image` — worth doing once `machines/pi/` exists, not before.
- **A disk layout for the Pi** is only needed for the SSH route: the image route carries
  its own partitioning.

### 2. The overlay — reached 2026-10-20

- The instance is live in `clan.nix`: clan-core's `mycelium` service, its single `peer`
  role assigned to the tag `all`, so a new machine joins the overlay by construction
  rather than by remembering a tag. `openFirewall` and `addHostedPublicNodes` keep their
  defaults.
- Its generator mints three vars per machine — `key/secret`, and the public `ip/value`
  and `pubkey/value` — and the 14-file/six-generator count in
  [`adding-a-machine.md`](./adding-a-machine.md) follows from that.
- Verified on `workstation`: the service is active, listens on 9651, reports the address
  in `vars/per-machine/workstation/mycelium/ip/value`
  (`5db:53c6:9758:1b11:bd26:854c:c651:5039`), and connects to public peers over TCP and
  QUIC with routes acquired. Being reachable *by another machine* needs a second peer,
  which is what the Pi will be.
- The price of an overlay is exposure, and the gate said so: mycelium opens TCP 9651 and
  UDP 9650/9651, so the `ports` unit group failed until the expected set was edited
  deliberately — which is the assertion working, not an obstacle. `test_the_only_bare_tcp_ports_have_a_reason`
  now names both bare ports and why each cannot be interface-scoped.

### 3. CI — prepared 2026-10-20, one interactive step left

- **Done:** `.github/workflows/gate.yml`, running `nix flake check --all-systems
  --keep-going` on a self-hosted runner labelled `[ "self-hosted" "linux" "kvm" ]`.
  `--all-systems` is in the job because the bare command builds the *current* system's
  checks only, which would leave the Pi's leg unbuilt by the one job that exists to prove
  it. The runner is this machine because the VM tier needs `/dev/kvm` and a hosted runner
  would skip that tier while reporting green over a smaller gate.
- **The trust boundary, which is what a self-hosted runner makes urgent.** The runner
  executes the workflow file *and* the flake of whatever ref asks for it, on a WSL guest
  with `/mnt/c` and LAN reach. So: `pull_request` is narrowed by an `if:` to branches of
  this repository (a fork's PR is skipped, because the only GitHub-side control is a
  repository setting a tree cannot assert); `permissions: contents: read` because the
  default token is read/write; `actions/checkout` pinned to a commit and
  `persist-credentials: false` so the job token is not left in the workspace; and **no
  `--accept-flake-config`**, because that flag trusts the `nixConfig` of the tree under
  test — a PR could add its own substituters and signing keys and land arbitrary paths in
  this runner's persistent store. The caches the job needs are ambient in `base-system`;
  `cache.clan.lol` buys nothing here, since clan-core is consumed for its modules only.
- **Done:** the runner itself — `services.github-runners.gate` in the workstation's
  configuration, with `replace = true`: a PAT outlives a single registration, so a restart
  must replace the stale one, and a runner holds no state between jobs. `ephemeral = true`
  for the same reason one level down: one job per registration, so no job inherits
  another's workspace (`Restart = on-success` re-registers). The token var carries
  `restartUnits = [ "github-runner-gate.service" ]` so regenerating a revoked PAT actually
  reaches the service. Two corrections to the original plan: no `kvm` group is needed
  (`/dev/kvm` is mode `666` here), and the credential is a **prompted** var rather than a
  generated one.
- **The one step left, and it is the owner's.** The token is a fine-grained PAT with
  `Administration: read and write` on the repository. Clan's prompt needs a real terminal —
  measured: piping a value into it *and* passing `--fake-prompts` both fail with
  `termios.error: (25, 'Inappropriate ioctl for device')`, so it cannot be scripted:

  ```console
  clan vars generate workstation --generator github-runner-token
  sudo nixos-rebuild switch --flake .#workstation
  ```

  Until it runs, `tokenFile` evaluates to `/no-such-path` — clan's sentinel for "not
  generated yet", which is a normal state and not an error — and the runner fails to
  register, visible in `journalctl -u github-runner-gate`.
- Branch protection on `main` requiring that job: once, when a run has reported at least
  once, because GitHub will not offer a check it has never seen.
- `origin/main` is 12 commits behind this tree, so nothing can be a pull request until
  those land. Pushing is the owner's call, not a side effect of this plan.

### 4. The Pi — when the board is in hand

Ready: the input is in place, the template exists, and the overlay joins by tag. What is
left belongs to the board.

- **Done:** the `nixos-raspberrypi` input, reached as a module through
  `clan.specialArgs.nixos-raspberrypi` (clan owns the `nixpkgs.lib.nixosSystem` call, so
  that flake's own helper is not reachable at this seam), and
  `clan machines create pi --template .#raspberry-pi-4` writes the skeleton that imports
  `nixos-raspberrypi.nixosModules.raspberry-pi-4.base`. Evaluated against clan's nixpkgs:
  kernel `linux_rpi-bcm2711-6.18.34`, bootloader `uboot`, firmware at `/boot/firmware`.
- **Done:** the overlay — `mycelium` is on the tag `all` (section 2), so the Pi joins it
  by construction and its address comes from its own generator.
- `deploy.targetHost`: the LAN address first. The overlay address would be better and is
  only known after `clan vars generate pi`, and whether a public var is readable at
  evaluation time is still unverified — start with what is knowable, and add the overlay
  address once it has been measured.
- Boot: `boot.loader.raspberry-pi` comes from the flake, and the firmware partition is
  written on activation. Declarative disk layout (disko) against a hand-installed card is
  a hardware-time decision, made deliberately.
- Flash route: `installerImages.rpi4` from the input, then
  `clan machines install pi --target-host root@<ip>` (section 1a).

### 5. The ThinkPad — when the hardware is in hand

- The bootloader module follows the disk decision, and the hardware config is generated on
  the machine, because the model decides the GPU and the fingerprint specifics and nothing
  here can guess them. Encryption is not part of the first install — it is the deferred item
  below, with its shape fixed there.
- mycelium peer — reachable through the Pi when away from home — power and suspend
  settings, fingerprint login, file sync, and the devshell toolchain.
- `deploy.targetHost` must be the overlay address here, not a LAN name: the machine roams,
  so a LAN address is wrong the first time it leaves the house.

### 6. Services become clan services

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
- **Disk encryption, LUKS2 — deferred, not dropped.** The decision is the owner's, and it is
  deliberately absent from the first install; the consequence is accepted with its size
  named rather than implied. `sops.age.keyFile` is `/var/lib/sops-nix/key.txt`, so a machine's
  own age key sits in plaintext on an unencrypted disk beside the ciphertexts in the
  checkout: a powered-off disk yields the SSH host key, both password hashes, and whatever a
  later generator adds. The sops store protects the repository and the backups, not a stolen
  disk. The shape when it lands is fixed by the unlock story rather than by taste — **LUKS2**,
  because `systemd-cryptenroll` supports only LUKS2 volumes (it stores token metadata in the
  format's JSON area), with `argon2id` key derivation, 4096-byte sectors on an SSD, a TPM2
  enrollment bound to PCR 7 so an unattended reboot stays reachable, and a recovery key kept
  in the sops store. Remember the cost: a firmware update changes PCR 7 and breaks the
  auto-unlock until it is re-enrolled with that key. Adding it later needs no reinstall —
  cryptsetup re-encrypts in place — though a rebuild is the cleaner path for a machine that is
  reproducible from this flake. `pi` is a different answer: no TPM to seal to and no console
  to type at, so a passphrase gate there would lose to unattended operation.
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
