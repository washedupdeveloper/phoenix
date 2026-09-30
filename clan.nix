{ inputs }:
{
  meta = {
    name = "phoenix";
    domain = "lab";
    description = "My ever-changing immutable homelab";
  };

  # Locally-authored clan.service modules. Referenced below with
  # `module.input = "self"` -- module.input defaults to "clan-core", not
  # local, so this must be explicit for anything not shipped by clan-core.
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

  # Docs: https://docs.clan.lol/services/definition
  inventory.instances = {

    # Docs: https://docs.clan.lol/services/official/sshd
    # Generates persistent host keys + certs, grants SSH access to root.
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
            # certificate.searchDomains = [ "example.com" ];
          };
        };
        client = {
          tags = [ "all" ];
          settings = {
            # certificate.searchDomains = [ "example.com" ];
          };
        };
      };
    };

    # Docs: https://docs.clan.lol/services/official/users
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
      roles.default.machines.workstation = { };
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

    hm = {
      module.name = "importer";
      module.input = "clan-core";
      roles.default.machines.workstation = { };
      roles.default.extraModules = [
        ./modules/home/default.nix
        (
          { username, ... }:
          {
            home-manager.users.${username}.imports = [
              ./modules/home/git.nix
              ./modules/home/jj.nix
              ./modules/home/shell.nix
              inputs.hermes-agent.homeManagerModules.default
            ];
          }
        )
        ./modules/hermes.nix
      ];
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
      roles.default.settings.windowsUsername = "storm";
    };

    topology = {
      module.name = "importer";
      module.input = "clan-core";
      roles.default.tags.all = { };
      roles.default.extraModules = [ inputs.nix-topology.nixosModules.default ];
    };

    # mycelium = {
    #   roles.peer.tags = [ "all" ];
    # };

    # Docs: https://docs.clan.lol/services/official/zerotier
    # Requires a controller machine deployed first.
    # zerotier = {
    #   roles.controller.machines.vps-controller = { };
    #   roles.peer.tags.all = { };
    # };

    # Docs: https://docs.clan.lol/services/official/tor
    # tor = {
    #   roles.server.tags.all = { };
    # };
  };
}
