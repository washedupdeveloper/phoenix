# A binary cache for this machine's own store.
#
# harmonia serves what is already in /nix/store and signs the narinfo it generates with
# `signKeyPaths`, so one key covers everything this machine serves -- paths it built and
# paths it substituted. That is why no `secret-key-files` appears here: the daemon does not
# have to sign at build time when the server signs at serve time, and a single key is a
# simpler thing to trust than two.
#
# Policy lives in this module; the site supplies one fact (`bindAddress`) and the public
# half of the key (`publicKey`). The URL, the listener and the substituter entry derive
# from those, so a second consumer costs nothing and the address is written down once.
{ config, lib, ... }:
let
  cfg = config.services.binary-cache;

  # Materialised at activation. Until it is, its path is clan's sentinel and the cache
  # stays off -- the same shape as the ci-runner module, so a rebuild never fails on a key
  # that has not been set yet.
  key = config.clan.core.vars.generators.binary-cache-key.files.key;
  haveKey = toString key.path != "/no-such-path";
in
{
  options.services.binary-cache = {
    enable = lib.mkEnableOption "a local binary cache serving this machine's own store";

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address the cache listens on. The default is loopback: one machine, nothing
        exposed, and no firewall rule to remember. A site that wants peers to share the
        cache points this at its mesh address and `url` follows -- the tunnel already
        encrypts it, so plain HTTP stays defensible.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
    };

    publicKey = lib.mkOption {
      type = lib.types.str;
      example = "phoenix-cache-1:AAAA…";
      description = ''
        The public half of the signing key, in Nix's `name:base64` form. Required rather
        than defaulted: a cache whose key nobody names is a cache nobody can trust, and
        that failure would surface as "not signed" at substitution time instead of here.
      '';
    };

    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "http://${cfg.bindAddress}:${toString cfg.port}";
      description = "The one place clients read the cache's address from.";
    };
  };

  config = lib.mkIf cfg.enable {
    clan.core.vars.generators.binary-cache-key = {
      prompts.key = {
        description = "nix-store secret key for the local binary cache (phoenix-cache-1:…)";
        type = "hidden";
        persist = true;
      };

      files.key.restartUnits = [ "harmonia.service" ];
    };

    # `extra-` because `substituters` replaces the list and whichever module assigns last
    # wins. These append, so this composes with cache.nixos.org and with any later cache.
    nix.settings.extra-substituters = [ cfg.url ];
    nix.settings.extra-trusted-public-keys = [ cfg.publicKey ];

    # `services.harmonia.cache.*`, not `services.harmonia.*`: this nixpkgs renamed the
    # latter, and the repo's own integrity check fails on any evaluation warning.
    services.harmonia.cache = lib.mkIf haveKey {
      enable = true;

      settings = {
        bind = "${cfg.bindAddress}:${toString cfg.port}";
        # Before cache.nixos.org's 40: this cache is on the same machine, so it is the
        # cheaper answer whenever it has the path.
        priority = 30;
      };

      # The key reaches harmonia as a systemd credential, not as a readable file in the
      # unit's namespace; the module mounts it and points SIGN_KEY_PATHS at it.
      signKeyPaths = [ key.path ];
    };
  };
}
