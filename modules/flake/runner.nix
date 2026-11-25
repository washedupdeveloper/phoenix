# `nix run .#runner` — the self-hosted runner launcher, reached through the flake.
#
# The script itself lives in `bin/runner` so it can be read, diffed and run without
# evaluating anything, which matters for a host whose only job is to register. This
# exposes that same file as an app, the way the rest of this repository's tooling is
# reached.
_: {
  perSystem =
    { pkgs, ... }:
    {
      apps.runner = {
        type = "app";
        program = "${pkgs.writeShellScript "phoenix-runner" (builtins.readFile ../../bin/runner)}";
      };
    };
}
