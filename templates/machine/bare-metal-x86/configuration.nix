# Skeleton for a bare-metal x86_64 machine (the ThinkPad shape). Created with
#
#   clan machines create thinkpad --template bare-metal-x86
#
# which copies this directory to `machines/thinkpad/` and records the machine in the
# inventory. Nothing here is derivable-from-nothing: the hostname comes from the
# machine's own name, and the account, dotfiles, sshd, base-system and the topology
# importer all arrive from the inventory tag `all`. What is left is what only this
# machine knows -- its platform, its bootloader, and where it sits in the network.
{
  config,
  ...
}:
{
  # The platform lives in `platform.nix` so `systems` in flake.nix can be asserted
  # against what the templates aim at, not only against machines that already exist.
  nixpkgs.hostPlatform = import ./platform.nix;

  # Not a second copy of the name: `test_host_name_matches_the_machine_name` asserts
  # the two agree, and this spelling cannot disagree.
  networking.hostName = config.clan.core.settings.machine.name;

  # A bare-metal machine needs a bootloader. This is not in `base-system` because the
  # WSL guest has none: `system.build.installBootLoader` there is `true`, so QEMU has
  # nothing to start and the guest switches its generation instead.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Partitioning and disk encryption are deliberately absent -- both are deferred
  # items in docs/milestone.md, decided with the hardware in hand. If you reach for
  # disko, `clan templates list` also shows its disk templates, and
  # `clan templates apply disk ext4-single-disk <name> --set mainDisk <by-id>` applies
  # one to this machine.

  # Where the machine sits. `parent` must name a device or machine in `topology.nix`
  # and `network` must be one it defines; both are asserted. No address: a DHCP lease
  # is 3 hours and the recorded one would be stale (docs/adr/0002).
  topology.self = {
    parent = "home-router";
    interfaces.eth0.network = "lan";
  };
}
