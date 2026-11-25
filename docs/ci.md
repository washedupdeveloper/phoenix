# The CI runner

The gate runs on a machine you own, not on a hosted runner. That is a decision with a
reason, and the reason is not cost.

## Why self-hosted

The gate builds every machine's toplevel and runs three test tiers, the last of which
boots QEMU guests through `pkgs.testers.runNixOSTest`. Those guests need `/dev/kvm`.
GitHub-hosted runners do not provide it, and there is no paid tier that does — nested
virtualisation is not offered on standard or larger runners. A gate on a hosted runner
would therefore skip the VM tier and report green over a smaller gate than a commit
runs locally, which is worse than no gate: it reads as coverage.

Self-hosted is also free, which is why cost never enters the decision. What it costs
is availability: the machine has to be awake when you push.

## What a host must satisfy

| requirement | why |
| --- | --- |
| Linux | `runNixOSTest` boots a guest of the host platform; it is not a macOS or Windows test |
| Nix with flakes | the job runs `nix flake check` |
| `/dev/kvm`, readable and writable | the VM tier; without it the e2e checks cannot run |
| room for a NixOS closure | a cold gate builds system toplevels and test drivers |
| admin on the repository | registering a runner is an administrative action |

`preflight.yml` asserts all of it on the host itself:
`gh workflow run preflight.yml`. Run it before trusting a new machine.

## Two ways to run one

### `bin/runner` — portable, no state

For any Linux host with Nix, `gh` and KVM. Nothing is configured and nothing is
stored: the registration token is minted from your existing `gh` login, expires within
the hour, and the runner is ephemeral.

```bash
bin/runner                       # this repository
bin/runner --repo owner/fork     # another repository
bin/runner --labels kvm,cuda     # extra labels the workflow can select
bin/runner --dry-run             # say what it would do
```

It runs in the foreground; Ctrl-C stops it, and the temporary work directory is
removed on exit. That is the whole setup.

### `modules/ci-runner.nix` — declarative, always on

For a NixOS host that should be registered permanently. The machine's configuration
names the repository, the labels and the token file; the module wires
`services.github-runners`:

```nix
services.ci-runner = {
  enable = true;
  url = "https://github.com/owner/repo";
  labels = [ "kvm" ];
  tokenFile = "/run/secrets/github-runner-token";
};
```

The token is deliberately not the module's business: point `tokenFile` at whatever the
host already uses for secrets. A token that may register a runner needs administration
on the repository; a registration token expires within the hour, so the durable choice
is a PAT-style token.

## The labels are the contract

`gate.yml` selects `[ self-hosted, linux, kvm ]`. `self-hosted` and `Linux` come from
the runner, `kvm` is the host's claim that it can boot a guest. A host without
`/dev/kvm` should not advertise `kvm` — the gate would fail on it rather than fall back.

## Fork safety

`gate.yml` deliberately omits `pull_request`. This repository is public, and a
`pull_request` workflow runs from the PR's merge commit, so a fork that edits the
workflow deletes its own guard — the job would execute attacker-authored YAML and
attacker-authored Nix builders on the registered machine. The trigger set is the
control, not anything inside the file. Restoring fork-safe PR CI needs the repository's
fork-approval policy set to require approval for all external contributors first, which
is a repository setting no file can assert.

`preflight.yml` carries the same constraint: `workflow_dispatch` only.

## Stopping it

- `bin/runner`: Ctrl-C. The runner deregisters itself when ephemeral, otherwise
  `./config.sh remove --token <registration-token>` from its work directory.
- Module: set `services.ci-runner.enable = false` and rebuild, or stop
  `github-runner-<name>.service`.
