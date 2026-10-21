# Adding a machine

Every failure below still **evaluates** — no account, a wrong `stateVersion`, a node
attached to nothing — so only the gate's assertions turn them into errors.

**0. Create it from a template.** The skeleton exists so that the two lines a
hand-copied file forgets — the platform and the topology stub — are already right:

```console
clan machines create thinkpad --template .#bare-metal-x86    # x86_64, systemd-boot
clan machines create pi --template .#raspberry-pi-4          # aarch64, vendor kernel
clan templates list                                          # what else is on offer
```

The aliased spelling `clan templates apply machine .#bare-metal-x86 thinkpad` runs the
same command; `nix develop` first, because `clan` lives in the devshell. The selector is
`.#<template>` and that is not cosmetic: a bare name is looked up in clan's **builtin**
templates (`clanInternals.templates.machine`), so `--template bare-metal-x86` fails with
`Failed to select template … via attribute path …#clanInternals.templates.machine."bare-metal-x86"`
while `clan templates list` happily shows the template under `inputs.self`. The template
is a plain directory copy, so nothing in it knows the machine's name: the hostname is
therefore `config.clan.core.settings.machine.name` rather than a second spelling of it.

**1. What the template leaves you.** `machines/<name>/configuration.nix` — found by
convention once the machine exists, there is no import list:

```nix
{ config, lib, pkgs, ... }:            # the Pi's template also takes `nixos-raspberrypi`
{
  nixpkgs.hostPlatform = import ./platform.nix;   # the template's platform, as data
  networking.hostName = config.clan.core.settings.machine.name;
  topology.self = { parent = "home-router"; interfaces.eth0.network = "lan"; };
}
```

Edit what only this machine knows — an interface name, a second disk, a service — and
leave the derived lines alone. A laptop that reaches the network only over wifi wants
`interfaces.wlan0` instead of `eth0`; the name is descriptive, and the gate asserts
only that the *network* exists.

**2. Declare it in `clan.nix`.** One block: `inventory.machines` is what the gate reads.
Module args are no longer per machine — `username` is a global `clan.specialArgs`
entry — so there is nothing else to add there:

```nix
inventory.machines.<name> = {
  tags = [ "<name>" ];                  # clan adds `all` and `nixos` itself
  deploy.targetHost = "192.168.68.110"; # only if you deploy to it remotely
};
```

`clan machines create` also writes an `inventory.json` for what it makes; this
repository declares machines in `clan.nix` and the gate reads that, so the block above
is not optional — `test_every_machine_is_in_the_inventory` fails without it. If both
exist clan merges them, and the file speaks for the keys it carries.

`deploy.targetHost` is where `clan machines update` reaches a machine that is not on
the LAN, or one you deploy to rather than `switch` on locally; `workstation` has no
`deploy` block, being self-managed. **`all` is reserved**: clan adds `all` and `nixos`
to every machine, so `tags = [ "pi" ]` reads back `[ "pi" "all" "nixos" ]`.
`user-nixolotl` and `home-manager` are on `tags.all`, so every machine gets the account
and home. Do not enumerate machines by name on those instances — that builds, boots,
and has no account or dotfiles; `test_there_is_one_home_per_machine` fails.

**3. `git add` the new directory.** Nix only sees tracked files: an untracked
`machines/<name>/configuration.nix` evaluates as absent and fails with `error:
Neither nixpkgs.hostPlatform nor the legacy option nixpkgs.system has been set.` —
which reads like a missing setting, not an untracked file.

**4. Generate its vars — this blocks the build.** `clan vars generate <name>`, then
`git add vars/`. Not optional, and not only the state version: `sshd-with-certs`
gives the machine an SSH host key and `users` a password hash, and the toplevel will
not build without them — the gate reports `error: File 'ssh.id_ed25519.pub' at
'per-machine/pi/openssh' does not exist.` at `checks.x86_64-linux.nixos-<name>`.

