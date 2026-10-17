# Testing

`nix flake check` is the gate, and the tests are part of it. There is no second
command to remember: `modules/flake/tests.nix` contributes to the same `checks`
output that `modules/flake/checks.nix` and `modules/flake/nix-topology.nix` do.

## Scope

The suite tests **the system**: what it is, what it exposes, and what it must
never become. Two groups sit outside that and are named for it: `flake` covers
the flake's own wiring -- the two package sets, the devshell, the output set --
and `home` covers the user's home-manager configuration, which is per-user
rather than per-machine.

It deliberately does not test individual services. A broker's port or a
server's credential is a property of that service, not of the system, and those
expectations move with the service into its own module and its own test. Today
`mosquitto` and the Hermes backend are enabled by hand on this machine and are
expected to leave; they have no assertions here, and adding one would only have
to be removed again.

## Two kinds

They exist because they prove different things.

### Unit tests — what the configuration *says*

`tests/unit/default.nix`, wired as `checks.unit-<group>`. Evaluation-time
assertions: each reads a value out of a machine's evaluated config and compares
it with what this repository intends. They build nothing and take milliseconds.

They use `lib.runTests`, the helper clan-core uses for its own `eval-tests`.
Each group is its own check, so `nix flake check --keep-going` reports every
failing group rather than stopping at the first, and a failure names the test
and both values.

Eight groups, 54 assertions:

| Group | What it pins |
| --- | --- |
| `system` (6) | state version, host name, timezone, locale, keymap, host platform, and that every machine runs on a declared system |
| `ports` (4) | the declared exposure set is exactly `tcp/22` and `udp/5353`, the sshd listener and its firewall rule agree, and sshd is the only bare TCP port |
| `security` (8) | key-only SSH, root passwords prohibited, every password hash vars-backed, no empty passwords, `mutableUsers` off, sudo wheel-only and passwordless, no insecure packages permitted |
| `integrity` (3) | no nixpkgs assertion fails, no nixpkgs warning is emitted, the firewall is declared on |
| `structure` (3) | every machine declares its guest relationship, appears in the topology, and references only defined networks |
| `clan` (8) | deployability — see below |
| `flake` (10) | the flake's own wiring — see below |
| `home` (12) | the user's home-manager configuration — see below |

### `flake` — the wiring no machine config shows

`tests/unit/flake.nix`. It reads the per-system flake-parts config, which is
why it is built inside `perSystem` in `modules/flake/tests.nix` rather than
from a machine.

- **The two package sets agree.** `_module.args.pkgs` and `clan.pkgs` are two
  wirings of one set; if they disagree the devshell allows unfree packages and
  the clan CLI does not. Checked through the consumer —
  `clanInternals.machines.<system>.<machine>.config.nixpkgs.pkgs` — so removing
  `perSystem.clan.pkgs` fails the test rather than passing it vacuously.
- **The devshell and the machine enable the same experimental features.** The
  devshell's `NIX_CONFIG` and `nix.settings.experimental-features` are two
  declarations of one list, and a feature in one but not the other is a
  command that parses in the devshell and not in a rebuild.
- **`systems` is a build contract.** Every declared system has a devshell and a
  non-empty `checks`, and the declared set is exactly the set the machines run
  on.
- **Every custom output is paired with a check.** The output names nix does not
  know are enumerated, so a new one cannot be added without a `checks` entry.
- **The cache split holds.** The machine trusts nix-community,
  pre-commit-hooks and numtide, does not substitute from `cache.clan.lol`, and
  does not accept flake config silently.

### `home` — the user half

`tests/unit/home.nix`. It reads `home-manager.users.<name>` out of each
machine's evaluated config.

- **One identity, two tools.** git's and jj's `user.name`/`user.email` are the
  same values, and the name is derived from the account name. AGENTS.md records
  that the two copies drifted while each tool carried its own.
- **git's signing key stays out of jj.** `user.signingkey` is git-only; jj's
  signing is `signing.backend` plus `signing.key`, so a shared blob carrying
  git's key gives jj a setting it does not understand.
- **The home is the account's home**, its state version follows the system's,
  and home-manager and the ssh-agent are enabled.
