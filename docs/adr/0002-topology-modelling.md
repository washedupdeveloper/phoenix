# ADR-0002: Modelling the Windows-host / WSL topology

**Status:** Accepted
**Date:** 2026-10-02
**Deciders:** nixolotl

## Context

`workstation` is not a physical machine. It is a NixOS-WSL guest running under
a Windows 11 host, on a private NAT segment that Windows creates and manages,
which is itself behind an ISP router on the home LAN. The repository carried a
`topology.nix` describing an internet uplink, a "Windows Host" with one
unnamed NIC, and a `lan` network -- and nothing imported it.

The flake-parts wiring that was supposed to connect it read:

```nix
perSystem = {
  topology.modules = [ rootConfig.nixosConfigurations ];
};
```

Two things are wrong with that line, and only one of them is obvious:

1. `config.nixosConfigurations` does not exist at the flake-parts top level.
   The flake output is `config.flake.nixosConfigurations`. The whole `topology`
   output therefore failed to evaluate with `error: attribute
   'nixosConfigurations' missing`.
2. Even with the path corrected, the line would be redundant. nix-topology
   defaults `perSystem.topology.nixosConfigurations` to

   ```nix
   lib.filterAttrs (_: x: x.config ? topology) self.nixosConfigurations
   ```

   so any machine that imports `nix-topology.nixosModules.default` is picked up
   without being named. `topology.modules` is for *additional topology
   modules*.

Neither failure was caught, because `nix flake check` does not know the
`topology` output. It reports `warning: unknown flake output 'topology'` and
moves on. The breakage was only visible from the dangling `result` symlink at
the repository root.

## Decision

1. **`topology.modules` lists the global topology module, not machines.**
   `modules/topology.nix` sets `perSystem.topology.modules = [ ../topology.nix ]`.
   The per-machine half is left to nix-topology's default, which is the
   documented behaviour.
2. **Model the physical world, not the NixOS view of it.** The Windows host is
   a `device` node carrying the hardware, the wired NIC's MAC and DHCP address,
   and the Hyper-V switch WSL2 attaches to. The router is a `router` node. The
   LAN and WSL2's NAT segment are two separate networks, because they are two
   separate networks -- folding them together would misrepresent the NAT.
3. **The guest relationship is declared, not implied.**
   `topology.self.parent = "windows-host"` plus `guestType = "wsl"` on the
   machine, so the diagram draws the NixOS node under its host. `guestType` is
   free-form -- nix-topology's built-ins are `microvm` and `nixos-container` --
   and only feeds the default hardware info.
4. **The rendered output is a check.** `modules/topology.nix` re-exposes
   `config.flake.topology.<system>.config.output` as
   `checks.<system>.topology`, so `nix flake check` evaluates and builds the
   diagram. This is what stops (1) from recurring silently.

## Options Considered

### Option A: `topology.modules = [ config.flake.nixosConfigurations ]`

| Dimension | Assessment |
| --- | --- |
| Correctness | Low -- restates a default, and couples the flake to an internal option path |
| Resilience to nix-topology changes | Low -- the default is documented; a manual restatement can drift from it |
| Verbosity | Low |

**Pros:** makes the machine list explicit at a glance.

**Cons:** it is the same information nix-topology already derives, spelled a
second way, and it is the spelling that broke.

### Option B: rely on the default, list only global definitions (chosen)

| Dimension | Assessment |
| --- | --- |
| Correctness | High -- matches the documented contract for `topology.modules` |
| Resilience | High -- a new machine joins the diagram by importing the NixOS module, which it must do anyway |
| Verbosity | Low |

**Pros:** one place to declare the non-derivable parts; machines need no
topology wiring at all.

**Cons:** the set of rendered machines is implicit, so it is not visible from
`modules/topology.nix`. Mitigated by the check in (4), which fails loudly if
the set comes out empty or unbuildable.

### Option C: give the mosquitto listener an explicit `address`

nix-topology's mosquitto extractor renders the listen string by interpolation
with a fallback that only fires when the attribute is *absent*
(`l.address or "[::]"`), while nixpkgs declares that address as `nullOr str`
defaulting to `null`. The topology build therefore died with `cannot coerce
null to a string` until the derived value was overridden. The mechanics are in
[`../flake-internals.md`](../flake-internals.md); what follows is the decision.

| Dimension | Assessment |
| --- | --- |
| Effect on the broker | Changes it -- `address = "0.0.0.0"` binds IPv4 only, where an unset address listens on every interface |
| Effort | Lower -- one line in `configuration.nix` |
| Honesty | Low -- configures a network service to satisfy a diagram renderer |

**Pros:** less code, and the extractor would work.

**Cons:** silently narrows how the MQTT broker listens, in exchange for a
rendering fix. Rejected: the workaround belongs in the topology, not in the
service.

## Trade-off Analysis

The choice between A and B is the choice between restating a default and
trusting it. Restating a default is only worth it when the default is likely to
change underneath you; here the default is the documented contract of the
option, so a manual restatement buys nothing and can only drift. The cost of B
-- the rendered machine set being implicit -- is real but small, and it is
exactly the kind of cost the new `checks.<system>.topology` entry pays for.

For the mosquitto problem, the trade-off is between a one-line change to a
running service and a slightly longer workaround in the diagram. Service
behaviour should not be a rendering decision, so the workaround stays in
`configuration.nix` next to the topology it belongs to.

## Consequences

- Adding a machine needs no change to `modules/topology.nix`; it needs
  `topology.self` in its own configuration and the `nix-topology` NixOS module,
  which the `topology` importer instance already applies to everything tagged
  `all`.
- The `topology` flake output is now covered by `nix flake check`. The
  `warning: unknown flake output 'topology'` line remains -- nix has no
  category for it -- but a broken diagram now fails the check.
- A future upstream fix to the mosquitto extractor makes the override in
  `machines/workstation/configuration.nix` redundant. It can be deleted then;
  it is `lib.mkForce`, so it will keep winning until it is.
- The Windows host's addresses are recorded by hand from `ipconfig /all`. If
  the DHCP lease or the NIC changes, the diagram is wrong until
  `topology.nix` is edited. The MAC is the stable part.

## Action Items

1. [x] `nix build .#topology.x86_64-linux.config.output` succeeds and
   `main.svg` shows Internet -> Home router -> Desktop-Storm, the WSL2 NAT
   network, and the NixOS node hanging off the host's `guests` port.
2. [x] `nix flake check` passes, and lists `checks.x86_64-linux.topology`.
3. [ ] Consider filing the mosquitto extractor bug upstream -- see
   [`../recommendations.md`](../recommendations.md) section 4.1.
4. [ ] Re-check the host's addresses the next time the DHCP lease is renewed,
   and the NIC's MAC if the hardware changes.
