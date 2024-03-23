{
  lib,
  pkgs,
  config,
  ...
}: {
  options = with lib; {
    enableNodeJs = mkOption {
      type = types.bool;
      default = false;
      description = "Global Node JS and related dependencies";
    };
    enableNodeJsPkgs = mkOption {
      type = types.bool;
      default = false;
      description = "Global Node JS packages for general purpose";
    };
    enableGolang = mkOption {
      type = types.bool;
      default = false;
      description = "Global Golang and related dependencies";
    };
    enableElixir = mkOption {
      type = types.bool;
      default = false;
      description = "Global Elxiir and related dependencies";
    };
  };

  config = with lib; {
    home.packages =
      optionals config.enableGlobalNodeJs (with pkgs; [
        nodejs
        nodePackages.typescript-language-server
        typescript
      ])
      ++ optionals config.enableGlobalNodeJsPkgs (with pkgs; [
        nodePackages.prettier
        nodePackages.eslint
        nodePackages.tailwindcss
        nodePackages.postcss
        nodePackages.svelte-language-server
        nodePackages.pnpm
      ])
      ++ optionals config.enableGlobalGolang (with pkgs; [
        go
        gopls
        delve
        # impl
        # staticcheck
      ])
      ++ optionals config.enableGlobalElixir (with pkgs; [elixir elixir_ls]);
  };
}
