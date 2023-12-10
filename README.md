# My NixOS Configurations

Simple starter-template for my Nix/NixOS configurations

- `flake.nix` - entry point
- `hosts/` - host specific config
- `modules/` - modules e.g default system config, home-manager modules etc.
- `secrets/` - secrets provided through SOPS

Current hosts:

- WSL _(no UI)_
- RPI (Raspberry Pi 4) _(no UI)_

## Usage

1. Generate age key from SSH/GPG/PGP key. [Instructions](https://github.com/Mic92/sops-nix#usage-example)

2. Rebuild your NixOS with the repositorys flake.

- **Requires `flakes` & `nix-command` experimental features enabled**:
  `sudo nixos-rebuild switch --flake .#nixos` _(a given host name from hosts/default.nix)_

### IoT

Build the Raspberry Pi (4) custom image for flashing an SD card
`sudo nix build .#nixosConfigurations.rpi.config.system.build.sdImage`

## Todo list

- create more hosts (VPS, NAS, IoT)

## Resources

Running NixOS on WSL: [NixOS WSL Repository](https://github.com/nix-community/NixOS-WSL)

NixOS Searching Packages, Options & Flakes: [Search NixOS](https://search.nixos.org/packages)

Home Manager lookup: [Search Home Manager Options](https://mipmip.github.io/home-manager-option-search)

NixOS Logo: [NixOS Repository](https://github.com/NixOS/nixos-artwork/blob/master/logo/white.png)

SOPS: [Sops-Nix Repository](https://github.com/Mic92/sops-nix)
