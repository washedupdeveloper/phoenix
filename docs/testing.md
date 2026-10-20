# Testing

`nix flake check` is the gate, and the tests are part of it: `modules/flake/tests.nix` contributes to the same `checks` output as `modules/flake/checks.nix` and `modules/flake/nix-topology.nix`. There is no second command.

## Scope

The suite tests **the system**: what it is, what it exposes, what it must never become. Two groups sit outside that and are named for it: `flake` (the flake's own wiring — the two package sets, the devshell, the output set) and `home` (the user's home-manager configuration, which is per-user rather than per-machine). Individual services are deliberately untested: a broker's port or a server's credential belongs to that service and moves with it into its own module and test. `mosquitto` and the Hermes backend are enabled by hand here and expected to leave, so they have no assertions.

## Three tiers

| Tier | Answers | Cost | Needs |
| --- | --- | --- | --- |
| `unit` | what an option *says* | milliseconds | nothing |
| `build` | what that option *rendered* | seconds | the artifact |
| `e2e` | what a running machine *does* with it | minutes | `/dev/kvm` |

The tier is chosen by what an assertion *needs*, not by what is convenient. **Python is the price of the third tier and nothing else**: a `testScript` is the only place this suite needs an imperative language, so an assertion that can be made against a rendered file must not boot a machine to look at it. Reach for `unit` first, then `build`, and keep `e2e` for the residue — a daemon parsing its own config, a socket being open, a command succeeding.

**Two platforms, and not every tier runs on both.** `systems` declares `x86_64-linux` (the WSL guest) and `aarch64-linux` (the Pi), so every `perSystem` output exists twice and `checks.aarch64-linux` carries the unit, build and topology groups. The VM tier does not: `runNixOSTest` boots a QEMU guest *of the system under test*, so the aarch64 leg would be qemu-user running qemu-system-aarch64 — nested emulation, minutes per test, and no claim about a Pi that qemu-user cannot establish anyway. `modules/flake/tests.nix` gates `e2e-*` behind `pkgs.stdenv.hostPlatform.isx86_64`, and that gate is the only place the tier differs.

Which command proves what follows from it: `nix flake check` builds the checks of the **current** system only, and `nix flake check --all-systems` builds the other leg. The aarch64 leg needs a builder for that platform, which on this host is `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` in `machines/workstation/configuration.nix` — qemu-user under binfmt_misc, registered by `systemd-binfmt` from `/etc/binfmt.d/nixos.conf`. Measured cost on this host: the same rebuilt check takes **8.3 s native against 8.6 s emulated**, because that leg is evaluation and trivial builders; a compiling aarch64 build pays for the emulation in full, which is the second reason the VM tier stays off it.

### Unit — what the configuration *says*

`tests/unit/default.nix`, wired as `checks.unit-<group>`: evaluation-time assertions, each comparing a value out of a machine's evaluated config with what this repository intends. They use `lib.runTests`, the helper clan-core uses for its own `eval-tests`, and each group is its own check, so `nix flake check --keep-going` reports every failing group and a failure names the test and both values. Eight groups, 56 assertions:

| Group | What it pins |
| --- | --- |
| `system` (6) | state version, host name, timezone, locale, keymap, host platform, and that every machine runs on a declared system |
| `ports` (4) | the declared exposure set is exactly `tcp/22` and `udp/5353`, the sshd listener and its firewall rule agree, and sshd is the only bare TCP port |
| `security` (8) | key-only SSH, root passwords prohibited, every password hash vars-backed, no empty passwords, `mutableUsers` off, sudo wheel-only and passwordless, no insecure packages permitted |
| `integrity` (3) | no nixpkgs assertion fails, no nixpkgs warning is emitted, the firewall is declared on |
| `structure` (4) | every machine declares its guest relationship, appears in the topology, and references only defined networks; every mosquitto listener renders an address, `[::]` included — the extractor interpolates a `nullOr str` default and dies on it, so the value is asserted rather than left to the evaluator |
| `clan` (8) | deployability — see below |
| `flake` (10) | the flake's own wiring — see below |
| `home` (13) | the user's home-manager configuration — see below |

