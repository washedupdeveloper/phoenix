{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    sops-nix.url = "github:Mic92/sops-nix";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    deploy-rs.url = "github:serokell/deploy-rs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    disko = {
      url = "github:nix-community/disko/refs/tags/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devshell.url = "github:numtide/devshell";
    # kubeGenerators.url = "github:farcaller/nix-kube-generators";
    # kubeModules.url = "github:farcaller/nix-kube-modules";
    # cake.url = "github:farcaller/cake";
  };

  outputs = {
    self,
    flake-parts,
    ...
  } @ inputs: let
    username = "storm";
    sshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBCMD78tzMBKjffq9l65ho/6SDUrZu2gXeA6EpU5U/l 31986015+washedupdeveloper@users.noreply.github.com";
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devshell.flakeModule
        (import ./modules/flake/deploy.nix {inherit self inputs username;})
        (import ./modules/flake/nixosConfigurations.nix {inherit inputs username sshPubKey;})
      ];
      systems = ["x86_64-linux" "aarch64-linux"];
      perSystem = {
        system,
        pkgs,
        ...
      }: {
        packages = {
          rpi = self.nixosConfigurations.rpi.config.system.build.sdImage;
        };

        devshells.default.packages = with pkgs; [
          nil
          alejandra
        ];
      };
    };
}
