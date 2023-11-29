{pkgs, ...}: {
  home.packages = with pkgs;
    [
      go
      gopls
      delve
      # impl
      # staticcheck
    ]
    ++ (import ./vscode-extensions.nix {inherit pkgs;});
}
