{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { config, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";

        programs.nixfmt.enable = true;

        settings.global.excludes = [
          "flake.lock"
          "vars/**"
          "sops/**"
          ".direnv/**"
        ];
      };

      formatter = config.treefmt.build.wrapper;
    };
}
