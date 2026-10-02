# Hermes indexes a skill as a direct child directory carrying a SKILL.md, so that
# check is what keeps caveman's own build inputs out of the loader. Shared by
# `.#caveman-skills` and modules/hermes.nix. See docs/hermes-agent-provisioning.md.
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