- **Fish is the shell every integration targets**, all seven fish integrations
  are on, and the login shell is fish — the pair that
  [`shell-integrations.md`](./shell-integrations.md) says was inert while the
  account landed in bash.
- **The identity reaches the tool modules through `extraSpecialArgs`**, not
  through a second definition inside one of them.

### E2E tests — what the running system *does*

`tests/e2e/<name>/`, wired as `checks.e2e-<name>`. These boot a machine with the
**real** modules applied and assert against the running system.

| Test | Proves |
| --- | --- |
| `e2e-base-system` | the real `base-system` module renders into the running system: timezone, locale, `$EDITOR`, the conditional user half, and `sshd -T` — sshd's own parse of the config it will serve |
| `e2e-home` | the user's home-manager configuration works: git and jj read the same identity from the rendered files, git signs a real commit with the configured SSH key, and the fish direnv hook and Ctrl+Space binding fire |
| `e2e-ports` | nothing listens that the configuration did not declare |

`e2e-home` is the running-system half of the `home` unit group. It boots the
real `git.nix`, `jj.nix` and `shell.nix`; only the composition that
`modules/home/default.nix` performs is restated in the test, because a clanTest
builds its nodes out of `clanInternals.nixosModules` (bare module sets), so
`clan.specialArgs` — how the repository hands `homeManagerModule` to that
module — never reaches them, and supplying the argument through `_module.args`
recurses. The composition and the identity wiring are pinned by the `home`
unit group instead, which reads the real machine's evaluated configuration.

Its strongest assertion is a commit: `git config --get` answers from the same
file whether or not git can use it, so a signature git verifies against
`~/.ssh/allowed_signers` is the only proof that `commit.gpgsign`,
`gpg.format = ssh` and the key agree. The fish half is two claims: the hook is
in the file fish reads, and running it exports an allowed `.envrc` into the
shell's environment. The hook's own trigger is a prompt event, which a
`fish -c` shell never draws, so the function the hook installs is invoked
directly rather than waiting for a prompt.

`e2e-ports` is the running-system half of the `ports` unit group, and the two
are different claims. The unit test says what the configuration *intends* to
expose; this says what the kernel is actually listening on. The second is what
catches a service opening a socket no option mentions.

It reads `/proc/net/tcp{,6}` and `/proc/net/udp{,6}` rather than `ss`, because
iproute2 is not part of a minimal system and the test must not depend on a
diagnostic tool being installed. It splits the results by bound address: an
all-zero address is exposure, anything else is not. Today the exposed set is
exactly `tcp/22`, and nothing listens on loopback at all.

## The target problem

The machine this repository deploys cannot be the e2e target. `workstation` is a
NixOS-WSL guest, and `system.build.installBootLoader` resolves to
`${pkgs.coreutils}/bin/true` — the WSL kernel boots it, so there is no
bootloader and nothing for QEMU to start. It is not merely inconvenient to test;
it is not bootable.

The tests apply the same modules to a test machine instead, pointing
`clan.modules."base-system"` at the real
`modules/clanServices/base-system`, so the module under test is the one that
ships.

## Clan deployability

The `clan` unit group asserts what `clan machines update` needs to be true
before it can deploy anything. It imports `clan.nix` directly rather than
reading clan's internals, so the assertions are about what this repository
declares, not about clan's interpretation of it.

- **Every machine is a clan machine with a build artifact** — the artifact
  `clan machines build` produces, from `clanInternals.machines`.
- **Every instance names its module source.** `AGENTS.md` calls this the trap: a
  null `module.input` resolves to clan-core, so a local service silently loads
  the wrong module.
- **Every `self` instance names a module this repository defines** — otherwise
  clan resolves it to clan-core and fails at build time.
- **Every role is assigned to something.** A role with no tags and no machines
  never applies, and nothing says so.
- **Every role tag is carried by a machine**, and every role's machine exists —
  the same silent failure spelled as a typo.
- **Every machine is in the inventory and carries a tag**, or no role can target
  it.

Clan accepts a role assignment in three spellings — `tags = [ "x" ]`,
`tags.x = { }`, and `machines.<name> = { }` — so the checks normalise all three
rather than depending on which was used.

