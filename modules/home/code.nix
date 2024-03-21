{
  lib,
  pkgs,
  config,
  ...
}: {
  options = with lib; {
    enableGlobalNodeJs = mkOption {
      type = types.bool;
      default = false;
      description = "Global Node JS and related dependencies";
    };
    enableGlobalNodeJsPkgs = mkOption {
      type = types.bool;
      default = false;
      description = "Global Node JS packages for general purpose";
    };
    enableGlobalGolang = mkOption {
      type = types.bool;
      default = false;
      description = "Global Golang and related dependencies";
    };
    enableGlobalElixir = mkOption {
      type = types.bool;
      default = false;
      description = "Global Elxiir and related dependencies";
    };
  };

  config = {
    home.packages =
      lib.optionals config.enableGlobalNodeJs (with pkgs; [
        nodejs
        nodePackages.typescript-language-server
        typescript
      ])
      ++ lib.optionals config.enableGlobalNodeJsPkgs (with pkgs; [
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
