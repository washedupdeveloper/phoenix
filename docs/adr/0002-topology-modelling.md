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
   throughout, so the guest's `wsl0` sits on `lan` with its own address.
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
  redundant. It can be deleted then; until it is, it keeps winning.
- Host addresses are recorded by hand from `ipconfig /all`, the guest's from
  `ip addr`. A new DHCP lease or NIC makes the diagram wrong until edited; the MAC
  is the stable part.

## Action Items

1. [x] `nix build .#topology.x86_64-linux.config.output` succeeds; `main.svg` shows
   Internet → Home router → Desktop-Storm with the guest on the LAN.
2. [x] `nix flake check` passes and lists `checks.x86_64-linux.topology`.
3. [ ] Consider filing the mosquitto extractor bug upstream — see
   [`../recommendations.md`](../recommendations.md).
4. [ ] Re-check the host's addresses when the DHCP lease renews.
