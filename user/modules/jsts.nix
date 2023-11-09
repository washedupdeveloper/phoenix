{ pkgs, ...}:
{
  home.packages = with pkgs; [
    nodejs
    nodePackages.typescript-language-server
    typescript
    nodePackages.prettier
    vscode-extensions.esbenp.prettier-vscode
    nodePackages.eslint
    vscode-extensions.dbaeumer.vscode-eslint
    nodePackages.tailwindcss
    nodePackages.postcss
    nodePackages.svelte-language-server
    vscode-extensions.svelte.svelte-vscode
  ];
}
