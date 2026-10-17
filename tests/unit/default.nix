# Core unit tests: assertions about the *evaluated* system configuration.
#
# Scope is the system itself -- what it is, what it exposes, and what it must
# never become. Service-specific expectations (a broker's port, a server's
# credentials) do not belong here: they are properties of a module, and they
# move with that module into its own test when it becomes its own module.
#
# These are not VM tests and they build nothing. Each one reads a value out of a
# machine's evaluated config and compares it with what this repository intends,
# so a change that silently alters the system fails the gate in milliseconds.
#
# Naming: `lib.runTests` only runs an attribute whose name starts with `test`.
#
# The `flake` and `home` groups live in their own files: they read the flake's
# per-system wiring and the home-manager configuration rather than a machine's
# system config, and they are merged in at the bottom.
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

  # A clan role is assigned to machines three ways -- `tags = [ "x" ]`,
  # `tags.x = { }`, or `machines.<name> = { }` -- and clan accepts all three.
  # Normalise so a check does not depend on which spelling was used.
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

  machineNames = builtins.attrNames clan.machines;

  # --------------------------------------------------------------------------
  # Ports. The point of this group is the word "only": the set of ports this
  # system declares as reachable is enumerated here, in full, so a new service
  # cannot open one without this list being edited on purpose.
  #
  # `networking.firewall.*` is inert on a WSL guest (nixos-wsl disables the
  # unit), so this is a declaration of intent rather than a filter. The e2e
  # ports test is what checks the running system; this checks the intent, and
  # the two must agree.
  # --------------------------------------------------------------------------
  declaredTcp = lib.unique (
    lib.concatMap (m: m.config.networking.firewall.allowedTCPPorts or [ ]) named
  );
  declaredUdp = lib.unique (
    lib.concatMap (m: m.config.networking.firewall.allowedUDPPorts or [ ]) named
  );
  sshdPorts = lib.unique (lib.concatMap (m: m.config.services.openssh.ports or [ ]) named);

  # --------------------------------------------------------------------------
  # clan deployability helpers
  # --------------------------------------------------------------------------
  deployableMachines = builtins.attrNames (clanInternals.machines.${builtins.head systems} or { });
