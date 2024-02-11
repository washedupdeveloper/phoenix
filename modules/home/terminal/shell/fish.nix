{...}: {
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting
      bind -k nul -M insert 'accept-autosuggestion'
      set -Ux GIT_ASKPASS ""
      ssh-add ~/.ssh/id_ed25519
    '';
    shellAliases = {
      cat = "bat -p";
      find = "fd";
      gc = "nix store gc";
      # lsd aliases enabled as per lsd.enableAliases in shell/default.nix
    };
  };
}
