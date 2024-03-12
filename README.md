# My NixOS Configurations

My continuously evolving Nix/NixOS configurations.

![Logo / Artwork](phoenix.png)

## Hosts

| Host     | DE  |
|----------|-----|
| Laptop   | Yes |
| WSL      | No  |
| Racknerd | No  |
| RPI (4)  | No  |

## Repository Structure

```yaml
├── flake.nix     # Entry point.
├── hosts         # All of my hosts, directories indicate multiple files e.g hardware cfg.
│   ├── laptop
│   ├── racknerd
│   ├── rpi
│   └── wsl
├── modules       # All of my modules, separated by domain.
│   ├── flake     # Flake modules separated out
│   ├── home      # Home-manager modules
│   └── nixos     # Generic nixos modules, will entail options
└── secrets       # Secrets provided through SOPS.
```

## Usage Instructions

### General

- Generate age key from SSH/GPG/PGP key.
- Generate binary cache key pair. The private key is supplied through sops.
- Rebuild your NixOS with the repository's flake. This requires `flakes` & `nix-command` experimental features enabled:
`sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake .#[HOST]` (replace `[HOST]` with a configuration, provided in `modules/flake/nixosConfigurations`)
*For all future references once the system has been built and it includes the experimental features, omit the NIX_CONFIG environment variable.*

### Custom Images

- Build the Raspberry Pi (4) custom image for flashing an SD card. Utilizing the `package` in the flake: `nix build .#rpi`

## Todo List

- Create more hosts (NAS, mobile, etc.)
- Learn & implement custom modules for infrastructure -> migrate from containers to Nix modules
- Completely remove global "project specific" installs such as language servers, tooling etc.
- Fully setup and integrate K3s Kubernetes with Helm, Helmfile, Helm-secrets, SOPS & CI/CD (Flux/Argo)
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
