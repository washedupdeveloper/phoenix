{pkgs, ...}: {
  home.packages = with pkgs;
    [
      elixir
      elixir_ls
    ]
    ++ (import ./vscode/elixir.nix {inherit pkgs;});
}
