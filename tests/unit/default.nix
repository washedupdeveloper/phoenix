# Unit tests: assertions about the *evaluated* configuration.
#
# These are not VM tests and they do not build anything. Each one reads a value
# out of a machine's evaluated config and compares it with what this repository
# intends, so a change that silently alters the security posture, the topology
# model or a pinned value fails the gate in milliseconds instead of never.
#
# The properties below are the ones this repository has actually got wrong, plus
# the ones AGENTS.md names as a trap that yields a plausible-looking wrong
# result. Anything a build can already see is deliberately absent -- a test that
# restates the build adds a second place to be wrong.
#
# Naming: `lib.runTests` only runs an attribute whose name starts with `test`.
{
  lib,
  machines,
  topology,
  systems,
}:
let
  named = lib.mapAttrsToList (name: cfg: {
    inherit name;
    inherit (cfg) config;
  }) machines;

  # `topology.self` is a nix-topology option, so a machine without the module
  # does not have it at all.
  topologySelfOf = m: m.config.topology.self or null;

  # Every network any machine's `topology.self` puts an interface on.
  referencedNetworks = lib.unique (
    lib.concatMap (
      m:
      let
        self = topologySelfOf m;
      in
      if self == null then
        [ ]
      else
        lib.concatMap (iface: lib.optional (iface ? network) iface.network) (
          lib.attrValues (self.interfaces or { })
        )
    ) named
  );

  definedNetworks = lib.attrNames topology.networks;
  topologyNodes = lib.attrNames topology.nodes;

  # The credential generator SEC-0001 changed. Kept as a lookup rather than a
  # path so a rename fails loudly here instead of reading `null` and passing.
  generatorsOf = m: m.config.clan.core.vars.generators or { };
  credentialGenerators = lib.filterAttrs (name: _: name == "mosquitto-plant-monitor") (
    lib.foldl' (acc: m: acc // generatorsOf m) { } named
  );

  # The generator's script, as text, for the ordering assertion below.
  scriptLines = script: lib.splitString "\n" script;
  lineIndexOf =
    needle: lines:
    lib.findFirst (i: lib.hasInfix needle (lib.elemAt lines i)) null (
      lib.range 0 (lib.length lines - 1)
    );

  sshdSettingsOf = m: m.config.services.openssh.settings or { };
