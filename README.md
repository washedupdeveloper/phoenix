# My NixOS Configurations

My continuously evolving Nix/NixOS configuration repository

- `flake.nix` - entry point
- `hosts/` - host specific config
- `modules/` - modules e.g flake modules through `flake/`, nixos modules through `nixos/`, default system config through `system.nix` & home-manager modules throuh `home/`
- `secrets/` - secrets provided through SOPS

Current hosts:

- WSL _(no UI)_
- RPI (Raspberry Pi 4) _(no UI)_
- Racknerd (VPS) _(no UI)_

## Usage

1. Generate age key from SSH/GPG/PGP key. [Instructions](https://github.com/Mic92/sops-nix#usage-example)

2. generate binary cache key pair: [Instructions](https://nixos.wiki/wiki/Binary_Cache)
   private key is supplied through sops.

3. Rebuild your NixOS with the repositorys flake.
   **Requires `flakes` & `nix-command` experimental features enabled**:
   `sudo nixos-rebuild switch --flake .#nixos` _(a given host name from hosts/default.nix)_

### IoT

Build the Raspberry Pi (4) custom image for flashing an SD card. Utilizing the `package` in the flake.
`nix build .#rpi-sdcard`

## Todo list

- create more hosts (NAS, mobile, etc.)
- continue the nix journey and explore tooling
- learn & implement custom modules for infrastructure -> migrate from containers to nix modules

## Resources

Running NixOS on WSL: [NixOS WSL Repository](https://github.com/nix-community/NixOS-WSL)

NixOS Searching Packages, Options & Flakes: [Search NixOS](https://search.nixos.org/packages)

Nixos & Home-Manager lookup: [MyNixOS](https://mynixos.com/)

Home Manager lookup: [Search Home Manager Options](https://mipmip.github.io/home-manager-option-search)

NixOS Logo: [NixOS Repository](https://github.com/NixOS/nixos-artwork/blob/master/logo/white.png)

SOPS: [Sops-Nix Repository](https://github.com/Mic92/sops-nix)

Deploy: [Deploy-rs Repository](https://github.com/serokell/deploy-rs)

Flake-parts: [Flake Parts Repository](https://flake.parts/)
