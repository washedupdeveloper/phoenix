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
      description = "Node JS packages for general purpose";
    };
    enableGolang = mkOption {
      type = types.bool;
      default = false;
      description = "Golang and related dependencies";
    };
    enableElixir = mkOption {
      type = types.bool;
      default = false;
      description = "Elxiir and related dependencies";
    };
  };

  config = with lib; {
    home.packages =
      optionals config.enableNodeJs (with pkgs; [
        nodejs
        nodePackages.typescript-language-server
        typescript
      ])
      ++ optionals config.enableNodeJsPkgs (with pkgs; [
        nodePackages.prettier
        nodePackages.eslint
        nodePackages.tailwindcss
        nodePackages.postcss
        nodePackages.svelte-language-server
        nodePackages.pnpm
      ])
      ++ optionals config.enableGolang (with pkgs; [
        go
        gopls
        delve
        # impl
        # staticcheck
      ])
      ++ optionals config.enableElixir (with pkgs; [elixir elixir_ls]);
  };
}
