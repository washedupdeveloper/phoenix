{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs2305.url = "github:nixos/nixpkgs/nixos-23.05";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nil.url = "github:oxalica/nil";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    home-manager.url = "github:nix-community/home-manager/release-23.05";
  };

  outputs = { self, ... } @ inputs:
  let variables = import (if builtins.pathExists ./variables.nix then ./variables.nix else ./example.variables.nix);
  in {
    nixosConfigurations = import ./hosts
      { inherit self inputs variables; }
    ;
  };
}
