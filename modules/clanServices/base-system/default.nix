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
              # The nix tooling (nixd, deadnix, statix, nixfmt,
              # nix-output-monitor) lives in the flake's devshell, and direnv
              # comes from home-manager's `programs.direnv`. Installing them
              # here as well put a second copy -- and, via nixd, a second nix --
              # into every machine's system closure.
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

            # fish is the shell every integration in modules/home/shell.nix
            # targets; without this the login shell stays bash, where none of
            # them -- the direnv hook included -- is installed. See
            # docs/shell-integrations.md.
            users.users = lib.mkIf (username != null) {
              ${username}.shell = pkgs.fish;
            };

            # Host keys belong to clan's `sshd` service -- the `sshd-with-certs`
            # instance in clan.nix -- which keeps them in the vars store. See
            # ADR-0001 decision 2. Declaring `hostKeys` here as well does not
            # override clan's list, it concatenates onto it, leaving the machine
            # serving a second, unmanaged key that no `clan vars` run can
            # reproduce.
            services.openssh = {
              enable = true;
              settings = {
                PasswordAuthentication = false;
                KbdInteractiveAuthentication = false;
              };
            };

            users.mutableUsers = lib.mkDefault false;
            # Accepted risk, recorded rather than left implicit: this is a
            # single-user WSL guest. Both of its accounts are clan-managed and
            # vars-backed -- `nixolotl` and `root` -- and SSH is key-only:
            # PasswordAuthentication and KbdInteractiveAuthentication are both
            # off above. `nixolotl` is in `@wheel`, which is also a nix
            # trusted-user. A sudo password would not add a boundary nothing
            # else crosses. Flip this to `true` if the machine ever gains a
            # second human user.
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
                # clan-core already sets ["nix-command" "flakes"], and a plain
                # list definition concatenates onto it -- which is why this
                # contributes only the extra feature rather than repeating the
                # two. `lib.mkDefault` here would lose to clan's normal-priority
                # definition and silently drop `pipe-operators`. Must stay in
                # step with the devshell's NIX_CONFIG in flake.nix; see
                # docs/experimental-features.md.
                experimental-features = [ "pipe-operators" ];
                auto-optimise-store = lib.mkDefault true;
                # `accept-flake-config` is deliberately left at nix's default
                # (`false`): accepting a flake's config means trusting its
                # substituters and its public keys, and that should not happen
                # silently for every flake this machine ever evaluates. Nothing
                # here needs it -- the caches, keys and `pipe-operators` that
                # flake.nix's `nixConfig` asks for are set below at system level,
                # except `cache.clan.lol`, which flake.nix declares for other
                # evaluators and this machine does not substitute from.
                #
                # nix's default is `root` alone; `@wheel` is added here
                # deliberately, and that is a widening: every @wheel account may
                # then set restricted options. Kept as a deliberate choice --
                # narrow it to the default if that is not wanted. The explicit
                # `root` duplicates the default, harmlessly.
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
