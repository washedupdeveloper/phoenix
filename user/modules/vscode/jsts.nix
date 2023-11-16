{ pkgs, ...}:
{
  home.packages = with pkgs; [
    vscode-extensions.esbenp.prettier-vscode
    vscode-extensions.dbaeumer.vscode-eslint
    vscode-extensions.svelte.svelte-vscode
  ];
}
