#!/bin/sh
# Install the kit into a project.
# Usage: ./install.sh <project-dir> [--adapter <name>] [--preset <name>]... [--plugin] [--force]
#   --adapter  stack adapter from adapters/ (for example typescript)
#   --preset   stack preset from the adapter's presets/ (for example nextjs); repeatable
#   --plugin   the skills, agents and hooks come from the agentic-workflow-kit plugin; install only the project files
#   --force    overwrite files that already exist in the project
# Existing project files are never overwritten without --force; they are listed for a manual merge.
set -eu

kit=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
target=""
adapter=""
presets=""
plugin=0
force=0

while [ $# -gt 0 ]; do
  case $1 in
    --adapter) adapter=${2:?--adapter needs a name}; shift 2 ;;
    --preset) presets="$presets ${2:?--preset needs a name}"; shift 2 ;;
    --plugin) plugin=1; shift ;;
    --force) force=1; shift ;;
    -h | --help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "install: unknown option $1" >&2; exit 2 ;;
    *) target=$1; shift ;;
  esac
done

[ -n "$target" ] || { echo "usage: ./install.sh <project-dir> [--adapter <name>] [--preset <name>]... [--plugin] [--force]" >&2; exit 2; }
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
  case $2 in
    # Skills name the plugin's agents (agentic-workflow-kit:reviewer); in the project they are plain names.
    .claude/skills/*/SKILL.md) sed 's/^agent: agentic-workflow-kit:/agent: /' "$1" >"$dest" ;;
    *) cp -p "$1" "$dest" ;;
  esac
  printf '%s\n' "$2" >>"$installed"
}

# The plugin manifest and the plugin's hook config only matter when kit/.claude is loaded as a plugin.
copy_tree() {
  (cd "$1" && find . -type f ! -path './presets/*' | sed 's|^\./||') | while IFS= read -r rel; do
    case $rel in
      .claude/.claude-plugin/* | .claude/hooks/hooks.json) continue ;;
      .claude/skills/* | .claude/agents/* | .claude/hooks/*) [ "$plugin" -eq 1 ] && continue ;;
    esac
    copy "$1/$rel" "$rel"
  done
}

# With --plugin the hooks are registered by the plugin, so settings.json must not register them again.
strip_hooks() {
  file="$target/.claude/settings.json"
  awk '
    /^  "hooks": \{/ { skip = 1; sub(/,$/, "", prev); next }
    skip { if ($0 ~ /^  \}/) skip = 0; next }
    { if (have) print prev; prev = $0; have = 1 }
    END { if (have) print prev }
  ' "$file" >"$file.tmp" && mv "$file.tmp" "$file"
}

copy_tree "$kit/kit"
[ -n "$adapter" ] && copy_tree "$kit/adapters/$adapter"
for preset in $presets; do
  file="$kit/adapters/$adapter/presets/$preset.md"
  [ -n "$adapter" ] && [ -f "$file" ] || { echo "install: preset '$preset' not found for adapter '${adapter:-none}'" >&2; exit 2; }
  copy "$file" ".claude/rules/$preset.md"
done
[ "$plugin" -eq 1 ] && grep -qxF .claude/settings.json "$installed" && strip_hooks

echo "Installed $(sort -u "$installed" | grep -c .) files into $target."
if [ -s "$skipped" ]; then
  echo
  echo "Kept these existing files (merge the kit's version by hand, or rerun with --force):"
  sed 's/^/  /' "$skipped"
fi
[ -z "$adapter" ] && echo "
No adapter installed: fill in .claude/kit.conf so the hooks know how to typecheck, test and format,
or run /onboard in Claude Code to have it proposed from the repository (existing repositories)."

cat <<'EOF'

Next steps:
  1. Fill in the "Project facts" section of CLAUDE.md.
  2. If your formatter or linter also checks .claude/, run it once over the adapter helpers, for example: .claude/bin/check format .claude/bin/*.mjs
  3. Make sure every check in .claude/kit.conf works: .claude/bin/check typecheck (and lint, test, coverage, build).
  4. Start Claude Code in the project and accept the trust prompt once; until then the hooks and allow rules stay off.
     With --plugin: /plugin marketplace add vitoleonardo/agentic-development-template
                    /plugin install agentic-workflow-kit@agentic-development-template
  5. Make the CI workflow a required status check in your branch protection rules.
EOF
