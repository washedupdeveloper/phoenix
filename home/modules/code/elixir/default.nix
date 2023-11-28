{pkgs, ...}: {
  home.packages = with pkgs;
    [
      elixir
      elixir_ls
    ]
    ++ (import ./vscode-extensions.nix {inherit pkgs;});
}
