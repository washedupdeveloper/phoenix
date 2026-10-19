{ inputs }:
{
  meta = {
    name = "phoenix";
    domain = "lab";
    description = "My ever-changing immutable homelab";
  };

  # Locally-authored modules. `module.input = "self"` is required: a null input
  # resolves to clan-core, not to local modules.
  modules."base-system" = ./modules/clanServices/base-system;
  modules."wsl" = ./modules/clanServices/wsl;

  machines = {
    workstation = {
      _module.args.username = "nixolotl";
    };
  };

  inventory.machines = {
    workstation = {
      tags = [
        "all"
        "workstation"
        "wsl"
      ];
    };
  };

  # Docs: https://clan.lol/docs/26.05/services/definition
  inventory.instances = {
    # Docs: https://clan.lol/docs/26.05/services/official/sshd
    sshd-with-certs = {
      module.name = "sshd";
      module.input = "clan-core";
      roles = {
        server = {
          tags = [ "all" ];
          settings = {
            authorizedKeys = {
              "admin-machine-1" =
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBCMD78tzMBKjffq9l65ho/6SDUrZu2gXeA6EpU5U/l 31986015+washedupdeveloper@users.noreply.github.com";
              "nixolotl" =
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhTgCNuk6WYCrN0Sl0ViGe7cpPofT2ECwUYQ0uQ5zLm nixolotl@proton.me";
            };
          };
        };
        client = {
          tags = [ "all" ];
          settings = { };
        };
      };
    };

    # Docs: https://clan.lol/docs/26.05/services/official/users
    user-root = {
      module.name = "users";
      module.input = "clan-core";
      roles.default.tags.all = { };
      roles.default.settings = {
        user = "root";
        prompt = true;
      };
    };

    user-nixolotl = {
      module.name = "users";
      module.input = "clan-core";
      # Tag-driven: a machine tagged `all` gets the account automatically, so it
      # cannot be added everywhere else and still have no login. Asserted in
      # tests/unit/default.nix.
      roles.default.tags.all = { };
      roles.default.settings = {
        user = "nixolotl";
        groups = [
          "wheel"
          "networkmanager"
          "video"
          "input"
          "dialout"
        ];
        prompt = true;
      };
    };

    # Spelled out because instance names appear in `clan vars` paths and deploy
    # output. Tag-driven so no machine is left without dotfiles or a git identity.
    home-manager = {
      module.name = "importer";
      module.input = "clan-core";
      roles.default.tags.all = { };
      roles.default.extraModules = [ ./modules/home/default.nix ];
    };

    base-system = {
      module.name = "base-system";
      module.input = "self";
      roles.default.tags.all = { };
    };

    wsl = {
      module.name = "wsl";
      module.input = "self";
      roles.default.tags.wsl = { };
    };

    topology = {
      module.name = "importer";
      module.input = "clan-core";
      roles.default.tags.all = { };
      roles.default.extraModules = [ inputs.nix-topology.nixosModules.default ];
    };

    # Parked: not deployed yet.
    # mycelium = {
    #   roles.peer.tags = [ "all" ];
    # };

    # Docs: https://clan.lol/docs/26.05/services/official/zerotier
    # Requires a controller machine deployed first.
    # zerotier = {
    #   roles.controller.machines.vps-controller = { };
    #   roles.peer.tags.all = { };
    # };

    # Docs: https://clan.lol/docs/26.05/services/official/tor
    # Parked: not deployed yet.
    # tor = {
    #   roles.server.tags.all = { };
    # };
  };
}
