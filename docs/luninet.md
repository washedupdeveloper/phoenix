# luninet

This machine joins **luninet**, the computer-club's WireGuard mesh
(`github:the-computer-club/luninet`, pinned in `flake.lock`). The change is on the branch
`feat/luninet`.

The owner provisioned this peer, so the parameters below are *given*, not derived: their
interface `wg.gandalf.luninet` at `198.12.96.43:1735`, the address they routed to this machine
(`172.29.83.15/32`), `AllowedIPs = 172.29.64.0/18`, MTU 1420, DNS `172.29.83.1`. The peer list
from the pinned input is kept alongside them, and the more specific route wins: each listed
peer's `/32` or `/64` makes a session direct where a path exists, and the hub carries the rest.

## Joining, in order

**1. The keypair already exists.** The `luninet` generator in
`machines/workstation/configuration.nix` minted it with `wg genkey` / `wg pubkey`. The private
half never leaves the vars store — age-encrypted at rest, deployed to `/run/secrets`, never the
Nix store:

```console
nix develop -c clan vars get workstation luninet/pubkey
```

**2. Give the public half to the network, under the name the owner used.** If it is not already
registered, the entry in `the-computer-club/luninet`'s `peers.nix` is:

```nix
  gandalf.publicKey = "cSvaSSxlFd/av1yWj7pq8Qofa3d+cmx/E5hzsCFQ0z0=";
  ipv4 = [ "172.29.83.15/32" ];   # the address the owner already routed to this machine
```

`docs/joining.md` upstream points at `automous-zones` for the fork — that repository is this
one, renamed. Their `nix run .#update-inventory` regenerates `inventory.json` if the canonical
form is wanted; the hardcoded address above is their documented fallback.

**3. Activate:** `sudo nixos-rebuild switch` on this branch. The interface comes up with its
address, the hub peer, and the scoped DNS.

**4. Verify:** `ip addr show asluni` (address present), `sudo wg show` (a handshake with the
hub), `ping 172.29.83.1` (the DNS server, inside the routed range), and
`resolvectl query <peer>.luni` (resolution through the mesh).

## What this means for the machine — measured where measured, given where given

| | |
| --- | --- |
| interface | `asluni`, MTU 1420, unit `wireguard-asluni.service`; `wireguard-tools` is installed by the module |
| this machine's address | `172.29.83.15/32` — the address routed to it by the owner |
| peers | the hub (`172.29.64.0/18` via `198.12.96.43:1735`) plus **11** from the pinned peer list, each with its own `/32` or `/64` |
| routing | AllowedIPs decide: the whole routable range via the hub, each listed peer's `/32`/`/64` direct where a path exists. The default route is untouched — a split tunnel, and everything outside those prefixes goes out unchanged |
| inbound | **yes, from the mesh.** `persistentKeepalive = 25` on the hub peer holds a NAT mapping open, which is what lets their side open the session their route expects — so services listening on every interface are reachable from the mesh, not only after this machine speaks first |
| DNS | `.luni` resolves through `172.29.83.1`, scoped to that domain by `resolvectl domain asluni luni.` in the interface's `postSetup`. No other name goes to that server |
| secrets | private key in the vars store; only the public half is public |
| tooling | `wireguard-tools-1.0.20260223` in `environment.systemPackages` on this branch — absent from the running system until the switch |

## The honest blast radius

- **The mesh can reach this machine's services.** Not because a port is open — none is — but
  because the hub peer keeps a mapping alive so the owner's side can initiate. On this machine
  that means `sshd` (key-only, so the boundary is the authorized-keys list) and the broker
  (`mosquitto`, TCP 1883, cleartext MQTT behind one password, bound to every interface). If the
  broker's exposure to club members is not acceptable: bind it to the LAN interface, or drop
  `persistentKeepalive` and accept the reverse trade — their side then cannot initiate, and
  their route to `172.29.83.15` becomes one-directional.
- **`172.29.64.0/18` is routed to a peer you do not control.** Joining is a routing decision as
  much as a networking one: traffic to that range is carried by them, and `.luni` names are
  answered by their server.
- **The identity is `gandalf`**, and the peer list is read from a pinned input — `nix flake
  update luninet` is the deliberate act that changes who else is on the wire.
- **Nothing here is a commercial VPN.** Only the mesh prefixes are encapsulated; browsing and
  everything else take the normal path.

## Not included, deliberately

Their `aslunip2p` peer list (direct peer-to-peer discovery through `wgsd`/DNS-SD), named keys
for `wg show` (needs the `flake-guard-v2` input plus a patched `wireguard-tools`), and the
flake-guard modules — this repository manages the key through the clan vars store, and adopting
theirs would put one secret in two places. Each is an addition to the interface above.

Nothing here is live until the switch: the branch declares the interface, and the address is
`172.29.83.15/32` whether or not the registration has been merged, because the owner gave it
directly.
