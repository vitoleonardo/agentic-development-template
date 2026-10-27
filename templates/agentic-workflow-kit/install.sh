#!/bin/sh
# Install the kit into a project, or update an installed kit.
# Usage: ./install.sh <project-dir> [--adapter <name>] [--preset <name>]... [--plugin] [--force | --update]
#   --adapter  stack adapter from adapters/ (for example typescript)
#   --preset   stack preset from the adapter's presets/ (for example nextjs); repeatable
#   --plugin   the skills, agents and hooks come from the agentic-workflow-kit plugin; install only the project files
#   --force    overwrite files that already exist in the project
#   --update   replace the kit files the project has not changed; stage the kit's version of changed ones in .work/kit-update/
# Existing project files are never overwritten without --force; they are listed for a manual merge.
# Without --adapter, --preset and --plugin, the options of the last install (in .claude/kit.manifest) are used.
set -eu

kit=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
target=""
adapter=""
presets=""
plugin=0
force=0
update=0
options=""
tab=$(printf '\t')

parse_options() {
  while [ $# -gt 0 ]; do
    case $1 in
      --adapter) adapter=${2:?--adapter needs a name}; options="$options --adapter $2"; shift 2 ;;
      --preset) presets="$presets ${2:?--preset needs a name}"; options="$options --preset $2"; shift 2 ;;
      --plugin) plugin=1; options="$options --plugin"; shift ;;
      --force) force=1; shift ;;
      --update) update=1; shift ;;
      -h | --help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
      -*) echo "install: unknown option $1" >&2; exit 2 ;;
      *) target=$1; shift ;;
    esac
  done
}
parse_options "$@"

[ -n "$target" ] || { echo "usage: ./install.sh <project-dir> [--adapter <name>] [--preset <name>]... [--plugin] [--force | --update]" >&2; exit 2; }
[ -d "$target" ] || { echo "install: $target is not a directory" >&2; exit 2; }
[ "$force" -eq 1 ] && [ "$update" -eq 1 ] && { echo "install: use either --force or --update" >&2; exit 2; }
target=$(CDPATH='' cd -- "$target" && pwd)
manifest=$target/.claude/kit.manifest
old_manifest=/dev/null
[ -f "$manifest" ] && old_manifest=$manifest
if [ -z "$options" ]; then
  # shellcheck disable=SC2046 # the saved options are words
  parse_options $(awk -F'\t' '$1 == "options" { print $2 }' "$old_manifest")
fi
if [ -n "$adapter" ] && [ ! -d "$kit/adapters/$adapter" ]; then
  echo "install: unknown adapter '$adapter'. Available: $(ls "$kit/adapters" | tr '\n' ' ')" >&2
  exit 2
fi
for preset in $presets; do
  [ -n "$adapter" ] && [ -f "$kit/adapters/$adapter/presets/$preset.md" ] || { echo "install: preset '$preset' not found for adapter '${adapter:-none}'" >&2; exit 2; }
done

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
installed=$scratch/installed
skipped=$scratch/skipped
staged=$scratch/staged
recorded=$scratch/recorded
rendered=$scratch/rendered
: >"$installed"
: >"$skipped"
: >"$staged"
: >"$recorded"
staging=$target/.work/kit-update
[ "$update" -eq 1 ] && rm -rf "$staging"

checksum() { cksum <"$1" | awk '{ print $1 "-" $2 }'; }

# With --plugin the hooks are registered by the plugin, so settings.json must not register them again.
strip_hooks() {
  awk '
    /^  "hooks": \{/ { skip = 1; sub(/,$/, "", prev); next }
    skip { if ($0 ~ /^  \}/) skip = 0; next }
    { if (have) print prev; prev = $0; have = 1 }
    END { if (have) print prev }
  ' "$1"
}

render() {
  case $2 in
    # Skills name the plugin's agents (agentic-workflow-kit:reviewer); in the project they are plain names.
    .claude/skills/*/SKILL.md) sed 's/^agent: agentic-workflow-kit:/agent: /' "$1" ;;
    .claude/settings.json) if [ "$plugin" -eq 1 ]; then strip_hooks "$1"; else cat "$1"; fi ;;
    *) cat "$1" ;;
  esac
}

copy() {
  dest=$target/$2
  render "$1" "$2" >"$rendered"
  new=$(checksum "$rendered")
  if [ -e "$dest" ] && [ "$force" -eq 0 ]; then
    if [ "$update" -eq 0 ]; then
      printf '%s\n' "$2" >>"$skipped"
      return 0
    fi
    printf '%s\t%s\n' "$new" "$2" >>"$recorded"
    current=$(checksum "$dest")
    base=$(awk -F'\t' -v path="$2" '$2 == path { print $1 }' "$old_manifest")
    { [ "$current" = "$new" ] || [ "$base" = "$new" ]; } && return 0
    if [ "$current" != "$base" ]; then
      mkdir -p "$(dirname -- "$staging/$2")"
      cp "$rendered" "$staging/$2"
      printf '%s\n' "$2" >>"$staged"
      return 0
    fi
  fi
  mkdir -p "$(dirname -- "$dest")"
  cat "$rendered" >"$dest"
  if [ -x "$1" ]; then chmod +x "$dest"; fi
  printf '%s\t%s\n' "$new" "$2" >>"$recorded"
  printf '%s\n' "$2" >>"$installed"
}

# The plugin manifest and the plugin's hook config only matter when kit/.claude is loaded as a plugin.
list_tree() {
  (cd "$1" && find . -type f ! -path './presets/*' | sed 's|^\./||') | while IFS= read -r rel; do
    case $rel in
      .claude/.claude-plugin/* | .claude/hooks/hooks.json) continue ;;
      .claude/skills/* | .claude/agents/* | .claude/hooks/*) [ "$plugin" -eq 1 ] && continue ;;
    esac
    printf '%s\t%s\n' "$rel" "$1/$rel"
  done
}

{
  list_tree "$kit/kit"
  [ -n "$adapter" ] && list_tree "$kit/adapters/$adapter"
  for preset in $presets; do
    printf '.claude/rules/%s.md\t%s\n' "$preset" "$kit/adapters/$adapter/presets/$preset.md"
  done
} | awk -F'\t' '
  !($1 in source) { order[++n] = $1 }
  { source[$1] = $2 }
  END { for (i = 1; i <= n; i++) print order[i] "\t" source[order[i]] }
' >"$scratch/sources"

while IFS="$tab" read -r rel source; do
  copy "$source" "$rel"
done <"$scratch/sources"

{
  printf 'options\t%s\n' "${options# }"
  awk -F'\t' '
    $1 == "options" { next }
    !($2 in hash) { order[++n] = $2 }
    { hash[$2] = $1 }
    END { for (i = 1; i <= n; i++) print hash[order[i]] "\t" order[i] }
  ' "$old_manifest" - <"$recorded"
} >"$scratch/manifest"
mkdir -p "$target/.claude"
mv "$scratch/manifest" "$manifest"

if [ "$update" -eq 1 ]; then
  echo "Updated $(grep -c . "$installed") files in $target."
  if [ -s "$staged" ]; then
    echo
    echo "Changed in the project and in the kit. The kit's version is in .work/kit-update/; merge it by hand:"
    sed 's|.*|  diff .work/kit-update/& &|' "$staged"
  fi
  echo
  echo "Review the changes with git diff and commit them with .claude/kit.manifest."
  exit 0
fi

echo "Installed $(grep -c . "$installed") files into $target."
if [ -s "$skipped" ]; then
  echo
  echo "Kept these existing files (merge the kit's version by hand, or rerun with --update or --force):"
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