in
{
  # --------------------------------------------------------------------------
  # What the system is. A drift here is silent and changes the machine.
  # --------------------------------------------------------------------------
  system = {
    test_state_version_is_pinned = {
      expr = lib.unique (lib.map (m: m.config.system.stateVersion) named);
      expected = [ "26.05" ];
    };

    test_host_name_is_declared = {
      expr = lib.unique (lib.map (m: m.config.networking.hostName) named);
      expected = [ "workstation" ];
    };

    test_time_zone_is_declared = {
      expr = lib.unique (lib.map (m: m.config.time.timeZone) named);
      expected = [ "Europe/Copenhagen" ];
    };

    test_locale_and_keymap_are_declared = {
      expr = lib.unique (lib.map (m: "${m.config.i18n.defaultLocale}:${m.config.console.keyMap}") named);
      expected = [ "en_DK.UTF-8:dk-latin1" ];
    };

    test_every_machine_is_x86_64_linux = {
      expr = lib.unique (lib.map (m: m.config.nixpkgs.hostPlatform.system) named);
      expected = [ "x86_64-linux" ];
    };

    # The flake builds for exactly the systems it declares.
    test_every_machine_runs_on_a_declared_system = {
      expr = lib.all (m: lib.elem m.config.nixpkgs.hostPlatform.system systems) named;
      expected = true;
    };
  };

  # --------------------------------------------------------------------------
  # What the system exposes. See the note above the `ports` group: this is the
  # "and nothing else" half of the suite.
  # --------------------------------------------------------------------------
  ports = {
    test_only_the_declared_tcp_ports_are_reachable = {
      expr = declaredTcp;
      # 22 -- sshd. Declared by `services.openssh.openFirewall`.
      expected = [ 22 ];
    };

    test_only_the_declared_udp_ports_are_reachable = {
      expr = declaredUdp;
      # 5353 -- mDNS, declared by clan-core's own networking module for its
      # local discovery. Not this repository's doing, and not something to
      # remove without checking clan's networking guide first.
      expected = [ 5353 ];
    };

    # The firewall entry and the listener must not drift apart: a port declared
    # open that nothing listens on is a stale rule, and a listener with no rule
    # is an accident waiting for the firewall to be switched on.
    test_sshd_listens_on_exactly_its_declared_port = {
      expr = sshdPorts;
      expected = [ 22 ];
    };

    # Nothing in this repository may open a bare port beyond sshd. A service
    # that needs one gets an interface-scoped rule instead.
    test_the_only_bare_tcp_port_is_sshd = {
      expr = lib.subtractLists sshdPorts declaredTcp;
      expected = [ ];
    };
  };

  # --------------------------------------------------------------------------
  # Security posture. These are the settings a change can quietly relax.
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

    # Every account whose password is set must get it from the vars store. A
    # literal `initialPassword` would put a hash in the repository, and a plain
    # `hashedPassword` would put it in the store.
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

    # No account may be created without a password and without being locked:
    # an empty password is a login, not a missing one.
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
          # `null` means no password set (fine if the account is locked or has
          # a file); an empty string is a password that is the empty string.
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

    # No unfree or known-insecure package may be admitted without this list
    # being edited.
    test_no_insecure_packages_are_permitted = {
      expr = lib.all (m: (m.config.nixpkgs.config.permittedInsecurePackages or [ ]) == [ ]) named;
      expected = true;
    };
  };

  # --------------------------------------------------------------------------
  # Integrity. nixpkgs ships ~1500 assertions and a warning channel; both are
  # free sanity checks that this repository's own changes can trip.
  # --------------------------------------------------------------------------
  integrity = {
    # A failed assertion is nixpkgs saying the configuration is internally
    # inconsistent. The build would fail too, but the message here is the
    # assertion's own.
    test_no_nixpkgs_assertion_fails = {
      expr = lib.concatMap (
        m:
        map (a: "${m.name}: ${a.message}") (builtins.filter (a: !a.assertion) (m.config.assertions or [ ]))
      ) named;
      expected = [ ];
    };

    # Warnings do not fail a build, so nothing else in the gate would catch
    # them. Deprecations and misconfigurations surface here.
    test_no_nixpkgs_warning_is_emitted = {
      expr = lib.concatMap (m: map (w: "${m.name}: ${w}") (m.config.warnings or [ ])) named;
      expected = [ ];
    };

    # The firewall must be asked for, even though nixos-wsl disables the unit.
    # Turning it off entirely would make the declaration above meaningless.
    test_the_firewall_is_declared_on = {
      expr = lib.all (m: m.config.networking.firewall.enable == true) named;
      expected = true;
    };
  };

  # --------------------------------------------------------------------------
  # Structural invariants. AGENTS.md calls these the traps: each yields a
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
              lib.concatMap (i: lib.optional (i ? network) i.network) (lib.attrValues (self.interfaces or { }))
          ) named
        )
      );
      expected = [ ];
    };

    test_every_machine_appears_in_the_topology = {
      expr = lib.subtractLists (lib.attrNames topology.nodes) (lib.map (m: m.name) named);
      expected = [ ];
    };
  };

  # --------------------------------------------------------------------------
  # clan deployability. What `clan machines update` needs to be true before it
  # can deploy anything: the machine is a clan machine, it builds as one, and
  # every service in the inventory is actually assigned to it.
  # --------------------------------------------------------------------------
  clan = {
    # The artifact `clan machines build` produces. If clan cannot see the
    # machine, there is nothing to deploy.
    test_every_machine_is_a_clan_machine_with_a_build_artifact = {
      expr = lib.subtractLists deployableMachines machineNames;
      expected = [ ];
    };

    # AGENTS.md's trap: a null input resolves to clan-core, so a local service
    # silently loads the wrong module. Every instance must name its source.
    test_every_instance_names_its_module_source = {
      expr = lib.filter (r: r.input == null) roles;
      expected = [ ];
    };

    # A local (`self`) instance must name a module this repository defines;
    # otherwise clan resolves it to clan-core and fails at build time.
    test_every_self_instance_names_a_local_module = {
      expr = lib.filter (
        r: r.input == "self" && !(lib.elem r.module (builtins.attrNames clan.modules))
      ) roles;
      expected = [ ];
    };

    # A role assigned to nothing never applies, and nothing says so. Each role
    # must be reachable by tag or by machine name.
    test_every_role_is_assigned_to_something = {
      expr = lib.filter (r: r.tags == [ ] && r.machines == [ ]) roles;
      expected = [ ];
    };

    # A role tagged with a tag no machine carries is the same silent failure
    # spelled differently.
    test_every_role_tag_is_carried_by_a_machine = {
      expr = lib.unique (lib.concatMap (r: lib.subtractLists machineTags r.tags) roles);
      expected = [ ];
    };

    # A role naming a machine that does not exist is a typo that would deploy
    # nothing.
    test_every_role_machine_exists = {
      expr = lib.unique (lib.concatMap (r: lib.subtractLists machineNames r.machines) roles);
      expected = [ ];
    };

    # Every declared machine must be in the inventory, or `clan machines
    # update` will not know where to reach it.
    test_every_machine_is_in_the_inventory = {
      expr = lib.subtractLists (builtins.attrNames clan.inventory.machines) machineNames;
      expected = [ ];
    };

    # ...and every inventory machine must be tagged, or no role can target it.
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
