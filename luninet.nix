# luninet's peer list, read from the pinned input rather than copied.
#
# Upstream keeps the authoritative data in two files and merges them in its own flake --
# `lib.recursiveUpdate (import ./peers.nix) inventory.network` -- then maps each entry
# through `lib.toPeers`. The merge and the mapping are repeated here, because calling the
# upstream `lib` output would evaluate its flake and drag its own nixpkgs input in for
# four fields. Only data is read: `peers.nix` (keys, optional endpoints) and
# `inventory.json` (the generated addresses). If upstream changes either shape, this
# file is what fails, and it fails in the gate.
{
  lib,
  luninet,
  peerName,
}:
let
  declared = import (luninet + "/peers.nix");

  # Right side wins for lists and scalars, which is how the generated addresses replace
  # the hand-written ones without dropping `selfEndpoint` alongside them.
  all =
    lib.recursiveUpdate declared
      (builtins.fromJSON (builtins.readFile (luninet + "/inventory.json"))).network;

  toPeer = v: {
    inherit (v) publicKey;
    allowedIPs = (v.ipv4 or [ ]) ++ (v.ipv6 or [ ]);
    endpoint = v.selfEndpoint or null;
    persistentKeepalive = v.persistentKeepalive or null;
  };
in
{
  # Null until the registration PR is merged and the input updated: the interface then
  # carries no address, which is a no-op rather than an error. The public key in
  # `vars/.../luninet/pubkey` is what the PR registers.
  self = all.${peerName} or null;

  peers = lib.mapAttrsToList (_: toPeer) (lib.removeAttrs all [ peerName ]);
}