## Findings

The suite found these while being written. Each is recorded rather than fixed
unless it is a defect with an obvious repair.

**`lib.throwTestFailures` does not exist, so the suite's failure path was
broken.** `lib.runTests` returns a list of failures, and the reporter for them
lives at `lib.debug.throwTestFailures`. With the bare `lib.throwTestFailures`,
a *failing* unit test produced `attribute 'throwTestFailures' missing` instead
of the test's own name, expected value and result — so the gate went red with a
message about the reporter rather than about the test. It went unnoticed because
every group passed, and the branch is only evaluated when one does not. Fixed:
`modules/flake/tests.nix` now calls `lib.debug.throwTestFailures`.

**`nixConfig` cannot be read from evaluation, so it is not tested.** It sits
outside the flake's outputs: `builtins.getFlake` has no `nixConfig` attribute
and `nix flake metadata --json` omits it. The only way to read it would be to
parse `flake.nix` as text, which breaks on any reformat, so the `flake` group
asserts the invariant from the machine side instead — the three caches it must
substitute from, the absence of `cache.clan.lol`, and that flake config is not
accepted silently. The consequence is worth knowing: a cache added to
`nixConfig` and *not* to `base-system` is caught by nobody.

**`base-system`'s `username` default is unreachable.** The module's
`perInstance.nixosModule` takes `username ? null` and gates the user half on
`lib.mkIf (username != null)`. That default never applies: the module system
resolves a formal argument from `_module.args` and errors when it is absent, so
omitting `username` fails evaluation instead of yielding `null`. The guard is
therefore always true. It was found by the `e2e-ports` test, which tried to omit
the argument. Making the optionality real means giving `username` a default in
`_module.args`; leaving it means deleting a guard that cannot be false.

**clan-core enables systemd-resolved, which opens three ports nothing here
declares.** The `e2e-ports` test's first run reported `TCP exposed: [22, 5355]`
and `UDP exposed: [5353, 5355]` — LLMNR, mDNS, and the loopback DNS stub. They
come from `systemd-resolved`, which clan-core's own networking module turns on
(it is what provides the mDNS that clan advertises). This repository disables it
— `services.resolved.enable = lib.mkForce false` — but only in
`modules/clanServices/wsl`, and only because WSL supplies its own resolver. Two
consequences: a non-WSL machine in this clan would run resolved and expose three
undeclared listeners, and the firewall's `udp/5353` allow (which comes from
clan-core, not from here) is for a service this repository turns off.

## Commonly implemented checks, and where this stands

Grouped by what they protect. The ones marked *not implemented* are the usual
next candidates rather than oversights.

### Attack surface

| Check | Status |
| --- | --- |
| No undeclared listening ports | implemented, unit + e2e |
| Firewall enabled with a minimal allow-list | implemented |
| Only intended services enabled | partial — the e2e ports test catches the ones that listen; a full `systemd.services.*.enable` allow-list is not implemented |
| No unexpected `systemPackages` in the closure | not implemented |

### Identity and access

| Check | Status |
| --- | --- |
| No empty or default passwords | implemented |
| Password hashes never in the repository or store | implemented |
| Only intended users in `wheel`; sudo restricted | implemented |
| No secret in the Nix store or a committed file | covered by `gitleaks` in the pre-commit hooks |

### Configuration integrity

| Check | Status |
| --- | --- |
| No failing nixpkgs assertion | implemented |
| No nixpkgs warning (deprecations, misconfiguration) | implemented |
| State version pinned and not bumped by accident | implemented |
| No insecure packages permitted | implemented |
| No deprecated option aliases | partial — most surface through `warnings` |

### Reproducibility and build

| Check | Status |
| --- | --- |
| Every machine's toplevel builds | implemented, `modules/flake/checks.nix` |
| Flake evaluates from a clean checkout | `nix flake check` itself |
| The rendered topology builds | implemented, `modules/flake/nix-topology.nix` |
| The installer or image builds | not applicable — this clan has no installer machine |

### Deployment

