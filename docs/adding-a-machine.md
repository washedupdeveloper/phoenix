# Adding a machine

The steps below are the ones that actually matter, each written after watching a
second machine fail for that reason. They are ordered so that a mistake is caught
by `nix flake check` rather than by a machine that boots and cannot be used.

**The rule this file exists for:** every failure below produces a machine that
*evaluates*. A missing tag gives you a machine with no account; a missing
`stateVersion` gives you a machine silently on a newer state version than the
rest of the fleet; a missing topology entry gives you a diagram that does not
show a machine you own. Only the gate's assertions turn those into errors.

## 1. The machine's configuration

```nix
# machines/<name>/configuration.nix
{ username, ... }:
{
  networking.hostName = "<name>";       # must equal <name>; a test asserts it
  nixpkgs.hostPlatform = "x86_64-linux";
}
```

Clan discovers this file by convention once the machine is declared in
`clan.nix` — there is no import list to edit.

## 2. Declare it in `clan.nix`, in two places

```nix
machines.<name> = {
  _module.args.username = "nixolotl";   # modules/home/default.nix requires it
};

inventory.machines.<name> = {
  tags = [ "<name>" ];                  # clan adds `all` and `nixos` itself
};
```

**`all` is reserved.** Clan tags every machine `all` and `nixos` automatically —
`tags = [ "pi" ]` reads back as `[ "pi" "all" "nixos" ]`. `user-nixolotl` and
`home-manager` are assigned to `tags.all` rather than to a machine list, so every
machine gets the account and its home with no per-machine edit and no tag to
remember. Writing `"all"` in the tag list is redundant; it is harmless, and the
workstation's list keeps it as documentation.

Do not add a machine to those instances by name. That is the shape that produced
a machine which builds, boots, and has no account or no dotfiles — and
`test_there_is_one_home_per_machine` is what fails when it happens.

A machine that is not on the LAN, or that you deploy to rather than run `switch`
on locally, also needs a target:

```nix
inventory.machines.<name> = {
  tags = [ "all" "<name>" ];
  deploy.targetHost = "192.168.68.110";  # where `clan machines update` reaches it
};
```

`workstation` has no `deploy` block on purpose: it is self-managed, and it is
where you run the command from.

## 3. `git add` the new directory

Nix only sees files git tracks. A new `machines/<name>/configuration.nix` that is
untracked evaluates as if it did not exist, and the machine fails with

```text
error: Neither nixpkgs.hostPlatform nor the legacy option nixpkgs.system has been set.
```

which reads like a missing setting rather than an untracked file.

## 4. Give it a state version, through the vars store

`system.stateVersion` on every machine comes from clan's `state-version` var
generator, not from this repository — the generator's value is committed under
`vars/`. A new machine has no value yet, so it silently takes nixpkgs' default
(the current release) instead of the fleet's pinned one:

```console
clan vars generate <name>      # writes vars/per-machine/<name>/state-version
git add vars/
```

Left undone, the machine is on `26.11` while the rest of the fleet is on `26.05`,
and `stateVersion` is the one setting that must never move on an existing
machine. `test_state_version_is_pinned` fails the gate in exactly that case.

## 5. Give it a place in the topology

A machine does **not** go in `topology.nix` — that file holds the non-NixOS
devices (the router, the Windows host, the uplink). Machines are derived from
their own config, so the block goes in `machines/<name>/configuration.nix`:

```nix
topology.self = {
  parent = "home-router";                # required; the gate asserts it exists
  interfaces.eth0 = {
    network = "lan";                     # must be a network topology.nix defines
    addresses = [ "192.168.68.110/24" ];
  };
};
```

Without it the machine still builds and still renders a node — an empty one,
attached to nothing — and `test_every_machine_declares_its_guest_relationship`
is what fails.

## 6. Add its architecture to `systems` if it is new

`systems` is the build contract, not a wish list: every `perSystem` output is
expected to evaluate for each entry, and `nix flake check --all-systems` builds
them. A Pi is `aarch64-linux`, so add it there when the Pi exists.

## 7. Run the gate

```console
nix flake check --keep-going
```

Expect it to fail the first time. The assertions that catch a half-added machine,
in the order they fire:

| assertion | what it caught |
| --- | --- |
| `test_every_machine_is_in_the_inventory` | declared in `machines` but not in `inventory.machines` |
| `test_every_inventory_machine_carries_a_tag` | in the inventory with no tags, so no service reaches it |
| `test_every_machine_carries_the_account` | no `users.users.nixolotl` — the machine boots and cannot be logged into |
| `test_there_is_one_home_per_machine` | no home-manager importer, so no dotfiles, git identity or signing key |
| `test_state_version_is_pinned` | step 4 skipped |
| `test_host_name_matches_the_machine_name` | `networking.hostName` disagrees with the machine's name |
| `test_every_machine_declares_its_guest_relationship` | step 5 skipped — no `topology.self`, so the machine renders as a node attached to nothing |
| `test_every_machine_runs_on_a_declared_system` | architecture missing from `systems` |

## Why the assertions are fleet-shaped

`tests/unit/*.nix` reads as "every machine does X", not "the one machine is X".
The earlier spelling compared a per-machine map against a literal list, so the
second machine failed the gate *for existing*, and the natural fix — adding a row
to the expectation — disables the assertion for the machine just added.

When you add an assertion here, write it over `named` (every machine) or
`hmUsers` (every home) with `expected = true`, or as a `subtractLists` against
the declared set with `expected = [ ]`. If an assertion cannot be written that
way, the thing it checks is a per-machine fact and belongs in that machine's own
configuration.
