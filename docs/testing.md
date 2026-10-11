# Testing

`nix flake check` is the gate, and the tests are part of it. There is no second
command to remember: `modules/flake/tests.nix` contributes to the same `checks`
output that `modules/flake/checks.nix` and `modules/flake/nix-topology.nix` do.

There are two kinds, and they exist because they can prove different things.

## Unit tests — what the configuration *says*

`tests/unit/default.nix`, wired as `checks.unit-<group>`. They are
evaluation-time assertions: each one reads a value out of a machine's evaluated
config and compares it with what this repository intends. They build nothing and
take milliseconds.

They use `lib.runTests`, the same helper clan-core uses for its own
`eval-tests`. Each group is its own check, so `nix flake check --keep-going`
reports every failing group rather than stopping at the first, and a failure
names the test and both values.

The properties are chosen, not enumerated. Two sources decide them:

- **The invariants `AGENTS.md` calls traps** — the ones that yield a
  plausible-looking wrong result instead of an error. A machine on a network the
  topology model does not define is the example: it renders a dangling node and
  nothing else notices.
- **The security posture the council audits** — key-only SSH, vars-backed
  password hashes, the interface-scoped broker rule. These are the settings a
  change can quietly relax, and the ones a reviewer has to re-derive by hand
  every time.

What they deliberately do **not** cover is anything a build can already see. A
test that restates the build adds a second place to be wrong.

Groups: `security` (8), `generator` (5), `structure` (4), `pins` (2).

## E2E tests — what the running system *does*

`tests/e2e/<name>/`, wired as `checks.e2e-<name>` through clan-core's
`modules.nixosTest.clanTest`. These boot a machine with the **real** modules
applied and assert against the running system.

The difference from the unit tests is not ceremony. A unit test reads the
option; an e2e test reads what consumed it. `sshd -T` is the clearest case: it
is sshd's own parse of the configuration it will serve, so an option that never
reached a file cannot satisfy it.

### The target problem

The machine this repository deploys cannot be the e2e target. `workstation` is a
NixOS-WSL guest, and `system.build.installBootLoader` resolves to
`${pkgs.coreutils}/bin/true` — the WSL kernel boots it, so there is no
bootloader and nothing for QEMU to start. It is not merely inconvenient to test;
it is not bootable.

The tests therefore apply the same modules to a test machine, which is the
closest bootable thing. `clan.modules."base-system"` points at the real
`modules/clanServices/base-system`, not a copy, so the module under test is the
one that ships.

### Two environment requirements

Both were found by the tests failing, and both are recorded here because each
one reads like a broken test rather than a missing prerequisite.

**Containers need nix's `uid-range` system feature.** clan's test harness
defaults to `useContainers = true` (nspawn, much faster than a VM). A container
test requires the `uid-range` feature, which nix advertises only when the
builder sets `auto-allocate-uids`. nixpkgs' default `system-features` is
`[ "nixos-test" "benchmark" "big-parallel" "kvm" ]` and does not include it, so
the build fails with

```console
error: Cannot build '...-container-test-run-...drv'.
       Reason: missing system features
       Required features: {kvm, nixos-test, uid-range}
       Available features: {benchmark, big-parallel, kvm, nixos-test}
```

The tests use `useContainers = false`, which needs only `kvm` and `nixos-test`.
Set `nix.settings.auto-allocate-uids = true` on the builders, then flip
`useContainers` to `true` and rename `nodes` to `containers` to get the faster
path.

**`sshd -T` needs host keys.** It exits 1 with `no hostkeys available --
exiting` when they are absent, so an assertion on it must run `ssh-keygen -A`
first. That is a no-op once `sshd-keygen` has run.

**`sshd -T` echoes the config's casing.** NixOS writes `PasswordAuthentication
no`, not `passwordauthentication no`, and sshd does not normalise the keywords
in its `-T` output. Compare lowercased rather than assuming a case.

## What is deliberately not tested

- **The build.** `modules/flake/checks.nix` already builds every machine's
  toplevel; a test that repeated it would be a second, slower copy.
- **The WSL-specific half.** `modules/clanServices/wsl` configures a guest for
  the WSL kernel. Nothing off-WSL can boot it, so it is covered by the unit
  tests and by the topology check, not by a VM.
- **The rendered diagram's contents.** `checks.topology` builds it; asserting on
  the SVG would pin a renderer's layout.

## Running them

```console
nix flake check                      # everything, including the VM tests
nix build .#checks.x86_64-linux.unit-security   # one unit group, milliseconds
nix build .#checks.x86_64-linux.e2e-base-system # one e2e test, minutes
nix log .#checks.x86_64-linux.e2e-base-system   # the VM's own log
```

The e2e tests boot a VM, so they cost minutes and need `/dev/kvm`. That is the
price of the only check that can see a daemon's effective configuration, and it
is why the unit tests exist alongside them rather than instead of them.
