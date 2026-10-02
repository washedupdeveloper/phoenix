# Shell integrations

Why the devshell comes up on its own in this repository, and what has to be
true for that to happen.

## The interactive shell is fish

`modules/home/shell.nix` configures fish as the interactive shell and hangs
everything else off it: `nix-your-shell`, `starship`, `atuin`, `zoxide` and
`direnv` are all enabled with their fish integration, and the aliases
(`cat` -> `bat`, `nix` -> `nom`, ...) live under `programs.fish.shellAliases`.
`modules/clanServices/base-system` enables fish system-wide as well.

Home-manager installs each of those as a **fish hook** -- for direnv, the
generated `~/.config/fish/config.fish` carries

```fish
if not functions -q __direnv_export_eval
  <direnv>/bin/direnv hook fish | source
end
```

and `~/.config/direnv/lib/hm-nix-direnv.sh` supplies the `use_flake`
implementation that `.envrc`'s `use flake` calls. `nix-your-shell` is a fish
hook for the same reason: it is what makes `nix develop` re-exec into the
current shell instead of spawning a bare one.

## The login shell was bash

Every one of those hooks is written into a shell-specific file, and the file
that is read is the one belonging to the *login* shell. NixOS defaults
`users.defaultUserShell` to bash, and nothing here set
`users.users.<name>.shell` -- so the account landed in bash, where home-manager
had installed no shell integration at all.

Two independent confirmations from the machine's store:

- the generated `users-groups.json` records
  `"shell":"...-wrapped-bash/wrapper"` for the user;
- the home-manager file manifest contains `.config/fish/config.fish` and
  `.config/direnv/lib/hm-nix-direnv.sh` but **no** `~/.bashrc` and no
  `direnv hook bash` anywhere -- `programs.bash.enable` is off, so
  home-manager's `programs.bash.initExtra` (where `enableBashIntegration`,
  which defaults to on, would put the bash hook) is never written.

So the fish-only wiring was inert. `cd ~/projects/phoenix` ran no `.envrc`,
which is the whole of "direnv doesn't work automatically", and `nix develop`
was never wrapped by `nix-your-shell` -- the same root cause, not a second bug.

## The fix

`modules/clanServices/base-system/default.nix` sets

```nix
users.users = lib.mkIf (username != null) {
  ${username}.shell = pkgs.fish;
};
```

so the login shell is the shell the rest of the configuration already targets.
It belongs in `base-system` rather than a machine file because it is a property
of the account, and `base-system` is where the account's other system-level
settings (`users.mutableUsers`, `programs.fish`) already live.

## Consequences

- It takes effect at the next `nh os switch`. A shell that is already running
  keeps its old environment; start a new session.
- If bash is actually wanted, the fix is the other one: set
  `programs.bash.enable = true` in `modules/home/shell.nix`, which makes
  home-manager write the bash hooks (`programs.direnv.enableBashIntegration`
  already defaults to `true`). The fish configuration would then stay inert, so
  the two are alternatives, not complements.

## The Ctrl+Space binding

`programs.fish.interactiveShellInit` in `base-system` defines
`fish_user_key_bindings`, whose body is one `bind`. Three spellings in that line
are load-bearing, and each fails silently:

- **`--key-names` is a listing mode, not a way to name a key.** `bind -K` /
  `--key-names` has its own synopsis form: it takes no other argument, ignores
  whatever follows it, and prints the key names fish knows. Written inside
  `fish_user_key_bindings`, it prints that list on every shell start.
- **`nul` is not a key name.** The named keys are the arrows, `backspace`,
  `comma`, `delete`, `end`, `enter`, `escape`, `f1`-`f12`, `home`, `insert`,
  `menu`, `minus`, `pageup`, `pagedown`, `printscreen`, `space` and `tab`
  (`bind(1)`; the same list `bind --key-names` prints). Anything else is read as
  that literal sequence of characters, so `bind nul ...` binds `n`, `u`, `l`.
- **`ctrl-space` is the spelling the byte matches.** A terminal sends NUL for
  Ctrl+Space, and of the candidates only `ctrl-space` is matched by it -- `\c@`
  and `\x00` register a binding that lists as `''` and never fires.

The mode matters as much as the key. `-M insert` is vi's insert mode, and this
configuration never enables vi key bindings (`bind --list-modes` reports
`default` alone), so an `insert` binding is inert. Omitting `-M` means `default`,
which is the mode in use.

Checked by running fish against each version of the file in a pty: the old line
reproduces the 31-name dump before the first prompt, the new one prints nothing,
and Ctrl+Space then fires the binding.
