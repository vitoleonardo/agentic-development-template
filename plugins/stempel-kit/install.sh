#!/bin/sh
# Install the kit into a project, or update an installed kit.
# Usage: ./install.sh <project-dir> [--adapter <name>] [--preset <name>]... [--plugin] [--force | --update]
#        ./install.sh <project-dir> --extension <name | plugin dir>
#   --adapter  stack adapter from adapters/ (for example typescript)
#   --preset   stack preset from the adapter's presets/ (for example nextjs); repeatable
#   --plugin   the skills, agents and hooks come from the stempel-kit plugin; install only the project files
#   --force    overwrite files that already exist in the project
#   --update   replace the kit files the project has not changed; stage the kit's version of changed ones in .work/kit-update/
#   --extension <name>  add an extension to a project that has the core: its scripts go to .claude/bin/, its
#              workflows to .github/workflows/, and its kit.conf.part becomes the section
#              "# extension: <name> bin/<script>" at the end of .claude/kit.conf.
#              The name resolves to ../stempel-kit-<name>/plugin next to this kit; a path with a slash is used as is.
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
extension=""
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
      --extension) extension=${2:?--extension needs a name or a plugin dir}; shift 2 ;;
      -h | --help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
      -*) echo "install: unknown option $1" >&2; exit 2 ;;
      *) target=$1; shift ;;
    esac
  done
}
parse_options "$@"

[ -n "$target" ] || { echo "usage: ./install.sh <project-dir> [--adapter <name>] [--preset <name>]... [--plugin] [--force | --update] | --extension <name>" >&2; exit 2; }
[ -d "$target" ] || { echo "install: $target is not a directory" >&2; exit 2; }
[ "$force" -eq 1 ] && [ "$update" -eq 1 ] && { echo "install: use either --force or --update" >&2; exit 2; }
target=$(CDPATH='' cd -- "$target" && pwd)
manifest=$target/.claude/kit.manifest
# A project on the retired next plugin: say so and change nothing (CORE-AC31).
retired="stempel-kit-""next"
if grep -qs -- "$retired" "$target/.claude/settings.json" "$target/.claude/kit.manifest"; then
  echo "install: $retired is retired. Install stempel-kit and the extensions that replaced its parts:" >&2
  echo "  stempel-kit-evidence stempel-kit-onboard stempel-kit-routing stempel-kit-autopilot stempel-kit-improve stempel-kit-risk" >&2
  echo "  /plugin uninstall $retired@stempel-kit, then /plugin install stempel-kit@stempel-kit and each extension, then rerun install.sh --plugin." >&2
  exit 2
fi

