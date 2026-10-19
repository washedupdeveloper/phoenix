# Shell integrations

Why the devshell comes up on its own here, and what has to be true for it.

## The interactive shell is fish

`modules/home/shell.nix` configures fish and hangs everything off it: `nix-your-shell`, `starship`, `atuin`, `zoxide` and `direnv` all with their fish integration, aliases (`cat` -> `bat`, `nix` -> `nom`, ...) under `programs.fish.shellAliases`. `modules/clanServices/base-system` enables fish system-wide too.

Home-manager installs each as a **fish hook** -- for direnv, `~/.config/fish/config.fish` carries

```fish
if not functions -q __direnv_export_eval
  <direnv>/bin/direnv hook fish | source
end
```

and `~/.config/direnv/lib/hm-nix-direnv.sh` supplies the `use_flake` implementation that `.envrc`'s `use flake` calls. `nix-your-shell` is a hook for the same reason: it makes `nix develop` re-exec into the current shell.

## The login shell was bash

Those hooks go into shell-specific files, and the file that is read belongs to the *login* shell. NixOS defaults `users.defaultUserShell` to bash and nothing here set `users.users.<name>.shell`, so the account landed in bash, where home-manager had installed no integration at all. Two confirmations from the store:

- the generated `users-groups.json` records `"shell":"...-wrapped-bash/wrapper"` for the user;
- the home-manager file manifest has `.config/fish/config.fish` and `.config/direnv/lib/hm-nix-direnv.sh` but **no** `~/.bashrc` and no `direnv hook bash` -- `programs.bash.enable` is off, so `programs.bash.initExtra` (where `enableBashIntegration`, on by default, would put the hook) is never written.

So the fish-only wiring was inert: `cd ~/projects/phoenix` ran no `.envrc`, and `nix develop` was never wrapped by `nix-your-shell` -- one root cause, not two.

## The fix

`modules/clanServices/base-system/default.nix` sets

```nix
users.users = lib.mkIf (username != null) {
  ${username}.shell = pkgs.fish;
};
```

It belongs in `base-system`, not a machine file: it is a property of the account, alongside `users.mutableUsers` and `programs.fish`. It takes effect at the next `nh os switch`; a running shell keeps its old environment, so start a new session.

If bash is actually wanted, do the other fix: `programs.bash.enable = true` in `modules/home/shell.nix`, which makes home-manager write the bash hooks (`programs.direnv.enableBashIntegration` already defaults to `true`). The fish configuration then stays inert -- the two are alternatives, not complements.

## The Ctrl+Space binding

`programs.fish.interactiveShellInit` in `base-system` defines `fish_user_key_bindings`, whose body is one `bind`. Three spellings there are load-bearing, and each fails silently:

- **`--key-names` is a listing mode, not a way to name a key.** `bind -K` / `--key-names` takes no other argument and ignores what follows, printing the key names fish knows -- on every shell start when written in `fish_user_key_bindings`.
- **`nul` is not a key name.** The named keys are the arrows, `backspace`, `comma`, `delete`, `end`, `enter`, `escape`, `f1`-`f12`, `home`, `insert`, `menu`, `minus`, `pageup`, `pagedown`, `printscreen`, `space` and `tab` (`bind(1)`). Anything else is read as that literal character sequence, so `bind nul ...` binds `n`, `u`, `l`.
- **`ctrl-space` is the spelling the byte matches.** A terminal sends NUL for Ctrl+Space, and only `ctrl-space` is matched by it -- `\c@` and `\x00` register a binding that lists as `''` and never fires.

The mode matters as much as the key. `-M insert` is vi's insert mode, and this configuration never enables vi bindings (`bind --list-modes` reports `default` alone), so an `insert` binding is inert. Omitting `-M` means `default`.
