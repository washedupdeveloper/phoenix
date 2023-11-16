{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs2305.url = "github:nixos/nixpkgs/nixos-23.05";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    sops-nix.url = "github:Mic92/sops-nix";
    home-manager.url = "github:nix-community/home-manager";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    nil.url = "github:oxalica/nil";
    alejandra.url = "github:kamadorueda/alejandra/3.0.0";
  };

  outputs = {self, ...} @ inputs: let
    variables = import ./variables.nix;
  in {
    nixosConfigurations =
      import ./hosts
      {inherit self inputs variables;};
  };
}
