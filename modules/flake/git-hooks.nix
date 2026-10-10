{ inputs, ... }:
{
  imports = [ inputs.git-hooks.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      pre-commit = {
        check.enable = true;
        settings = {
          excludes = [
            "flake.lock"
            "^sops/"
            "^vars/"
          ];

          hooks = {
            treefmt.enable = true;

            # The build gate, which nothing ran before: `nix flake check`
            # builds every check, including the machine toplevel that
            # modules/flake/checks.nix derives. That is minutes of work, so it
            # runs at pre-push rather than on every commit.
            flake-check = {
              enable = true;
              name = "nix flake check";
              entry = "nix flake check";
              pass_filenames = false;
              stages = [ "pre-push" ];
            };

            check-added-large-files.enable = true;

            deadnix = {
              enable = true;
              settings = {
                noUnderscore = true;
                edit = true;
              };
            };

            nil.enable = true;

            statix.enable = true;

            gitleaks = {
              enable = true;
              name = "gitleaks";
              entry = "${pkgs.gitleaks}/bin/gitleaks protect --verbose --redact --staged";
              pass_filenames = false;
            };

            markdownlint = {
              enable = true;
              settings.configuration = {
                MD013 = false;
              };
            };

            editorconfig-checker = {
              enable = true;
              excludes = [ "\\.md$" ];
            };
          };
        };
      };
    };
}
