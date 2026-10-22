# Assertions about the *evaluated* system config: no build, no VM, milliseconds.
# Scope is the system itself; a service's own expectations belong with its module.
#
# `lib.runTests` only runs attributes whose name starts with `test`.
{
  lib,
  machines,
  systems,
  system,
  topology,
  clan,
  clanInternals,
  flake,
  perSystem,
}:
let
  named = lib.mapAttrsToList (name: cfg: {
    inherit name;
    inherit (cfg) config;
  }) machines;

  # --------------------------------------------------------------------------
  # Helpers
  # --------------------------------------------------------------------------

  # clan accepts three tag spellings -- `[ "x" ]`, `tags.x = { }`,
  # `machines.<name> = { }` -- so normalise before checking.
  tagNames =
    tags:
    if builtins.isList tags then
      tags
    else if builtins.isAttrs tags then
      builtins.attrNames tags
    else
      [ ];

  # Every role of every instance, flattened.
  roles = lib.concatMap (
    instanceName:
    let
      instance = clan.inventory.instances.${instanceName};
    in
    lib.mapAttrsToList (roleName: role: {
      inherit instanceName roleName;
      tags = tagNames (role.tags or [ ]);
      machines = builtins.attrNames (role.machines or { });
      module = instance.module.name;
      input = instance.module.input or null;
    }) (instance.roles or { })
  ) (builtins.attrNames clan.inventory.instances);

  # The tags any machine actually carries.
  machineTags = lib.unique (
    lib.concatMap (m: tagNames (m.tags or [ ])) (builtins.attrValues clan.inventory.machines)
  );

  # The machines that EXIST -- one `machines/<name>/configuration.nix` each -- not the
  # ones `clan.nix` lists module args for: `username` moved to `clan.specialArgs`, so a
  # machine is no longer listed there at all. Every inventory assertion compares this
  # against what `clan.nix` declares, which is what keeps them falsifiable: a new
  # machine joins `machines/` first and the declaration is a separate step it can be
  # missing from.
  machineNames = builtins.attrNames machines;

  # --------------------------------------------------------------------------
  # Ports. The word "only" is the point: the reachable set is enumerated in full,
  # so a service cannot open a port without this list being edited.
  #
  # `networking.firewall.*` is inert on a WSL guest, so this is a declaration of
  # intent; e2e/ports asserts the running system for its OWN node — a minimal clan
  # built from `base-system` alone — so it does not see the inventory-driven services
  # (mycelium) that a fleet machine carries. The two agree about everything the e2e
  # fixture applies; they are no longer the same set.
  # --------------------------------------------------------------------------
  declaredTcp = lib.unique (
    lib.concatMap (m: m.config.networking.firewall.allowedTCPPorts or [ ]) named
  );
  declaredUdp = lib.unique (
    lib.concatMap (m: m.config.networking.firewall.allowedUDPPorts or [ ]) named
  );
  sshdPorts = lib.unique (lib.concatMap (m: m.config.services.openssh.ports or [ ]) named);

  # nixpkgs' mycelium module writes these straight into `networking.firewall` rather
  # than exposing them as options, so they are restated here — the alternative is an
  # assertion that cannot see the port at all. 9651 is the peering port, 9650 UDP
  # discovery; the same numbers are commented on the tests that use them.
  myceliumTcpPorts = [ 9651 ];

  # --------------------------------------------------------------------------
  # clan deployability helpers
  # --------------------------------------------------------------------------
  deployableMachines = builtins.attrNames (clanInternals.machines.${builtins.head systems} or { });

  # Every machine that enables mosquitto, with the service nix-topology renders for
  # it -- read from the evaluated topology so the assertion sees what the diagram
  # sees, not what the machine config says.
  mosquitto = lib.concatMap (
    m:
    lib.optional (m.config.services.mosquitto.enable or false) {
      inherit (m) name;
      listeners = m.config.services.mosquitto.listeners or [ ];
      rendered = m.config.topology.nodes.${m.name}.services.mosquitto or { };
    }
  ) named;
