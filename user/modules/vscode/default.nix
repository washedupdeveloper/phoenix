{ pkgs, ...}:
{
  home.packages = with pkgs; [
    vscode-extension-bbenoist-Nix
    vscode-extensions.kamadorueda.alejandra
    vscode-extension-mikestead-dotenv
    vscode-extension-EditorConfig-EditorConfig
    vscode-extension-DavidAnson-vscode-markdownlint
    vscode-extensions.redhat.vscode-yaml
  ];
}
