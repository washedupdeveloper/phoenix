# Adding a machine

Every failure below still **evaluates** — no account, a wrong `stateVersion`, a node
attached to nothing — so only the gate's assertions turn them into errors.

**1. Configuration.** `machines/<name>/configuration.nix`, found by convention once
`clan.nix` declares the machine; there is no import list:

```nix
{ username, ... }: {
  networking.hostName = "<name>";       # must equal <name>; a test asserts it
  nixpkgs.hostPlatform = "x86_64-linux";
}
```

**2. Declare it in `clan.nix`, in two places.** `machines.<name>` supplies module
args; `inventory.machines.<name>` is what the gate reads:

```nix
machines.<name>._module.args.username = "nixolotl";  # modules/home/default.nix requires it
inventory.machines.<name> = {
  tags = [ "<name>" ];                  # clan adds `all` and `nixos` itself
  deploy.targetHost = "192.168.68.110"; # only if you deploy to it remotely
};
```

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

Vars hold 11 files from five generators: `state-version` (`version/value`), `openssh`
(`ssh.id_ed25519.pub/value`, `ssh.id_ed25519/secret`), `openssh-cert`
(`ssh.id_ed25519-cert.pub/value`, `.validation-hash`), `user-password-root` /
`user-password-nixolotl` (`user-password/secret`, `user-password-hash/secret`), and
per-service secrets (`mosquitto-plant-monitor` on `workstation`) only where the
service runs. They are **sops/age-encrypted at rest**, so committing `vars/` is correct; do
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
output must build under `nix flake check --all-systems`; a Pi is `aarch64-linux`.

**7. Run the gate:** `nix flake check --keep-going`. Expect a first failure; these
assertions catch a half-added machine, in firing order:

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
