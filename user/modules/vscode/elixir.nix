{ pkgs, ...}:
{
  home.packages = with pkgs; [
    vscode-extensions.elixir-lsp.vscode-elixir-ls
    vscode-extensions.phoenixframework.phoenix
  ];
}
