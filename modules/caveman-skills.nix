# Hermes-loadable skill set, built out of the caveman repository.
#
# Hermes indexes a skill as a direct child directory that carries a SKILL.md,
# so only those directories are copied. The rest of skills/ -- registry.json,
# the *.mjs helpers, native/ and generated/ -- is caveman's own build input and
# must not reach the loader as if it were a skill.
#
# Shared by the `caveman-skills` flake package (which the refresh job builds)
# and by the home-manager wiring in hermes.nix (which points Hermes at it), so
# both always describe the same derivation.
{ pkgs, cavemanSrc }:
pkgs.runCommand "caveman-skills" { } ''
  mkdir -p $out
  for dir in ${cavemanSrc}/skills/*/; do
    name=$(basename "$dir")
    if [ -f "$dir/SKILL.md" ]; then
      cp -r "$dir" "$out/$name"
    fi
  done
  echo "caveman-skills: packaged $(find $out -mindepth 1 -maxdepth 1 -type d | wc -l) skills"
''
