# A GitHub Actions runner for this repository, as ordinary NixOS configuration.
#
# `bin/runner` needs no declaration and stores no secret: it mints a registration
# token from an existing `gh` login and runs in the foreground. This module is for a
# host that should be registered permanently instead. Both share one contract --
# Linux, Nix, and `/dev/kvm` when the `kvm` label is selected -- so a workflow that
# targets `[self-hosted, linux, kvm]` runs the same way on either.
#
# The token is not this module's business: `tokenFile` points at whatever the host
# already uses for secrets (clan vars, sops, agenix, a root-owned file). A token that
# can register a runner needs administration on the repository, and a registration
# token expires within the hour, so a PAT-style token is the durable choice.
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.ci-runner;
in
{
  options.services.ci-runner = {
    enable = lib.mkEnableOption "a self-hosted GitHub Actions runner for this repository";

    url = lib.mkOption {
      type = lib.types.str;
      example = "https://github.com/owner/repo";
      description = "Repository the runner registers against.";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.hostName}-gate";
      defaultText = lib.literalExpression ''"''${config.networking.hostName}-gate"'';
      description = "Runner name, as it appears in the repository's runner settings.";
    };

    labels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "kvm" ];
      description = ''
        Extra labels this host advertises. `self-hosted`, `Linux` and `X64` are added
        by the runner itself. The gate's VM tier selects `kvm`, so a host without
        /dev/kvm needs a different workflow selector, not a different label here.
      '';
    };

    tokenFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        Path to a file holding a token that may register a runner: a PAT with
        administration on the repository. Read at start, never copied into the store.
      '';
    };

    ephemeral = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        One job per registration. The service exits after a job and restarts, so no
        job inherits another's workspace or environment.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.github-runners.${cfg.name} = {
      enable = true;
      inherit (cfg)
        url
        name
        tokenFile
        ephemeral
        ;
      extraLabels = cfg.labels;
      # A registration outlives the process, so a restart without `replace` fails
      # against the name it left behind. Nothing is lost: a runner holds no state.
      replace = true;
    };
  };
}
