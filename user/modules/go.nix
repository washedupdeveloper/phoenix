{pkgs, ...}: {
  home.packages = with pkgs;
    [
      go
      gopls
      delve
      # impl
      # staticcheck
    ]
    ++ (import ./vscode/go.nix {inherit pkgs;});
}
