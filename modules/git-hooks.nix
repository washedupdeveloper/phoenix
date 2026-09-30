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

            check-added-large-files.enable = true;

            typos = {
              enable = false;
              settings = {
              };
            };

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