# --extension: add one extension to a project that has the core installed (CORE-AC19, CORE-AC20, CORE-AC33).
if [ -n "$extension" ]; then
  case $extension in
    */*) ext_dir=$(CDPATH='' cd -- "$extension" 2>/dev/null && pwd) || { echo "install: $extension is not a directory" >&2; exit 2; }
         ext_name=$(basename -- "$(dirname -- "$ext_dir")"); ext_name=${ext_name#stempel-kit-} ;;
    *) ext_dir=$kit/../stempel-kit-$extension/plugin; ext_name=$extension
       [ -d "$ext_dir" ] || { echo "install: unknown extension '$extension'. Available: $(cd "$kit/.." && ls -d stempel-kit-*/plugin 2>/dev/null | sed 's|^stempel-kit-||; s|/plugin$||' | tr '\n' ' ')" >&2; exit 2; } ;;
  esac
  conf=$target/.claude/kit.conf
  [ -f "$conf" ] || { echo "install: $target has no .claude/kit.conf; install the core first." >&2; exit 2; }
  part=$ext_dir/kit.conf.part
  [ -f "$part" ] || { echo "install: $ext_dir has no kit.conf.part." >&2; exit 2; }
  # Installed by name into a project with an adapter, the extension gets the adapter's settings when it has them.
  installed_adapter=""
  case $extension in */*) ;; *) installed_adapter=$(awk -F'\t' '$1 == "options" { print $2 }' "$manifest" 2>/dev/null | sed -n 's/.*--adapter \([^ ]*\).*/\1/p') ;; esac
  if [ -n "$installed_adapter" ] && [ -f "$kit/adapters/$installed_adapter/extensions/$ext_name.conf" ]; then
    part=$kit/adapters/$installed_adapter/extensions/$ext_name.conf
  fi
  script=$(cd "$ext_dir" && ls bin 2>/dev/null | head -n 1)
  [ -n "$script" ] || { echo "install: $ext_dir has no bin/ script." >&2; exit 2; }
  header="# extension: $ext_name bin/$script"
  # Every KIT_ variable the part defines must be new: not in the core part of kit.conf, not in another section.
  # An assignment may be indented (inside an if) or follow && (has_script e2e && KIT_E2E=...).
  awk -v name="$ext_name" -v part="$part" '
    # assigned <line>: the KIT_ variables the line assigns, separated by spaces.
    function assigned(l,   out) {
      out = ""
      if (l ~ /^[[:space:]]*#/) return out
      while (match(l, /(^|[[:space:];&|])KIT_[A-Z0-9_]+=/)) {
        v = substr(l, RSTART, RLENGTH - 1); sub(/^[^K]*/, "", v)
        out = out " " v
        l = substr(l, RSTART + RLENGTH)
      }
      return out
    }
    FNR == NR { n = split(assigned($0), a, " "); for (i = 1; i <= n; i++) mine[a[i]] = 1; next }
    /^# extension: / { owner = $3; next }
    {
      n = split(assigned($0), a, " ")
      for (i = 1; i <= n; i++) if ((a[i] in mine) && owner != name && !(a[i] in told)) {
        printf "install: %s is already defined by %s; extension %s cannot define it too.\n", a[i], (owner == "" ? "the core" : "extension " owner), name
        told[a[i]] = 1; bad = 1
      }
    }
    END { exit bad }
  ' "$part" "$conf" >&2 || exit 2
  mkdir -p "$target/.claude/bin"
  for f in "$ext_dir"/bin/*; do
    [ -f "$f" ] || continue
    cp "$f" "$target/.claude/bin/$(basename -- "$f")"
    [ -x "$f" ] && chmod +x "$target/.claude/bin/$(basename -- "$f")"
  done
  # Workflows the extension brings (the Risk check) go where GitHub reads them.
  # A workflow the project already has and changed is kept, as for every project file without --force.
  for f in "$ext_dir"/workflows/*.yml; do
    [ -f "$f" ] || continue
    dest=$target/.github/workflows/$(basename -- "$f")
    if [ -f "$dest" ] && [ "$force" -eq 0 ] && ! cmp -s "$f" "$dest"; then
      echo "install: kept .github/workflows/$(basename -- "$f"), which differs from the extension's; merge it by hand or use --force." >&2
      continue
    fi
    mkdir -p "$target/.github/workflows"
    cp "$f" "$dest"
  done
  # Replace the extension's own section if there is one, then append the part under its header.
  tmp=$(mktemp)
  awk -v name="$ext_name" '
    /^# extension: / { skip = ($3 == name) }
    !skip { print }
  ' "$conf" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' >"$tmp"
  { cat "$tmp"; printf '\n%s\n' "$header"; cat "$part"; } >"$conf"
  rm -f "$tmp"
  echo "Installed extension $ext_name: .claude/bin/$script and the section '$header' in .claude/kit.conf."
  exit 0
fi
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

gate_ask_rules='Bash(npm install *)
Bash(npm i *)
Bash(npm ci *)
Bash(npm uninstall *)
Bash(npm update *)
Bash(pnpm install *)
Bash(pnpm i *)
Bash(pnpm add *)
Bash(pnpm remove *)
Bash(pnpm update *)
Bash(pnpm up *)
Bash(yarn add *)
Bash(yarn remove *)
Bash(yarn install *)
Bash(bun add *)
Bash(bun install *)
Bash(pip install *)
Bash(uv add *)
Bash(uv pip *)
Bash(poetry add *)
Bash(cargo add *)
Bash(go get *)
Bash(bundle add *)
Bash(composer require *)
Bash(dotnet add *)
Bash(git push *)
Bash(gh pr create *)
Edit(.github/**)
Edit(.gitlab-ci.yml)
Edit(package-lock.json)
Edit(pnpm-lock.yaml)
Edit(yarn.lock)
Edit(bun.lock)
Edit(poetry.lock)
Edit(uv.lock)
Edit(Cargo.lock)
Edit(go.sum)
Edit(Gemfile.lock)
Edit(composer.lock)
Edit(migrations/**)
Edit(Dockerfile*)
Edit(docker-compose*)
Edit(compose.yaml)
Edit(compose.yml)
Edit(infra/**)
Edit(terraform/**)'
retire_ask_rules() {
  RULES=$gate_ask_rules awk '
    BEGIN { n = split(ENVIRON["RULES"], r, "\n"); for (i = 1; i <= n; i++) retired["\"" r[i] "\""] = 1 }
    {
      entry = $0
      sub(/^[[:space:]]+/, "", entry); sub(/,?[[:space:]]*$/, "", entry)
      if (entry in retired) { print entry > "/dev/stderr"; next }
      if ($0 ~ /^[[:space:]]*[]}]/ && have) sub(/,[[:space:]]*$/, "", prev)
      if (have) print prev
      prev = $0; have = 1
    }
    END { if (have) print prev }
  ' "$1" >"$scratch/retired-settings" 2>"$scratch/retired-rules" && cat "$scratch/retired-settings" >"$1"
}

render() {
  case $2 in
    # Skills name the plugin's agents (stempel-kit:reviewer); in the project they are plain names.
    .claude/skills/*/SKILL.md) sed 's/^agent: stempel-kit:/agent: /' "$1" ;;
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
      [ "$2" = .claude/settings.json ] && retire_ask_rules "$dest"
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
  (cd "$1" && find . -type f ! -path './presets/*' ! -path './extensions/*' | sed 's|^\./||') | while IFS= read -r rel; do
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
  if [ -s "$scratch/retired-rules" ]; then
    echo
    echo "Removed from .claude/settings.json; the guard asks for these now, per KIT_APPROVAL (.claude/bin/gate):"
    tr '\n' ' ' <"$scratch/retired-rules" | fold -s -w 110 | sed 's/^/  /'; echo
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
     With --plugin: /plugin marketplace add vitoleonardo/stempel-kit
                    /plugin install stempel-kit@stempel-kit
  5. Make the CI workflow a required status check in your branch protection rules.
EOF
