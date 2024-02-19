{
  lib,
  pkgs,
  config,
  ...
}: {
  options = {
    enableGlobalNodeJs = lib.mkEnableOption "global Node.js";
    enableGlobalGolang = lib.mkEnableOption "global Golang";
    enableGlobalElixir = lib.mkEnableOption "global Elixir";
  };

  config = {
    home.packages =
      lib.optionals config.enableGlobalNodeJs (with pkgs; [
        nodejs
        nodePackages.typescript-language-server
        typescript
        nodePackages.prettier
        nodePackages.eslint
        nodePackages.tailwindcss
        nodePackages.postcss
        nodePackages.svelte-language-server
        nodePackages.pnpm
      ])
      ++ lib.optionals config.enableGlobalGolang (with pkgs; [
        go
        gopls
        delve
        # impl
        # staticcheck
      ])
      ++ lib.optionals config.enableGlobalElixir (with pkgs; [elixir elixir_ls]);
  };
}