in
{
  # --------------------------------------------------------------------------
  # What the system is. Drift here is silent and changes the machine.
  # --------------------------------------------------------------------------
  system = {
    # Fleet-shaped, not one-machine-shaped: reads as "every machine does X", so a
    # second machine does not fail the gate for existing.
    test_state_version_is_pinned = {
      expr = lib.all (m: m.config.system.stateVersion == "26.05") named;
      expected = true;
    };

    # A hostName that disagrees with the clan machine name means sshing to the
    # wrong address.
    test_host_name_matches_the_machine_name = {
      expr = lib.all (m: m.config.networking.hostName == m.name) named;
      expected = true;
    };

    test_time_zone_is_declared = {
      expr = lib.all (m: m.config.time.timeZone == "Europe/Copenhagen") named;
      expected = true;
    };

    test_locale_and_keymap_are_declared = {
      expr = lib.all (
        m: "${m.config.i18n.defaultLocale}:${m.config.console.keyMap}" == "en_DK.UTF-8:dk-latin1"
      ) named;
      expected = true;
    };

    # An undeclared architecture cannot be built by `nix flake check` or deployed
    # by `clan machines update` (docs/adding-a-machine.md).
    test_every_machine_runs_on_a_declared_system = {
      expr = lib.all (m: lib.elem m.config.nixpkgs.hostPlatform.system systems) named;
      expected = true;
    };

    # The account comes from the `all` tag, so a new machine gets it by
    # construction. `isNormalUser`, not `users.users ? nixolotl`: base-system sets
    # `.shell`, so that attribute exists without the account, and a mutation proved
    # the weaker spelling vacuous.
    test_every_machine_carries_a_normal_user = {
      expr = lib.all (m: (m.config.users.users.nixolotl or { }).isNormalUser or false) named;
      expected = true;
    };
  };

  # --------------------------------------------------------------------------
  # What the system exposes: the "and nothing else" half of the suite.
  # --------------------------------------------------------------------------
  ports = {
    test_only_the_declared_tcp_ports_are_reachable = {
      expr = declaredTcp;
      # 22   -- sshd, via `services.openssh.openFirewall`.
      # 9651 -- mycelium's peering port, opened by `services.mycelium.openFirewall`,
      #         which clan-core's instance leaves at its default.
      expected = [
        22
        9651
      ];
    };

    test_only_the_declared_udp_ports_are_reachable = {
      expr = declaredUdp;
      # 5353      -- mDNS, from clan-core's own networking module, not this repo.
      # 9650/9651 -- mycelium: discovery and its QUIC listener.
      expected = [
        5353
        9650
        9651
      ];
    };

    # A declared port with no listener is a stale rule; a listener with no rule is
    # an accident waiting for the firewall to be switched on.
    test_sshd_listens_on_exactly_its_declared_port = {
      expr = sshdPorts;
      expected = [ 22 ];
    };

    # A bare port -- open on every interface -- is a decision worth failing over, not a
    # default. sshd accepts key-authenticated logins from anywhere, and mycelium's 9651
    # is where peers dial in from outside the LAN; both are `openFirewall` on a service
    # whose listener cannot be scoped to one interface. Anything else must scope its
    # rule (`networking.firewall.interfaces.<if>`) or be added here with its reason.
    test_the_only_bare_tcp_ports_have_a_reason = {
      expr = lib.subtractLists (sshdPorts ++ myceliumTcpPorts) declaredTcp;
      expected = [ ];
    };
  };

  # --------------------------------------------------------------------------
  # Security posture: the settings a change can quietly relax.
  # --------------------------------------------------------------------------
  security = {
    test_sshd_refuses_password_authentication = {
      expr = lib.all (
        m:
        let
          s = m.config.services.openssh.settings or { };
        in
        (s.PasswordAuthentication or null) == false && (s.KbdInteractiveAuthentication or null) == false
      ) named;
      expected = true;
    };

    test_sshd_refuses_root_passwords = {
      expr = lib.all (
        m: (m.config.services.openssh.settings or { }).PermitRootLogin or null == "prohibit-password"
      ) named;
      expected = true;
    };

    # A literal `initialPassword` would put a hash in the repo, a plain
    # `hashedPassword` in the store.
    test_every_password_hash_comes_from_the_vars_store = {
      expr = lib.all (
        m:
        let
          withHash = lib.filterAttrs (_: u: u.hashedPasswordFile or null != null) (
            m.config.users.users or { }
          );
        in
        lib.all (u: lib.hasPrefix "/run/secrets-for-users/vars/" u.hashedPasswordFile) (
          lib.attrValues withHash
        )
      ) named;
      expected = true;
    };

    # An empty password is a login, not a missing one.
    test_no_account_has_an_empty_password = {
      expr = lib.all (
        m:
        let
          users = m.config.users.users or { };
        in
        lib.all (
          u:
          let
            pw = u.hashedPassword or null;
          in
          # `null` means no password set (fine if locked or file-backed).
          pw == null || pw != ""
        ) (lib.attrValues users)
      ) named;
      expected = true;
    };

    test_users_are_not_mutable = {
      expr = lib.all (m: m.config.users.mutableUsers or null == false) named;
      expected = true;
    };

    test_sudo_needs_no_password_from_wheel = {
      expr = lib.all (m: m.config.security.sudo.wheelNeedsPassword or null == false) named;
      expected = true;
    };

    test_sudo_is_restricted_to_wheel = {
      expr = lib.all (m: m.config.security.sudo.execWheelOnly or null == true) named;
      expected = true;
    };

    # Admitting one requires editing this list on purpose.
    test_no_insecure_packages_are_permitted = {
      expr = lib.all (m: (m.config.nixpkgs.config.permittedInsecurePackages or [ ]) == [ ]) named;
      expected = true;
    };
  };

  # --------------------------------------------------------------------------
  # Integrity. nixpkgs ships ~1500 assertions and a warning channel; both are
  # free checks that this repository's changes can trip.
  # --------------------------------------------------------------------------
  integrity = {
    # A failed assertion means nixpkgs considers the config inconsistent. The
    # build would fail too, but this message is the assertion's own.
    test_no_nixpkgs_assertion_fails = {
      expr = lib.concatMap (
        m:
        map (a: "${m.name}: ${a.message}") (builtins.filter (a: !a.assertion) (m.config.assertions or [ ]))
      ) named;
      expected = [ ];
    };

    # Warnings do not fail a build, so nothing else in the gate would catch them.
    test_no_nixpkgs_warning_is_emitted = {
      expr = lib.concatMap (m: map (w: "${m.name}: ${w}") (m.config.warnings or [ ])) named;
      expected = [ ];
    };

    # Must be asked for even though nixos-wsl disables the unit, or the port
    # declarations above mean nothing.
    test_the_firewall_is_declared_on = {
      expr = lib.all (m: m.config.networking.firewall.enable == true) named;
      expected = true;
    };
  };

  # --------------------------------------------------------------------------
  # Structural invariants: the traps AGENTS.md names -- each yields a
  # plausible-looking wrong result rather than an error.
  # --------------------------------------------------------------------------
  structure = {
    test_every_machine_declares_its_guest_relationship = {
      expr = lib.all (m: (m.config.topology.self or { }).parent or null != null) named;
      expected = true;
    };

    test_every_referenced_network_is_defined = {
      expr = lib.subtractLists (lib.attrNames topology.networks) (
        lib.unique (
          lib.concatMap (
            m:
            let
              self = m.config.topology.self or null;
            in
            if self == null then
              [ ]
            else
              # `i ? network` is too strict a test: nix-topology derives an interface for every
              # interface a machine has, and a tunnel (`asluni`) attaches to no LAN, so a
              # present-but-null `network` describes the tunnel rather than dangling. What
              # this catches is an interface naming a network that `topology.nix` never
              # defines.
              lib.filter (n: n != null) (lib.map (i: i.network or null) (lib.attrValues (self.interfaces or { })))
          ) named
        )
      );
      expected = [ ];
    };

    test_every_machine_appears_in_the_topology = {
      expr = lib.subtractLists (lib.attrNames topology.nodes) (lib.map (m: m.name) named);
      expected = [ ];
    };

    # nix-topology's mosquitto extractor interpolates `l.address`, which nixpkgs
    # declares `nullOr str` defaulting to null, so a listener that sets no address
    # kills the whole topology evaluation ("cannot coerce null to a string", measured).
    # The machine overrides `details` with a null-safe derivation of the *same* shape.
    #
    # The expected value is the contract, not a copy of the implementation: a listener
    # with no address listens on all interfaces, which the diagram is meant to show as
    # `[::]`. `toString null` would give `:1883`, and the first workaround hardcoded
    # `1883` -- both fail here, which is why this is not merely an eval guard.
    test_mosquitto_listeners_render_without_a_null_address = {
      expr = lib.concatMap (
        s:
        let
          expected = map (
            l: "${if l.address == null then "[::]" else l.address}:${toString l.port}"
          ) s.listeners;
          actual = map (d: d.text) (lib.attrValues (s.rendered.details or { }));
        in
        lib.optional (actual != expected) {
          inherit (s) name;
          inherit actual expected;
        }
      ) mosquitto;
      expected = [ ];
    };
  };

  # --------------------------------------------------------------------------
  # clan deployability: what `clan machines update` needs before it can deploy.
  # --------------------------------------------------------------------------
  clan = {
    # If clan cannot see the machine, there is no build artifact to deploy.
    test_every_machine_is_a_clan_machine_with_a_build_artifact = {
      expr = lib.subtractLists deployableMachines machineNames;
      expected = [ ];
    };

    # A null input resolves to clan-core, so a local service silently loads the
    # wrong module.
    test_every_instance_names_its_module_source = {
      expr = lib.filter (r: r.input == null) roles;
      expected = [ ];
    };

    # A `self` instance must name a module this repo defines, or clan resolves it
    # to clan-core and fails at build time.
    test_every_self_instance_names_a_local_module = {
      expr = lib.filter (
        r: r.input == "self" && !(lib.elem r.module (builtins.attrNames clan.modules))
      ) roles;
      expected = [ ];
    };

    # A role assigned to nothing never applies, and nothing says so.
    test_every_role_is_assigned_to_something = {
      expr = lib.filter (r: r.tags == [ ] && r.machines == [ ]) roles;
      expected = [ ];
    };

    # A tag no machine carries is the same silent failure, spelled differently.
    test_every_role_tag_is_carried_by_a_machine = {
      expr = lib.unique (lib.concatMap (r: lib.subtractLists machineTags r.tags) roles);
      expected = [ ];
    };

    # A machine that does not exist is a typo that would deploy nothing.
    test_every_role_machine_exists = {
      expr = lib.unique (lib.concatMap (r: lib.subtractLists machineNames r.machines) roles);
      expected = [ ];
    };

    # An undeclared machine leaves `clan machines update` without a target.
    test_every_machine_is_in_the_inventory = {
      expr = lib.subtractLists (builtins.attrNames clan.inventory.machines) machineNames;
      expected = [ ];
    };

    # An untagged inventory machine cannot be targeted by any role.
    test_every_inventory_machine_carries_a_tag = {
      expr = lib.filter (m: tagNames (m.tags or [ ]) == [ ]) (lib.attrValues clan.inventory.machines);
      expected = [ ];
    };
  };
}
// import ./flake.nix {
  inherit
    lib
    machines
    systems
    system
    clan
    clanInternals
    flake
    perSystem
    ;
}
// import ./home.nix { inherit lib machines; }
