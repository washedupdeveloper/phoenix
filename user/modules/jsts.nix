{ pkgs, ...}:
{
  home.packages = with pkgs; [
    nodejs
    nodePackages.typescript-language-server
    typescript
    nodePackages.prettier
    nodePackages.eslint
    nodePackages.tailwindcss
    nodePackages.postcss
    nodePackages.svelte-language-server
  ] ++ (import ./vscode/jsts.nix);
}
