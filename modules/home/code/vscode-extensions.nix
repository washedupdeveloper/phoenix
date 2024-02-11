{pkgs, ...}: {
  home.packages = with pkgs; [
    vscode-extensions.bbenoist.nix
    vscode-extensions.kamadorueda.alejandra
    vscode-extensions.mikestead.dotenv
    vscode-extensions.editorconfig.editorconfig
    vscode-extensions.davidanson.vscode-markdownlint
    vscode-extensions.redhat.vscode-yaml
    vscode-extensions.bradlc.vscode-tailwindcss
  ];
}
