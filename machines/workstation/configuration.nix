{
  config,
  lib,
  pkgs,
  username,
  luninet,
  ...
}:
let
  # This machine's view of the mesh: every other peer, read from the pinned input
  # (luninet.nix). `peerName` is the identity the mesh knows this machine by -- the
  # owner's own configuration calls this peer `gandalf` (`wg.gandalf.luninet`), and it
  # is the name to submit in luninet's `peers.nix`.
  mesh = import ../../luninet.nix {
    inherit lib luninet;
    peerName = "gandalf";
  };
in
{
  networking = {
    hostName = "workstation";
    # Mirrored networking supplies the address from the Windows host; a default
    # DHCP client would compete with it for the lease.
    useDHCP = false;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  programs.nix-ld.enable = true;

  # Overrides base-system's mkDefault; `programs.nh.clean` below does the same job
  # with a keep-policy, and running both would duplicate it.
  nix.gc.automatic = false;

  # `nix.settings.max-jobs` / `cores` stay unset on purpose: the NixOS defaults
  # mean "use the machine", and `cores = 1` is a downgrade, not a safety margin.
  # Traps and measurement: docs/adr/0003.
  #
  # `download-buffer-size` is likewise unset: Nix 2.33 fixed the warning at source.

  # `aarch64-linux` is in the flake's `systems`, so the gate has to BUILD aarch64
  # derivations on this host -- without a builder for that platform nix refuses with
  # "a 'aarch64-linux' ... is required to build ... but I am a 'x86_64-linux'".
  # qemu-user through the kernel's binfmt_misc, registered by systemd-binfmt on
  # activation; the module also adds the platform to `nix.settings.extra-platforms`.
  # Measured: the same rebuilt check takes 8.6s against 8.3s native (the aarch64 leg is
  # evaluation and trivial builders, so emulation is not what it costs); see
  # docs/testing.md for the tier split that keeps a compiled kernel off it.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 4";
    flake = "/home/${username}/projects/phoenix";
  };

  # --- secrets ---------------------------------------------------------------
  #
  # One assignment per option, because clan nests every generator under
  # `clan.core.vars.generators` and three separate spellings of that key are three
  # homes for one fact (statix W20). Each generator keeps its own reasoning.
  clan.core.vars.generators = {
    # The WireGuard keypair for the mesh (docs/luninet.md). The PUBLIC half is what the
    # registration PR puts in luninet's `peers.nix`; the private half never leaves the
    # vars store -- age-encrypted at rest, deployed to `/run/secrets`, never into the
    # store. Mint them with
    #   clan vars generate workstation --generator luninet
    # and read the public key back with
    #   clan vars get workstation luninet/pubkey
    # Regenerating would break the registration, so it is a rotation, not a fix.
    luninet = {
      files.key = {
        # The interface must pick up a rotated key rather than keep running on the old
        # one. It is a `systemd-networkd` netdev (no `wg-*` service exists), so the
        # restart that re-reads the key is networkd's own.
        restartUnits = [ "systemd-networkd.service" ];
      };
      files.pubkey.secret = false;
      runtimeInputs = [ pkgs.wireguard-tools ];
      script = ''
        wg genkey > "$out"/key
        wg pubkey < "$out"/key > "$out"/pubkey
      '';
    };

    # The broker credential lives in the clan vars store: this generator mints it and
    # only the hash is deployed. Plaintext for the device:
    #   clan vars get workstation mosquitto-plant-monitor/plant-monitor-password
    mosquitto-plant-monitor = {
      files.plant-monitor-password.deploy = false;
      files.plant-monitor-password-hash.neededFor = "services";

      runtimeInputs = [
        pkgs.coreutils
        pkgs.mosquitto
        pkgs.xkcdpass
      ];

      script = ''
        # `-U` hashes a plaintext `user:password` file in place. The `-b` form
        # would put the secret in argv instead, where /proc/<pid>/cmdline stays
        # world-readable for the life of the process. The plaintext file is built
        # by redirection, so it never becomes an argument either. `umask` comes
        # first so that file is 0600 for the moment it exists.
        umask 077
        xkcdpass --numwords 6 --delimiter - --count 1 | tr -d "\n" > "$out"/plant-monitor-password
        { printf 'plant_monitor:'; cat "$out"/plant-monitor-password; printf '\n'; } > "$out"/plant-monitor-passwd
        mosquitto_passwd -U "$out"/plant-monitor-passwd
        cut -d: -f2 "$out"/plant-monitor-passwd > "$out"/plant-monitor-password-hash
        rm "$out"/plant-monitor-passwd
      '';
    };

    # The CI runner's token: asked for rather than written down, because a
    # registration token is minted by GitHub. `persist` keeps the answer as the secret
    # var `token`, which is what makes `--regenerate` a usable recovery path for a
    # revoked PAT -- the reasoning and the commands are in the CI section below.
    github-runner-token = {
      prompts.token = {
        description = "GitHub fine-grained PAT (Administration: read and write) for the runner";
        type = "hidden";
        persist = true;
      };

      # Regenerating the token must reach the service, or the documented recovery path
      # ("--regenerate" after a revoked PAT) leaves a runner running on the old one.
      files.token.restartUnits = [ "github-runner-gate.service" ];
    };
  };

  # Inert on WSL: nixos-wsl sets `systemd.services.firewall.enable = false`, so
  # this rule is not enforced and every listener is open -- :22 from base-system and
  # :1883 here -- to whatever the Windows host is exposed to, mirrored networking
  # meaning the host's reach. Accepted for a proof-of-concept broker. MQTT is
  # cleartext (no cafile/certfile), so the password bounds a guesser, not a passive
  # listener. Written as an eth0 rule so it is already correct if the unit is forced
  # on: `systemd.services.firewall.enable = lib.mkForce true;`
  networking.firewall.interfaces.eth0.allowedTCPPorts = [ 1883 ];
  services = {
    # `prunePaths` replaces the nixpkgs default rather than extending it, so the
    # default entries are restated here. /mnt holds the host's 9p volumes.
    locate = {
      enable = true;
      prunePaths = [
        "/mnt"
        "/tmp"
        "/var/tmp"
        "/var/cache"
        "/var/lock"
        "/var/run"
        "/var/spool"
        "/nix/store"
        "/nix/var/log/nix"
      ];
    };

    mosquitto = {
      enable = true;
      listeners = [
        {
          port = 1883;
          users.plant_monitor = {
            hashedPasswordFile =
              config.clan.core.vars.generators.mosquitto-plant-monitor.files.plant-monitor-password-hash.path;
            acl = [ "readwrite plants/#" ];
          };
        }
      ];
    };
  };

  # --- luninet (docs/luninet.md) ------------------------------------------------
  #
  # The owner's own parameters for this peer, which is what makes it work: their
  # WireGuard interface `wg.gandalf.luninet` at `198.12.96.43:1735`, the address they
  # routed to this machine (`172.29.83.15/32`), and AllowedIPs covering the whole
  # routable range so the hub carries what the direct peers cannot.
  #
  # Two layers, and the more specific route wins:
  #
  #   * `mesh.peers` -- every peer from the pinned peer list, each with its own `/32`
  #     or `/64`, so a session that can be direct is direct;
  #   * the hub below -- `172.29.64.0/18` through the owner's endpoint, which is what
  #     reaches a peer that has no `selfEndpoint` at all.
  #
  # `persistentKeepalive` on the hub peer is deliberate rather than idle noise: this
  # machine has no fixed listen port, so the only way their side can open the session
  # its route expects is a NAT mapping this side keeps alive.
  #
  # `postSetup` scopes DNS to the mesh instead of setting a system-wide resolver: the
  # `.luni` domain goes to the network's own server, and nothing else does.
  networking.wireguard.interfaces.asluni = {
    privateKeyFile = config.clan.core.vars.generators.luninet.files.key.path;
    mtu = 1420;
    ips = [ "172.29.83.15/32" ];
    peers = mesh.peers ++ [
      {
        publicKey = "oKOdqE808abkFj55UV3gvBzZtkxhIrDPfBWDSjEqPG4=";
        endpoint = "198.12.96.43:1735";
        allowedIPs = [ "172.29.64.0/18" ];
        persistentKeepalive = 25;
      }
    ];
  };

  # DNS, the networkd way. `networking.wireguard.useNetworkd` defaults to true as soon as an
  # interface is declared (nixpkgs: `default = cfg.interfaces != { }`), so this interface is a
  # `systemd.network` unit and a `postSetup` script is refused by assertion. The module
  # generates `systemd.network.networks."40-asluni"`; this merges into that same unit, which
  # makes the resolver part of the configuration rather than a command run once at start-up.
  # `~luni` is a routing-only domain: queries for `.luni` go to the mesh's server, and no other
  # name does.
  systemd.network.networks."40-asluni".networkConfig = {
    DNS = [ "172.29.83.1" ];
    Domains = [ "~luni" ];
  };

  # networkd deletes every routing policy rule, route and nexthop it did not
  # create, on every start -- boot included. On WSL three of those are
  # load-bearing: the kernel's local-delivery rule (`0: from all lookup local`)
  # and the mirror's two sets (loopback delivery for `iif eth0|loopback0` and
  # the `127`/`128` table selects that carry connections between Windows and
  # the guest). With them gone the guest routes its own addresses out eth0, the
  # desktop's gateway at `127.0.0.1:9119` dies, and because the purge re-runs at
  # boot no restart or switch heals it. None of these rules are ours, so the
  # cleanup has nothing to own here -- keep it off.
  systemd.network.config.networkConfig = {
    ManageForeignRoutes = false;
    ManageForeignRoutingPolicyRules = false;
    ManageForeignNextHops = false;
  };

  # A WSL guest: the CPU/GPU in the diagram belong to the Windows host (../../topology.nix).
  topology.self = {
    parent = "windows-host";
    guestType = "wsl";
    hardware.info = "NixOS-WSL (WSL2)";

    # The club's mesh terminates here (docs/luninet.md). No `network`: a tunnel carries
    # the peer list's prefixes and attaches to no LAN, which the network assertion now
    # allows explicitly instead of by accident.
    interfaces.asluni = {
      virtual = true;
      type = "wireguard";
    };

    # Mirrored networking: the guest's eth0 presents the host's address, so there is
    # no guest-specific address to record and the host's is a 3-hour DHCP lease
    # (../../topology.nix). The link is what the diagram needs.
    interfaces.eth0 = {
      network = "lan";
      virtual = true;
      type = "ethernet";
      gateways = [ "192.168.68.1" ];
    };

    # `details` only, recomputed null-safely for every listener. The extractor reads
    # `l.address or "[::]"`, which falls back only when the attribute is ABSENT --
    # nixpkgs declares it `nullOr str` defaulting to `null`, so a listener that sets
    # no address interpolates null and the whole topology fails to evaluate
    # (`cannot coerce null to a string`, docs/adr/0002). Overriding `details` with
    # `mkForce` stops the extractor's own thunk from being evaluated, so `name`,
    # `icon` and `id` still come from the extractor and only this field is ours.
    services.mosquitto.details = lib.mkForce (
      lib.listToAttrs (
        lib.imap0 (i: l: {
          name = "listen[${toString i}]";
          value.text = "${if l.address == null then "[::]" else l.address}:${toString l.port}";
        }) config.services.mosquitto.listeners
      )
    );
  };

  # --- CI -------------------------------------------------------------------------
  #
  # The gate runs here and nowhere else, because the e2e tier needs `/dev/kvm` and
  # GitHub-hosted runners have none: they would skip the VM tests while reporting
  # green over a smaller gate than a commit runs locally. The workflow that asks for
  # this runner is `.github/workflows/gate.yml`, and its label is `kvm`.
  #
  # The token is asked for rather than written down: a fine-grained PAT with
  # `Administration: read and write` on the repository. `persist` stores the answer as
  # the secret var `token` -- equivalent to `cp $prompts/token $out/token`, so this
  # generator needs no script:
  #
  #   clan vars generate workstation --generator github-runner-token
  #   clan vars generate workstation --generator github-runner-token --regenerate
  #
  # The second form replaces a revoked token. Until a real one is generated the
  # runner starts and fails to register, which is visible in
  # `journalctl -u github-runner-gate` and is the only symptom.
  services.github-runners.gate = {
    # The token is minted by hand (`clan vars generate workstation --generator
    # github-runner-token`), and until it is, its path is clan's `/no-such-path`
    # sentinel (docs/milestone.md). The runner's unconfigure hook then dies on
    # `install: cannot stat '/no-such-path'`, which takes the whole switch to
    # `failed (status 4)` for a reason unrelated to anything that changed. Gate
    # on the sentinel: no service until a token exists, and the first rebuild
    # after minting turns it on.
    enable =
      toString config.clan.core.vars.generators.github-runner-token.files.token.path != "/no-such-path";
    url = "https://github.com/washedupdeveloper/phoenix";
    name = "workstation-gate";
    tokenFile = config.clan.core.vars.generators.github-runner-token.files.token.path;
    extraLabels = [ "kvm" ];
    # One job per registration: the runner exits after a job and systemd starts it
    # again (`Restart = on-success`), so no job inherits another's workspace or state.
    # The store is still shared, which is why the workflow must not run fork code.
    ephemeral = true;
    # The PAT outlives a single registration, so an existing runner of the same name
    # is replaced on start; without it a restart fails against the stale registration
    # it left behind. Nothing is lost: a runner holds no state between jobs.
    replace = true;
  };
}