in
{
  # --------------------------------------------------------------------------
  # Security posture. These are the settings the council audits and the
  # reasoning for which lives in the modules' own comments.
  # --------------------------------------------------------------------------
  security = {
    test_sshd_refuses_password_authentication = {
      expr = lib.all (
        m:
        let
          s = sshdSettingsOf m;
        in
        (s.PasswordAuthentication or null) == false && (s.KbdInteractiveAuthentication or null) == false
      ) named;
      expected = true;
    };

    test_sshd_refuses_root_passwords = {
      expr = lib.all (m: (sshdSettingsOf m).PermitRootLogin or null == "prohibit-password") named;
      expected = true;
    };

    # Every account whose password is set must get it from the vars store. A
    # literal `initialPassword` would put a hash in the repository, and a plain
    # `hashedPassword` would put it in the store.
    test_every_password_hash_comes_from_the_vars_store = {
      expr = lib.all (
        m:
        let
          users = m.config.users.users or { };
          withHash = lib.filterAttrs (_: u: u.hashedPasswordFile or null != null) users;
        in
        lib.all (u: lib.hasPrefix "/run/secrets-for-users/vars/" u.hashedPasswordFile) (
          lib.attrValues withHash
        )
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

    # The broker's rule is written per-interface on purpose: mirrored
    # networking shares the host's interfaces, so the bare list would open the
    # port everywhere. See the comment above the rule.
    test_the_broker_port_is_interface_scoped = {
      expr = lib.all (
        m:
        let
          fw = m.config.networking.firewall;
        in
        lib.elem 1883 (fw.interfaces.eth0.allowedTCPPorts or [ ])
        && !(lib.elem 1883 (fw.allowedTCPPorts or [ ]))
      ) named;
      expected = true;
    };

    # Nothing else may join sshd on the bare list without this test being
    # updated, which is the point: the list is the set of ports open on every
    # interface the machine has.
    test_only_sshd_opens_a_bare_port = {
      expr = lib.all (m: (m.config.networking.firewall.allowedTCPPorts or [ ]) == [ 22 ]) named;
      expected = true;
    };
  };

  # --------------------------------------------------------------------------
  # The credential generator. SEC-0001 was a secret in argv; these pin the
  # shape of the fix so it cannot silently regress.
  # --------------------------------------------------------------------------
  generator = {
    test_the_generator_exists = {
      expr = lib.attrNames credentialGenerators;
      expected = [ "mosquitto-plant-monitor" ];
    };

    # `-b` puts the passphrase in argv, where /proc/<pid>/cmdline is
    # world-readable. `-U` hashes a file in place instead.
    test_the_secret_is_never_an_argument = {
      expr = lib.all (
        g:
        let
          s = g.script or "";
        in
        lib.hasInfix "mosquitto_passwd" s && !(lib.hasInfix "-b " s)
      ) (lib.attrValues credentialGenerators);
      expected = true;
    };

    test_the_hash_is_produced_in_place = {
      expr = lib.all (g: lib.hasInfix "mosquitto_passwd -U" (g.script or "")) (
        lib.attrValues credentialGenerators
      );
      expected = true;
    };

    # `umask` has to precede the first write, or the plaintext lands 0644 and
    # mosquitto_passwd warns it is world-readable. This is the ordering bug
    # found while fixing SEC-0001.
    test_umask_precedes_the_first_secret_write = {
      expr = lib.all (
        g:
        let
          lines = scriptLines (g.script or "");
          umaskAt = lineIndexOf "umask" lines;
          secretAt = lineIndexOf "plant-monitor-password" lines;
        in
        umaskAt != null && secretAt != null && umaskAt < secretAt
      ) (lib.attrValues credentialGenerators);
      expected = true;
    };

    test_the_intermediate_plaintext_is_removed = {
      expr = lib.all (g: lib.hasInfix "rm \"$out\"/plant-monitor-passwd" (g.script or "")) (
        lib.attrValues credentialGenerators
      );
      expected = true;
    };
  };

  # --------------------------------------------------------------------------
  # Structural invariants. AGENTS.md calls these the traps: each yields a
  # plausible-looking wrong result rather than an error.
  # --------------------------------------------------------------------------
  structure = {
    test_every_machine_declares_its_guest_relationship = {
      expr = lib.all (m: (topologySelfOf m).parent or null != null) named;
      expected = true;
    };

    test_every_machine_runs_on_a_declared_system = {
      expr = lib.all (m: lib.elem m.config.nixpkgs.hostPlatform.system systems) named;
      expected = true;
    };

    # The topology check catches the class of bug fixed in RD-0003: a machine
    # put on a network the global model does not define renders a dangling
    # node, and nothing else notices.
    test_every_referenced_network_is_defined = {
      expr = lib.subtractLists definedNetworks referencedNetworks;
      expected = [ ];
    };

    test_every_machine_appears_in_the_topology = {
      expr = lib.subtractLists topologyNodes (lib.map (m: m.name) named);
      expected = [ ];
    };
  };

  # --------------------------------------------------------------------------
  # Pinned values. A drift here is silent and changes what the machine is.
  # --------------------------------------------------------------------------
  pins = {
    test_state_version_is_pinned = {
      expr = lib.attrValues (lib.mapAttrs (_: m: m.config.system.stateVersion) machines);
      expected = [ "26.05" ];
    };

    test_every_machine_is_x86_64_linux = {
      expr = lib.unique (lib.map (m: m.config.nixpkgs.hostPlatform.system) named);
      expected = [ "x86_64-linux" ];
    };
  };
}
