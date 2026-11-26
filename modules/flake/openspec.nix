# `nix run .#openspec` — the spec CLI, resolved through `flake.lock`.
#
# The gate used `npm install -g @fission-ai/openspec@1`, which resolves outside the lock
# at run time and leaves a second version on the machine that the lockfile does not
# describe. Same reason as `nix run .#runner`: a tool the repository depends on is a
# flake output.
_: {
  perSystem =
    { pkgs, ... }:
    {
      apps.openspec = {
        type = "app";
        program = "${pkgs.openspec}/bin/openspec";
      };
    };
}