**`flake` — the wiring no machine config shows.** `tests/unit/flake.nix`, built inside `perSystem` in `modules/flake/tests.nix` because it reads the per-system flake-parts config rather than a machine. Five invariants: `_module.args.pkgs` and `clan.pkgs` agree (two wirings of one set — otherwise the devshell allows unfree packages and the clan CLI does not), checked **through the consumer** `clanInternals.machines.<system>.<machine>.config.nixpkgs.pkgs`, so removing `perSystem.clan.pkgs` fails rather than passing vacuously; `NIX_CONFIG` and `nix.settings.experimental-features` declare one list, since a feature in one but not the other parses in the devshell and not in a rebuild; every declared system has a devshell and a non-empty `checks`, and the set is exactly what the machines run on; every custom output name is paired with a `checks` entry; and the cache split holds — nix-community, pre-commit-hooks and numtide trusted, no `cache.clan.lol`, flake config not accepted silently.

**`home` — the user half.** `tests/unit/home.nix`, reading `home-manager.users.<name>` out of each machine's evaluated config. git's and jj's `user.name`/`user.email` must be the same values, with the name derived from the account (AGENTS.md records that the copies drifted while each tool carried its own). git's `user.signingkey` stays out of jj, which uses `signing.backend` plus `signing.key`, so a shared blob would give jj a setting it does not understand. The home is the account's home, its state version follows the system's, and home-manager and the ssh-agent are enabled. Fish is the shell every integration targets: all seven fish integrations are on and the login shell is fish — the pair [`shell-integrations.md`](./shell-integrations.md) says was inert while the account landed in bash. The identity reaches the tool modules through `extraSpecialArgs`, not through a second definition inside one of them.

### Build — what the configuration *renders*

`tests/build/default.nix`, wired as `checks.build-<group>`: each check is a `runCommand` that reads the artifacts the configuration produced and asserts on their bytes. No kernel, no QEMU, no Python — the artifact is the evidence. Two sources, both read from the evaluated configuration rather than restated: `config.system.build.etc`, the merged `/etc` activation installs, so a file is at `${cfg.system.build.etc}/etc/<name>`; and `home-manager.users.<name>.home.file.<absolute path>.source`, the exact file home-manager links into the account's home. The account and its home directory are discovered from the configuration, so renaming the user moves these checks with it.

| Check | Asserts |
| --- | --- |
| `build-etc` (8) | `locale.conf` carries `LANG=en_DK.UTF-8`, `set-environment` exports `EDITOR=nano`, `localtime` links to the Copenhagen zone, the sudoers rule is `%wheel ALL=(ALL:ALL) NOPASSWD`, the three sshd posture lines, and the system fish config carries `bind ctrl-space accept-autosuggestion` |
| `build-home` (6) | the rendered git config has `gpgsign`, `format = ssh` and the signing key; the rendered jj config has **no** `signingkey`; the fish config carries the direnv and `nix-your-shell` hooks |
| `build-home-identity` (3) | git's and jj's `user.email` and `user.name` are equal **in the rendered files**, and the name is derived from the account |

A failure prints the offending file, so a drift says what changed. The one thing this tier cannot see is **activation** — a correct file that lands in the wrong place, or a correct account that never gets written; that is home-manager's and nixpkgs' own contract, and where it matters it is checked by one runtime assertion rather than by re-reading the file.

### E2E — what the running system *does*

`tests/e2e/<name>/`, wired as `checks.e2e-<name>`: these boot a machine with the **real** modules applied, through `pkgs.testers.runNixOSTest` (as in the [nix.dev integration-testing tutorial](https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines.html)), with clan-core's `clanTest` module imported.

| Test | Proves |
| --- | --- |
| `e2e-base-system` | the account exists in the passwd database with the declared shell (activation writes it, so no file in the store can say so), `sshd -T` accepts the config it will serve, and sudo actually escalates without a prompt |
| `e2e-home` | git and jj read one identity from their own activated configs, git signs a commit that verifies against `~/.ssh/allowed_signers`, the fish direnv hook exports an allowed `.envrc`, and fish accepts the `ctrl-space` key name |
| `e2e-ports` | nothing listens that the configuration did not declare |

`sshd -T` is the strongest file-related assertion that still needs the machine: `build-etc` proves the lines are in `/etc/ssh/sshd_config`, and `sshd -T` proves sshd accepts them — a line spelled right and parsed wrong satisfies the first and not the second.

`e2e-home`'s strongest assertion is a commit. `git config --get` answers from the same file whether or not git can use it, so a verified commit proves `commit.gpgsign`, `gpg.format = ssh`, the signing key and the allowed-signers file all reached the live config **and** work together. The fish half splits the same way: direnv's hook is `--on-event fish_prompt` and the `PWD` hook it defines only exists after the first prompt, which a `fish -c` shell never draws, so the function the hook installs is invoked directly. The test restates the composition `modules/home/default.nix` performs, because a clanTest builds its nodes from `clanInternals.nixosModules` (bare module sets), so `clan.specialArgs` — how the repository hands `homeManagerModule` to that module — never reaches them, and supplying it through `_module.args` recurses; the `home` unit group pins the composition and identity wiring instead, reading the real machine's evaluated configuration.

