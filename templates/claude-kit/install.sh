#!/bin/sh
# Install the kit into a project.
# Usage: ./install.sh <project-dir> [--adapter <name>] [--preset <name>]... [--force]
#   --adapter  stack adapter from adapters/ (for example typescript)
#   --preset   stack preset from the adapter's presets/ (for example nextjs); repeatable
#   --force    overwrite files that already exist in the project
# Existing project files are never overwritten without --force; they are listed for a manual merge.
set -eu

kit=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
target=""
adapter=""
presets=""
force=0

while [ $# -gt 0 ]; do
  case $1 in
    --adapter) adapter=${2:?--adapter needs a name}; shift 2 ;;
    --preset) presets="$presets ${2:?--preset needs a name}"; shift 2 ;;
    --force) force=1; shift ;;
    -h | --help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "install: unknown option $1" >&2; exit 2 ;;
    *) target=$1; shift ;;
  esac
done

[ -n "$target" ] || { echo "usage: ./install.sh <project-dir> [--adapter <name>] [--preset <name>]... [--force]" >&2; exit 2; }
[ -d "$target" ] || { echo "install: $target is not a directory" >&2; exit 2; }
target=$(CDPATH='' cd -- "$target" && pwd)
if [ -n "$adapter" ] && [ ! -d "$kit/adapters/$adapter" ]; then
  echo "install: unknown adapter '$adapter'. Available: $(ls "$kit/adapters" | tr '\n' ' ')" >&2
  exit 2
fi

installed=$(mktemp)
skipped=$(mktemp)
trap 'rm -f "$installed" "$skipped"' EXIT

# copy <source> <relative destination>: files installed earlier in this run may be replaced
# (the adapter overlays the core); files that were already in the project are kept.
copy() {
  dest="$target/$2"
  if [ -e "$dest" ] && [ "$force" -eq 0 ] && ! grep -qxF "$2" "$installed"; then
    printf '%s\n' "$2" >>"$skipped"
    return 0
  fi
  mkdir -p "$(dirname -- "$dest")"
  cp -p "$1" "$dest"
  printf '%s\n' "$2" >>"$installed"
}

copy_tree() {
  (cd "$1" && find . -type f ! -path './presets/*' | sed 's|^\./||') | while IFS= read -r rel; do
    copy "$1/$rel" "$rel"
  done
}

copy_tree "$kit/kit"
[ -n "$adapter" ] && copy_tree "$kit/adapters/$adapter"
for preset in $presets; do
  file="$kit/adapters/$adapter/presets/$preset.md"
  [ -n "$adapter" ] && [ -f "$file" ] || { echo "install: preset '$preset' not found for adapter '${adapter:-none}'" >&2; exit 2; }
  copy "$file" ".claude/rules/$preset.md"
done

echo "Installed $(sort -u "$installed" | grep -c .) files into $target."
if [ -s "$skipped" ]; then
  echo
  echo "Kept these existing files (merge the kit's version by hand, or rerun with --force):"
  sed 's/^/  /' "$skipped"
fi
[ -z "$adapter" ] && echo "
No adapter installed: fill in .claude/kit.conf so the hooks know how to typecheck, test and format."

cat <<'EOF'

Next steps:
  1. Fill in the "Project facts" section of CLAUDE.md.
  2. Run your formatter once over the installed code, for example: .claude/bin/check format .github/scripts/*.mjs
  3. Make sure every check in .claude/kit.conf works: .claude/bin/check typecheck (and lint, test, coverage, build).
  4. Start Claude Code in the project and accept the trust prompt once; until then the hooks and allow rules stay off.
  5. Make the CI workflow a required status check in your branch protection rules.
EOF