| Check | Status |
| --- | --- |
| The machine is a clan machine and builds as one | implemented |
| Every inventory role is assigned and every tag is real | implemented |
| The machine's vars exist and are current | not implemented — `clan vars check` does this, but it reads the on-disk vars store and does not belong in a pure evaluation |

## Two environment requirements

Both were found by the tests failing, and both are recorded because each reads
like a broken test rather than a missing prerequisite.

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

**`sshd -T` needs host keys and echoes the config's casing.** It exits 1 with
`no hostkeys available -- exiting` when the host keys are absent, so an
assertion on it must run `ssh-keygen -A` first — a no-op once `sshd-keygen` has
run. And NixOS writes `PasswordAuthentication no`, not the lowercase form, while
sshd does not normalise keywords in its `-T` output, so the comparison must be
case-insensitive.

## What is deliberately not tested

- **The build.** `modules/flake/checks.nix` already builds every machine's
  toplevel; a test that repeated it would be a second, slower copy.
- **`nixConfig`'s contents.** See Findings: it is outside the flake's outputs,
  so only a text-level check could read it.
- **The WSL-specific half.** `modules/clanServices/wsl` configures a guest for
  the WSL kernel. Nothing off-WSL can boot it, so it is covered by the unit
  tests and the topology check, not by a VM.
- **The rendered diagram's contents.** `checks.topology` builds it; asserting on
  the SVG would pin a renderer's layout.
- **Service-specific behaviour.** See Scope.

## The gate and the git hooks

`nix flake check` is the only command needed, and it runs on every commit.

It covers everything: `modules/flake/checks.nix` builds each machine's
toplevel, `modules/flake/nix-topology.nix` builds the diagram,
`modules/flake/tests.nix` contributes the unit groups and the e2e tests, and
`checks.pre-commit` runs the lint hooks. A commit is refused unless all of it
passes.

The pre-commit hook that invokes it is guarded, and the guard is load-bearing:

```console
sh -c 'if [ -n "$NIX_BUILD_TOP" ]; then exit 0; fi; ...; exec nix flake check'
```

`nix flake check` builds `checks.pre-commit`, which runs `pre-commit
run --all-files`. A hook in the `pre-commit` stage therefore runs *inside* the
gate, so an unguarded `nix flake check` hook would call the gate again, without
end. `NIX_BUILD_TOP` is set inside a Nix build and unset in a shell — measured,
unlike `IN_NIX_SANDBOX`, which this Nix leaves unset even in a sandboxed build
— so the nested invocation returns immediately and the recursion stops at depth
one.

Measured cost of a commit, warm store, on this machine:

| change | checks rebuilt | time |
| --- | --- | --- |
| nothing | 0 | ~45s |
| a comment | 2 | ~45s |
| the system closure | 19 | ~49s |
| the shared `base-system` module | 47 | ~114s |

The last row is the one to know about: touching a module the VM tests apply
rebuilds their nodes and re-runs both VMs.

Two consequences worth knowing:

- The lint hooks run twice per commit: once directly, and once inside the gate.
  They are seconds and idempotent, so this is deliberate rather than worth
  unpicking.
- The hooks live in `.pre-commit-config.yaml`, a symlink into the store. It
  only moves when the flake is re-evaluated and the install script re-run,
  which is what `nix develop` does. A hook added to `git-hooks.nix` without
  re-entering the devshell is written down and never installed — that is how
  the `nix flake check` hook sat inert in `modules/flake/git-hooks.nix` while
  the installed config predated it.

## Running them

```console
nix flake check                                 # everything, including the VM tests
nix build .#checks.x86_64-linux.ports           # one unit group, milliseconds
nix build .#checks.x86_64-linux.e2e-home        # one e2e test, minutes
nix log .#checks.x86_64-linux.e2e-home          # the VM's own log
nix develop                                     # reinstalls the git hooks
```

The attribute name is the group name — `checks.x86_64-linux.ports`, not
`unit-ports`. `unit-<group>` is the *derivation* name, which is what a log or a
store path shows.

The e2e tests boot a VM, so they cost minutes and need `/dev/kvm`. That is the
price of the only check that can see what a daemon actually does, and it is why
the unit tests exist alongside them rather than instead of them.
