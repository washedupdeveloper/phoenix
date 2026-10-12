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

            # The whole gate, on every commit: `nix flake check` builds every
            # check -- the machine toplevel, the topology, the unit groups, the
            # VM tests -- and runs these hooks again through
            # `checks.pre-commit`. One command covers everything.
            #
            # The guard is load-bearing. `checks.pre-commit` runs
            # `pre-commit run --all-files`, so this hook would run inside the
            # gate and call the gate again, without end. Inside a Nix build
            # `NIX_BUILD_TOP` is set and outside it is not, so the nested
            # invocation returns immediately and the recursion stops at depth
            # one. Do not remove it.
            flake-check = {
              enable = true;
              name = "nix flake check";
              entry = ''
                sh -c 'if [ -n "$NIX_BUILD_TOP" ]; then exit 0; fi; command -v nix >/dev/null || { echo "nix is not on PATH -- run git from the devshell (nix develop)" >&2; exit 1; }; exec nix flake check'
              '';
              language = "system";
              pass_filenames = false;
              stages = [ "pre-commit" ];
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
