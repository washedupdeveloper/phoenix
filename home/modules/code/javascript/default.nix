{pkgs, ...}: {
  home.packages = with pkgs;
    [
      nodejs
      nodePackages.typescript-language-server
      typescript
      nodePackages.prettier
      nodePackages.eslint
      nodePackages.tailwindcss
      nodePackages.postcss
      nodePackages.svelte-language-server
      nodePackages.pnpm
    ]
    ++ (import ./vscode-extensions.nix {inherit pkgs;});
}
