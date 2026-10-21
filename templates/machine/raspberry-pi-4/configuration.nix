# Skeleton for a Raspberry Pi 4 Model B. Created with
#
#   clan machines create pi --template .#raspberry-pi-4
#
# or the aliased `clan templates apply machine .#raspberry-pi-4 pi`.
#
# Board support arrives as a MODULE, not through that flake's own `lib.nixosSystem`
# helper: clan makes the `nixpkgs.lib.nixosSystem` call itself, so the input reaches
# machines through `clan.specialArgs` (flake.nix) and is imported here. It brings the
# vendor kernel, the matched firmware and the `/boot/firmware` partition handling.
{
  config,
  nixos-raspberrypi,
  ...
}:
{
  # Shared with the `systems` assertion in tests/unit/flake.nix.
  nixpkgs.hostPlatform = import ./platform.nix;

  networking.hostName = config.clan.core.settings.machine.name;

  imports = [ nixos-raspberrypi.nixosModules.raspberry-pi-4.base ];

  # This machine runs nothing by decision (docs/milestone.md): it is the always-on
  # overlay peer, so a machine that is not at home can still reach the machines that
  # are. Services belong in the inventory, not in this file.

  topology.self = {
    parent = "home-router";
    interfaces.eth0.network = "lan";
  };
}