`e2e-ports` is the running-system half of the `ports` unit group, and the two are different claims: the unit test says what the configuration *intends* to expose, this says what the kernel is listening on, which is what catches a service opening a socket no option mentions. It reads `/proc/net/tcp{,6}` and `/proc/net/udp{,6}` rather than `ss`, because iproute2 is not part of a minimal system and the test must not depend on a diagnostic tool. Results are split by bound address: all-zero is exposure, anything else is not. Today the exposed set is exactly `tcp/22`, and nothing listens on loopback at all.

## The target problem

The deployed machine cannot be the e2e target: `workstation` is a NixOS-WSL guest and `system.build.installBootLoader` resolves to `${pkgs.coreutils}/bin/true` — the WSL kernel boots it, so there is no bootloader and nothing for QEMU to start. It is not merely inconvenient to test; it is not bootable. The tests apply the same modules to a test machine instead, pointing `clan.modules."base-system"` at the real `modules/clanServices/base-system`, so the module under test is the one that ships.

## Clan deployability

The `clan` unit group asserts what `clan machines update` needs before it can deploy anything. It imports `clan.nix` directly rather than reading clan's internals, so the assertions are about what this repository declares, not clan's interpretation of it.

- **Every machine is a clan machine with a build artifact** — the one `clan machines build` produces, from `clanInternals.machines` — and is in the inventory carrying a tag, or no role can target it.
- **Every instance names its module source.** `AGENTS.md` calls this the trap: a null `module.input` resolves to clan-core, so a local service silently loads the wrong module. Every `self` instance must name a module this repository defines, or clan resolves it to clan-core and fails at build time.
- **Every role is assigned to something.** A role with no tags and no machines never applies, and nothing says so. Every role tag is carried by a machine and every role's machine exists — the same silent failure spelled as a typo.

Clan accepts a role assignment in three spellings — `tags = [ "x" ]`, `tags.x = { }`, `machines.<name> = { }` — so the checks normalise all three.

## Traps

**`lib.throwTestFailures` does not exist.** `lib.runTests` returns a list of failures and the reporter lives at `lib.debug.throwTestFailures`; with the bare name, a *failing* unit test reported `attribute 'throwTestFailures' missing` instead of its own name and values, unnoticed because the branch only evaluates when a group fails. Fixed: `modules/flake/tests.nix` calls `lib.debug.throwTestFailures`.

**`nixConfig` cannot be read from evaluation, so it is not tested.** It sits outside the flake's outputs: `builtins.getFlake` has no `nixConfig` attribute, `nix flake metadata --json` omits it, and parsing `flake.nix` as text breaks on any reformat. The `flake` group asserts the invariant from the machine side instead (the three caches, no `cache.clan.lol`, flake config not accepted silently). Consequence: a cache added to `nixConfig` and *not* to `base-system` is caught by nobody.

**`base-system`'s `username` default is unreachable.** `perInstance.nixosModule` takes `username ? null` and gates the user half on `lib.mkIf (username != null)`, but the module system resolves a formal argument from `_module.args` and errors when it is absent, so omitting `username` fails evaluation instead of yielding `null` and the guard is always true. Found by `e2e-ports`, which tried to omit the argument. Either default `username` in `_module.args`, or delete a guard that cannot be false.

**clan-core enables systemd-resolved, opening three undeclared ports.** `e2e-ports`' first run reported `TCP exposed: [22, 5355]` and `UDP exposed: [5353, 5355]` — LLMNR, mDNS and the loopback DNS stub — from `systemd-resolved`, which clan-core's networking module turns on (it provides the mDNS clan advertises). This repository disables it with `services.resolved.enable = lib.mkForce false`, but only in `modules/clanServices/wsl`, because WSL supplies its own resolver. Consequences: a non-WSL machine in this clan would run resolved and expose three undeclared listeners, and the firewall's `udp/5353` allow (from clan-core, not here) is for a service this repository turns off.

**Containers need nix's `uid-range` system feature.** clan's harness defaults to `useContainers = true` (nspawn, much faster than a VM), but a container test needs `uid-range`, which nix advertises only when the builder sets `auto-allocate-uids`; nixpkgs' default `system-features` is `[ "nixos-test" "benchmark" "big-parallel" "kvm" ]`, so the build fails with

