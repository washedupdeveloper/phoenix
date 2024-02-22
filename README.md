# My NixOS Configurations

My continuously evolving Nix/NixOS configurations.

[Logo / Artwork](phoenix.png)

## Repository Structure

- `flake.nix`: Entry point
- `hosts/`: Host-specific configurations
- `modules/`: Modules (Flake modules through `flake/`, NixOS modules through `nixos/`, Home-Manager modules through `home/`)
- `secrets/`: Secrets provided through SOPS

## Hosts

| Host      | UI  |
|-----------|-----|
| Laptop    | Yes |
| WSL       | No  |
| Racknerd  | No  |
| RPI (4)   | No  |

## Usage Instructions

### General

- Generate age key from SSH/GPG/PGP key. Instructions
- Generate binary cache key pair. Instructions. The private key is supplied through sops.
- Rebuild your NixOS with the repository's flake. This requires `flakes` & `nix-command` experimental features enabled: `sudo nixos-rebuild switch --flake .#[HOST]` (replace `[HOST]` with a given host name from hosts)

### Custom Images

- Build the Raspberry Pi (4) custom image for flashing an SD card. Utilizing the `package` in the flake: `nix build .#rpi`
- Build the Nixos-Anywhere custom image for building a base image to use Disko and format the disks of a host. Utilizing the `package` in the flake: `nix build .#nixosAnywhere`

## Todo List

- Create more hosts (NAS, mobile, etc.)
- Learn & implement custom modules for infrastructure -> migrate from containers to Nix modules
- Completely remove global "project specific" installs such as language servers, tooling etc.
- Fully setup and integrate K3s Kubernetes with Helm, Helmfile, Helm-secrets, SOPS & ArgoCD
- Continue the Nix journey and explore tooling

## Resources

Running NixOS on WSL: [NixOS WSL Repository](https://github.com/nix-community/NixOS-WSL)

NixOS Searching Packages, Options & Flakes: [Search NixOS](https://search.nixos.org/packages)

Nixos & Home-Manager lookup: [MyNixOS](https://mynixos.com/)

Home Manager lookup: [Search Home Manager Options](https://mipmip.github.io/home-manager-option-search)

SOPS: [Sops-Nix Repository](https://github.com/Mic92/sops-nix)

Deploy: [Deploy-rs Repository](https://github.com/serokell/deploy-rs)

Disko: [Disko Repository](https://github.com/nix-community/disko)

Flake-parts: [Flake Parts Repository](https://flake.parts/)

NixOS Logo: [NixOS Repository](https://github.com/NixOS/nixos-artwork/blob/master/logo/white.png)
