default = {
  packages =
    with pkgs;
    [
      nixd
      deadnix
      statix
      nixfmt
      nix-output-monitor
    ]
    ++ [
      inputs'.clan-core.packages.clan-cli
      config.treefmt.build.wrapper
    ];

  devshell.startup.pre-commit.text = config.pre-commit.installationScript;

  env = [
    {
      name = "NIX_CONFIG";
      value = "experimental-features = nix-command flakes pipe-operators";
    }
  ];
};
