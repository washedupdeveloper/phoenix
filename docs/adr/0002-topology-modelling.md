# ADR-0002: Modelling the Windows-host / WSL topology

**Status:** Accepted
**Date:** 2026-10-02
**Deciders:** nixolotl

## Context

`workstation` is not a physical machine: a NixOS-WSL guest under a Windows 11 host,
which sits behind an ISP router on the home LAN. The repository carried a
`topology.nix` describing an uplink, a "Windows Host" and a `lan` network — and
nothing imported it. The flake-parts wiring meant to connect it read:

```nix
perSystem = {
  topology.modules = [ rootConfig.nixosConfigurations ];
};
```

Two things are wrong with that line, only one obvious:

1. `config.nixosConfigurations` does not exist at flake-parts' top level; the output
   is `config.flake.nixosConfigurations`. The whole `topology` output failed with
   `error: attribute 'nixosConfigurations' missing`.
2. Even corrected, it is redundant. nix-topology defaults
   `perSystem.topology.nixosConfigurations` to
   `lib.filterAttrs (_: x: x.config ? topology) self.nixosConfigurations`, so any
   machine importing `nix-topology.nixosModules.default` is picked up unnamed.
   `topology.modules` is for *additional topology modules*.

Neither was caught: `nix flake check` does not know the `topology` output, warns
`unknown flake output 'topology'`, and moves on.

## Decision

1. **`topology.modules` lists the global topology module, not machines.**
   `modules/flake/nix-topology.nix` sets
   `perSystem.topology.modules = [ ../../topology.nix ]`; the per-machine half is
   nix-topology's documented default.
2. **Model the physical world, not the NixOS view of it.** The Windows host is a
   `device` node carrying the hardware and the wired NIC's MAC and address; the
   router is a `router` node. A WSL NAT segment is modelled only for as long as it
   exists — it does not, because `networkingMode=mirrored` has been in use
   throughout, so the guest's NIC sits on `lan`. (The address itself was recorded here
   and is now omitted — see the amendment.)
3. **The guest relationship is declared, not implied.**
   `topology.self.parent = "windows-host"` plus `guestType = "wsl"`, so the diagram
   draws the NixOS node under its host. `guestType` is free-form (nix-topology's
   built-ins are `microvm` and `nixos-container`) and renders as the type label; it
   also defaults `hardware.info`, which this machine overrides.
4. **The rendered output is a check.**
   `config.flake.topology.<system>.config.output` is re-exposed as
   `checks.<system>.topology`, so the gate builds the diagram. This is what stops
   (1) recurring silently.

## Options Considered

**A — restate `config.flake.nixosConfigurations` in `topology.modules`.** Makes the
machine list explicit, but it is the same information nix-topology derives, spelled
a second way, and it is the spelling that broke. Rejected.

**B — rely on the default, list only global definitions (chosen).** Matches the
documented contract; a new machine joins by importing the NixOS module it needs
anyway. The rendered set becomes implicit, which the check in (4) pays for.

**C — give the mosquitto listener an explicit `address` to satisfy the renderer.**
nix-topology's extractor interpolates with `l.address or "[::]"`, a fallback that
only fires when the attribute is absent, while nixpkgs declares it `nullOr str`
defaulting to `null` — so the build died with `cannot coerce null to a string`.
`address = "0.0.0.0"` would bind IPv4 only, silently narrowing how the broker
listens. Rejected: service behaviour is not a rendering decision. The override
lives in the machine's `topology.self` block instead.

## Consequences

- Adding a machine needs no change to `modules/flake/nix-topology.nix`; it needs
  `topology.self` and the nix-topology NixOS module, which the `topology` importer
  instance applies to everything tagged `all`.
- The `unknown flake output 'topology'` warning remains — nix has no category for it
  — but a broken diagram now fails the check.
- An upstream fix to the mosquitto extractor makes the `lib.mkForce` override
  redundant. It can be deleted then; until it is, it keeps winning. Verified against the
  pinned revision (2026-10-20): the extractor still reads `l.address or "[::]"`, so the
  override is still load-bearing.
- The model carries no DHCP address (amendment above). A new NIC still makes the
  diagram wrong until edited, but the MAC — the part that does not move — is what it
  records, so the drift is now a hardware change rather than an ordinary lease renewal.

## Amendment (2026-10-20): the recorded addresses were the wrong half

Action item 4 asked for the host's address to be re-checked when the DHCP lease
renews. Doing it once was enough to see the item is unanswerable as written:

- the wired NIC's lease is **3 hours** (`ipconfig /all`: obtained 16:23, expires 19:23),
  and the address had already moved — `.107` recorded, `.108` measured;
- with mirrored networking the guest's `eth0` presents **that same address**, so the
  guest's recorded `.108` was not "its own" at all;
- nothing reads either value. They were diagram labels.

So both recorded IPv4 addresses are gone, and the model keeps what does not rot: the
MAC (`30:c5:99:26:e1:4f`, verified against the adapter), the router's static `.1`, and
the network's `cidrv4`. Re-copying `.108` would have made the file true for three hours
and wrong again before the next switch.

The guest interface is renamed `wsl0` → `eth0` for the same reason: NAT mode names it
`wsl0`, mirrored mode gives it the host's `eth0`. A stable-address model would need a
DHCP reservation on the router, which is the router's configuration, not this flake's.

## Action Items

1. [x] `nix build .#topology.x86_64-linux.config.output` succeeds; `main.svg` shows
   Internet → Home router → Desktop-Storm with the guest on the LAN.
2. [x] `nix flake check` passes and lists `checks.x86_64-linux.topology`.
3. [ ] File the mosquitto extractor bug upstream — drafted, not filed: it is a
   publication to someone else's tracker. Tracked as
   [`../recommendations.md`](../recommendations.md) 4.1, which carries the one-line fix.
4. [x] Addresses: resolved by the amendment above — the volatile values were removed
   rather than re-recorded.