```console
error: Cannot build '...-container-test-run-...drv'.
       Reason: missing system features
       Required features: {kvm, nixos-test, uid-range}
       Available features: {benchmark, big-parallel, kvm, nixos-test}
```

The tests use `useContainers = false`, which needs only `kvm` and `nixos-test`. To get the faster path, set `nix.settings.auto-allocate-uids = true` on the builders, then flip `useContainers` to `true` and rename `nodes` to `containers`.

**`sshd -T` needs host keys and echoes the config's casing.** It exits 1 with `no hostkeys available -- exiting` when host keys are absent, so an assertion on it must run `ssh-keygen -A` first — a no-op once `sshd-keygen` has run. And NixOS writes `PasswordAuthentication no`, not the lowercase form, while sshd does not normalise keywords in its `-T` output, so the comparison must be case-insensitive.

## Not tested

- **The build and the diagram's contents** — `modules/flake/checks.nix` already builds every machine's toplevel, so a test repeating it would be a second, slower copy, and `checks.topology` builds the SVG, so asserting on it would pin a renderer's layout.
- **The WSL-specific half** — `modules/clanServices/wsl` configures a guest for the WSL kernel, nothing off-WSL can boot it, so the unit tests and topology check cover it.
- **The gaps**: no `systemd.services.*.enable` allow-list (partial — `e2e-ports` catches the ones that listen), no `systemPackages` closure check, no deprecated-alias check (most surface through `warnings`), no installer or image (this clan has none), and no vars-currency check (`clan vars check` reads the on-disk store and does not belong in a pure evaluation).

Secrets in the store or a committed file are covered by `gitleaks` in the pre-commit hooks; a clean-checkout evaluation by `nix flake check` itself.

## The gate and the git hooks

`nix flake check` is the only command needed, and it runs on every commit. It covers everything: `checks.nix` builds each machine's toplevel, `nix-topology.nix` builds the diagram, `tests.nix` contributes the unit, build and e2e checks, and `checks.pre-commit` runs the lint hooks. A commit is refused unless all of it passes.

The pre-commit hook that invokes it is guarded, and the guard is load-bearing:

```console
sh -c 'if [ -n "$NIX_BUILD_TOP" ]; then exit 0; fi; ...; exec nix flake check'
```

`nix flake check` builds `checks.pre-commit`, which runs `pre-commit run --all-files`, so a hook in the `pre-commit` stage runs *inside* the gate and an unguarded `nix flake check` hook would call the gate again without end. `NIX_BUILD_TOP` is set inside a Nix build and unset in a shell — measured, unlike `IN_NIX_SANDBOX`, which this Nix leaves unset even in a sandboxed build — so the nested invocation returns immediately and recursion stops at depth one.

Measured cost of a commit, warm store, on this machine:

| change | checks rebuilt | time |
| --- | --- | --- |
| nothing | 0 | ~45s |
| a comment | 2 | ~45s |
| the system closure | 19 | ~49s |
| the shared `base-system` module | 47 | ~114s |

The last row is the one to know: touching a module the VM tests apply rebuilds their nodes and re-runs both VMs.

The lint hooks run twice per commit — once directly, once inside the gate; seconds and idempotent, so deliberate rather than worth unpicking. They live in `.pre-commit-config.yaml`, a symlink into the store, which only moves when the flake is re-evaluated and the install script re-run, as `nix develop` does: a hook added to `git-hooks.nix` without re-entering the devshell is written down and never installed — that is how the `nix flake check` hook sat inert in `modules/flake/git-hooks.nix` while the installed config predated it.

## Running them

```console
nix flake check                                 # everything, including the VM tests
nix build .#checks.x86_64-linux.ports           # one unit group, milliseconds
nix build .#checks.x86_64-linux.build-etc       # one build group, seconds
nix build .#checks.x86_64-linux.e2e-home        # one e2e test, minutes
nix log .#checks.x86_64-linux.e2e-home          # the VM's own log
nix develop                                     # reinstalls the git hooks
```

The attribute name is the group name — `checks.x86_64-linux.ports`, not `unit-ports`. The `unit-`/`build-` prefix is the *derivation* name, which is what a log or a store path shows; `e2e-` is in both.

The e2e tests boot a VM, so they cost minutes and need `/dev/kvm` — the price of the only check that can see what a daemon actually does, and why the cheaper tiers exist alongside them: a change that breaks a rendered file fails in seconds, before a VM is built.
