# My NixOS Configurations

Simple starter-template for my Nix/NixOS configurations

- `flake.nix` - entry point
- `home/` - home-manager config, programs etc.
- `hosts/` - host specific config
- `modules/` - shared modules e.g default system config.

Current hosts:

- WSL _(no UI)_

## Usage

1. Modify variables.nix file

2. Generate age key from SSH/GPG/PGP key. [Instructions](https://github.com/Mic92/sops-nix#usage-example)

3. Rebuild your NixOS with the repositorys flake.
   - **Requires `flakes` & `nix-command` experimental features enabled**:
     `sudo nixos-rebuild switch --flake .#nixos` _(a given host name from hosts/default.nix)_

## Todo list

- create more hosts (VPS, NAS, IoT)

## Resources

Running NixOS on WSL: [NixOS WSL Repository](https://github.com/nix-community/NixOS-WSL)

NixOS Searching Packages, Options & Flakes: [Search NixOS](https://search.nixos.org/packages)

Home Manager lookup: [Search Home Manager Options](https://mipmip.github.io/home-manager-option-search)

NixOS Logo: [Github Repository](https://github.com/NixOS/nixos-artwork/blob/master/logo/white.png)
