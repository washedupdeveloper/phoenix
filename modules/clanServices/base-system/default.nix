{
  _class = "clan.service";
  manifest = {
    name = "base-system";
    description = "Baseline NixOS settings shared by every machine in the clan.";
    categories = [ "System" ];
    readme = ''
      Applies the baseline every machine in the clan should have
    '';
  };

  roles.default = {
    description = "The single role every machine in the clan gets.";

    interface =
      { lib, ... }:
      {
        options = {
          timeZone = lib.mkOption {
            type = lib.types.str;
            default = "Europe/Copenhagen";
            description = "System timezone.";
          };
          locale = lib.mkOption {
            type = lib.types.str;
            default = "en_DK.UTF-8";
            description = "Default system locale.";
          };
          keyMap = lib.mkOption {
            type = lib.types.str;
            default = "dk-latin1";
            description = "Console keymap.";
          };
          editor = lib.mkOption {
            type = lib.types.str;
            default = "nano";
            description = "Default $EDITOR.";
          };
          extraLocale = lib.mkOption {
            type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
            default = {
              LC_ADDRESS = "da_DK.UTF-8";
              LC_IDENTIFICATION = "da_DK.UTF-8";
              LC_MEASUREMENT = "da_DK.UTF-8";
              LC_MONETARY = "da_DK.UTF-8";
              LC_NAME = "da_DK.UTF-8";
              LC_NUMERIC = "da_DK.UTF-8";
              LC_PAPER = "da_DK.UTF-8";
              LC_TELEPHONE = "da_DK.UTF-8";
              LC_TIME = "da_DK.UTF-8";
            };
            description = ''
              Per-category locale overrides (i18n.extraLocaleSettings).
              Set to `null` to just use `locale` for everything.
            '';
          };
        };
      };

    perInstance =
      { settings, ... }:
      {
        nixosModule =
          {
            pkgs,
            lib,
            username ? null,
            ...
          }:
          {
            time.timeZone = lib.mkDefault settings.timeZone;
            console.keyMap = lib.mkDefault settings.keyMap;

            environment = {
              variables.EDITOR = lib.mkDefault settings.editor;
              # nix tooling lives in the devshell; installing it here would put a
              # second copy -- and, via nixd, a second nix -- in every closure.
            };

            programs.fish = {
              enable = true;
              interactiveShellInit = ''
                function fish_user_key_bindings
                  # `ctrl-space` is the only spelling that matches the byte the
                  # terminal sends; `nul` is not a key name. See
                  # docs/shell-integrations.md.
                  bind ctrl-space accept-autosuggestion
                end
              '';
            };

            # fish is the target of every integration in modules/home/shell.nix;
            # without this the login shell stays bash and none of them load.
            users.users = lib.mkIf (username != null) {
              ${username}.shell = pkgs.fish;
            };

            # Host keys belong to clan's `sshd` service, which keeps them in the vars
            # store (ADR-0001 decision 2). Declaring `hostKeys` here concatenates onto
            # clan's list rather than replacing it, leaving an unmanaged second key.
            services.openssh = {
              enable = true;
              settings = {
                PasswordAuthentication = false;
                KbdInteractiveAuthentication = false;
              };
            };

            users.mutableUsers = lib.mkDefault false;
            # Accepted: single-user WSL guest, both accounts clan-managed and
            # vars-backed, SSH key-only, and `nixolotl` is in @wheel, itself a nix
            # trusted-user -- a sudo password would add no boundary. Set to true if a
            # second human ever gets an account here.
            security.sudo.wheelNeedsPassword = lib.mkDefault false;
            security.sudo.execWheelOnly = lib.mkDefault true;

            nix = {
              package = lib.mkDefault pkgs.nixVersions.latest;
              gc = {
                automatic = lib.mkDefault true;
                dates = lib.mkDefault "weekly";
                options = lib.mkDefault "--delete-older-than 7d";
              };

              settings = {
                # clan-core already sets ["nix-command" "flakes"] and a plain list
                # definition concatenates, so this only adds the extra feature.
                # `mkDefault` would lose to clan's definition and silently drop it.
                # Keep in step with the devshell's NIX_CONFIG in flake.nix.
                experimental-features = [ "pipe-operators" ];
                auto-optimise-store = lib.mkDefault true;
                # `accept-flake-config` stays at nix's default (false): accepting a
                # flake's config trusts its substituters and keys, which should not
                # happen silently for every flake evaluated here. Nothing needs it --
                # the caches and keys are set below, except `cache.clan.lol`, which
                # flake.nix declares for other evaluators.
                #
                # `trusted-users` widens nix's default (`root` alone) to @wheel: every
                # wheel account may then set restricted options. Deliberate.
                trusted-users = [
                  "root"
                  "@wheel"
                ];
                substituters = [
                  "https://cache.nixos.org"
                  "https://nix-community.cachix.org/"
                  "https://pre-commit-hooks.cachix.org/"
                  "https://numtide.cachix.org"
                ];
                trusted-public-keys = [
                  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                  "pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc="
                  "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
                ];
              };
            };

            i18n = {
              defaultLocale = lib.mkDefault settings.locale;
              extraLocaleSettings = lib.mkIf (settings.extraLocale != null) (lib.mkDefault settings.extraLocale);
            };

            documentation = lib.mkDefault {
              enable = false;
              nixos.enable = false;
              man.enable = false;
              dev.enable = false;
            };
          };
      };
  };
}