Vars hold 14 files from six generators: `state-version` (`version/value`), `openssh`
(`ssh.id_ed25519.pub/value`, `ssh.id_ed25519/secret`), `openssh-cert`
(`ssh.id_ed25519-cert.pub/value`, `.validation-hash`), `user-password-root` /
`user-password-nixolotl` (`user-password/secret`, `user-password-hash/secret`),
`mycelium` (`key/secret` for the overlay key, `ip/value` and `pubkey/value` for the
address and public key — those two are public on purpose, so the machine's address is
readable without a key), and per-service secrets (`mosquitto-plant-monitor` on
`workstation`, two files) only where the service runs. They are **sops/age-encrypted at
rest**, so committing `vars/` is correct; do
not hand-write them — `state-version` can be emulated, the key material cannot. At rest means
**for the repository**: on a machine without disk encryption the machine's own age key sits at
`/var/lib/sops-nix/key.txt`, so the store protects your Git host and your backups, not a
stolen disk — see [`milestone.md`](./milestone.md) for the accepted consequence.
The `state-version` generator pins `system.stateVersion` to the fleet's value; skipping it is
the quieter failure: the machine takes nixpkgs' current release (`26.11`) instead of the
fleet's `26.05`, and `stateVersion` must never move on an existing machine.

**4a. Declare it in `inventory.machines` too.** Clan does not need it —
`modules/clan/module.nix` derives the inventory from the `machines/` directory, so a
directory plus `machines.<name>` already evaluates with the account, home and
`[ "all" "nixos" ]` — but `test_every_machine_is_in_the_inventory` reads the
inventory **as declared in `clan.nix`**, and a derived test could never fail.

**5. Give it a place in the topology.** Not in `topology.nix`, which holds the
non-NixOS devices (router, Windows host, uplink); machines are derived from their own
config, so this goes in `machines/<name>/configuration.nix`:

```nix
topology.self = {
  parent = "home-router";                # required; the gate asserts it exists
  interfaces.eth0.network = "lan";       # must be a network topology.nix defines
  interfaces.eth0.addresses = [ "192.168.68.110/24" ];
};
```

Without it the machine still builds and renders a node — empty, attached to nothing
— and `test_every_machine_declares_its_guest_relationship` fails.

**6. Add its architecture to `systems` if new.** A build contract: every `perSystem`
output must build under `nix flake check --all-systems`; a Pi is `aarch64-linux`, and
`aarch64-linux` is already declared. The aarch64 leg builds on the WSL guest through
`boot.binfmt.emulatedSystems` (qemu-user under binfmt_misc): measured at 8.6s against
8.3s for the same rebuilt check, since that leg is evaluation and trivial builders. The
VM tier is skipped there by decision — `modules/flake/tests.nix` gates it — because a
QEMU guest of an emulated system is nested emulation, and `docs/testing.md` says why.

**7. Run the gate, both legs:** `nix flake check --all-systems --keep-going`. Without
`--all-systems` it builds only the machine you are on, so the Pi's leg is exactly what
it would skip. Expect a first failure; these assertions catch a half-added machine, in
firing order:

| assertion | what it caught |
| --- | --- |
| `test_every_machine_is_in_the_inventory` | declared in `machines` but not in `inventory.machines` |
| `test_every_inventory_machine_carries_a_tag` | in the inventory with no tags, so no service reaches it |
| `test_every_machine_carries_a_normal_user` | the account is only a shell stub — `base-system` sets `users.users.<user>.shell` everywhere, so the attribute existing is no evidence |
| `test_there_is_one_home_per_machine` | no home-manager importer, so no dotfiles, git identity or signing key |
| `test_state_version_is_pinned` | step 4 skipped |
| `test_host_name_matches_the_machine_name` | `networking.hostName` disagrees with the machine's name |
| `test_every_machine_declares_its_guest_relationship` | step 5 skipped — no `topology.self`, so the machine is a node attached to nothing |
| `test_every_machine_runs_on_a_declared_system` | architecture missing from `systems` |

Assertions in `tests/unit/*.nix` go over `named` (every machine) or `hmUsers` (every
home) with `expected = true`, or as a `subtractLists` against the declared set with
`expected = [ ]` — never against a literal list, which fails the next machine *for
existing* and whose obvious fix disables the assertion for the machine just added.
