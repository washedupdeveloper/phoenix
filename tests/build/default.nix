# Build-tier assertions: what the configuration RENDERS.
#
# Between the unit tests (what an option says) and the VM tests (what a running
# machine does). No kernel, no QEMU, no Python: the artifact is built and inspected.
#
# Both sources are read from the evaluated config rather than restated:
# `system.build.etc` is the merged /etc activation installs, and
# `home.file.<path>.source` is the file home-manager links into the home.
{
  pkgs,
  lib,
  machines,
}:
let
  cfg = machines.workstation.config;

  # The account is discovered rather than repeated, so renaming it moves these
  # checks with it.
  user = builtins.head (builtins.attrNames cfg.home-manager.users);
  home = cfg.home-manager.users.${user};

  # `home.file` is keyed by absolute path, so the home directory has to come
  # from the configuration as well.
  homeFile = rel: home.home.file."${home.home.homeDirectory}/${rel}".source;

  etc = "${cfg.system.build.etc}/etc";

  # One derivation per group, so `--keep-going` reports every failing group
  # rather than stopping at the first.
  mkCheck =
    name: extra: script:
    pkgs.runCommand name
      (
        {
          nativeBuildInputs = [
            pkgs.coreutils
            pkgs.gnugrep
          ]
          ++ (extra.nativeBuildInputs or [ ]);
        }
        // lib.removeAttrs extra [ "nativeBuildInputs" ]
      )
      ''
        set -eu
        ${script}
        touch $out
      '';

  # A file must contain a line matching an extended regex. The failure prints
  # the file, so a drift says what changed rather than that something did.
  expect = file: pattern: ''
    if ! grep -qE ${lib.escapeShellArg pattern} ${file}; then
      echo "FAIL: ${file} does not match /${pattern}/" >&2
      echo "--- ${file} ---" >&2
      cat ${file} >&2
      exit 1
    fi
  '';

  expectAbsent = file: pattern: ''
    if grep -qE ${lib.escapeShellArg pattern} ${file}; then
      echo "FAIL: ${file} matches /${pattern}/, and must not" >&2
      cat ${file} >&2
      exit 1
    fi
  '';

  expectLink = file: target: ''
    actual=$(readlink ${file})
    if [ "$actual" != ${lib.escapeShellArg target} ]; then
      echo "FAIL: ${file} -> $actual, expected ${target}" >&2
      exit 1
    fi
  '';

  gitConfig = homeFile ".config/git/config";
  jjConfig = homeFile ".config/jj/config.toml";
  fishConfig = homeFile ".config/fish/config.fish";
in
{
  # The system half: the files activation installs into /etc.
  "build-etc" = mkCheck "build-etc" { } ''
    ${expect "${etc}/locale.conf" "^LANG=en_DK[.]UTF-8$"}
    ${expect "${etc}/set-environment" "^export EDITOR=\"nano\"$"}
    ${expectLink "${etc}/localtime" "/etc/zoneinfo/Europe/Copenhagen"}

    # Passwordless sudo for @wheel, as the rendered rule -- not as the option.
    ${expect "${etc}/sudoers" "^%wheel[[:space:]]+ALL=[(]ALL:ALL[)][[:space:]]+NOPASSWD"}

    # The sshd posture as written to the file the daemon reads. Whether sshd
    # *parses* it is `e2e-base-system`'s job; this is the file it parses.
    ${expect "${etc}/ssh/sshd_config" "^PasswordAuthentication no$"}
    ${expect "${etc}/ssh/sshd_config" "^KbdInteractiveAuthentication no$"}
    ${expect "${etc}/ssh/sshd_config" "^PermitRootLogin prohibit-password$"}

    # The Ctrl+Space binding lives in the system fish config, because
    # `programs.fish.interactiveShellInit` is base-system's -- the home config
    # carries the tool hooks instead. `ctrl-space` is the only spelling the byte
    # matches; `nul` would bind n, u and l, and `-M insert` a mode this
    # configuration never enters.
    ${expect "${etc}/fish/config.fish" "^[[:space:]]*bind ctrl-space accept-autosuggestion$"}
  '';

  # The user half: the files home-manager links into the account's home.
  "build-home" = mkCheck "build-home" { } ''
    ${expect gitConfig "^[[:space:]]*gpgsign = true$"}
    ${expect gitConfig "^[[:space:]]*format = \"ssh\"$"}
    ${expect gitConfig "^[[:space:]]*signingkey = \"~/.ssh/id_ed25519.pub\"$"}

    # jj has no `user.signingkey` -- its signing is `signing.backend` plus
    # `signing.key` -- so git's key must not have leaked into the shared
    # identity it receives.
    ${expectAbsent jjConfig "signingkey"}

    # The fish integration is a hook in this file -- the tool hooks live in the
    # account's config, while the key binding lives in the system one.
    ${expect fishConfig "direnv hook fish"}
    ${expect fishConfig "nix-your-shell --nom fish"}
  '';

  # One identity, two tools -- compared across the two RENDERED files, which is
  # the pair that drifted when each tool carried its own copy.
  "build-home-identity" =
    mkCheck "build-home-identity"
      {
        nativeBuildInputs = [ pkgs.git ];
      }
      ''
        git_email=$(git config --file ${gitConfig} --get user.email)
        git_name=$(git config --file ${gitConfig} --get user.name)
        jj_email=$(sed -n 's/^email = "\(.*\)"$/\1/p' ${jjConfig})
        jj_name=$(sed -n 's/^name = "\(.*\)"$/\1/p' ${jjConfig})

        if [ "$git_email" != "$jj_email" ]; then
          echo "FAIL: git says $git_email, jj says $jj_email" >&2
          exit 1
        fi
        if [ "$git_name" != "$jj_name" ]; then
          echo "FAIL: git says $git_name, jj says $jj_name" >&2
          exit 1
        fi
        if [ "$git_name" != ${
          lib.escapeShellArg (lib.toUpper (builtins.substring 0 1 user) + builtins.substring 1 (-1) user)
        } ]; then
          echo "FAIL: the identity name $git_name is not derived from the account $user" >&2
          exit 1
        fi
      '';
}
