{ pkgs, ...}:
{
  home.packages = with pkgs; [
    elixir
    elixir_ls
    vscode-extensions.elixir-lsp.vscode-elixir-ls
    vscode-extensions.phoenixframework.phoenix
  ];
}
