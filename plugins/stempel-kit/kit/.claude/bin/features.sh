# shellcheck shell=sh

FEATURE_SPEC_FILE='function spec_file(f) { gsub(/[ `]/, "", f); sub(/^\[/, "", f); sub(/\].*$/, "", f); sub(/^(\.\/)?(specs\/)?/, "", f); return f }'

feature_row_field() {
  [ -f specs/README.md ] || return 0
  awk -F '|' -v spec="$1.md" -v col="$2" "$FEATURE_SPEC_FILE"'
    { sub(/\r$/, ""); s = spec_file($3) }
    s == spec { v = $col; gsub(/^ +| +$/, "", v); print v; exit }
  ' specs/README.md
}

resolve_branch() {
  case $2 in '' | -* | –* | _*) printf '%s' "$1" ;; *) printf '%s' "$2" ;; esac
}

feature_branch() {
  resolve_branch "$1" "$(feature_row_field "$1" 5)"
}

feature_for_branch() {
  [ -f specs/README.md ] || return 0
  awk -F '|' "$FEATURE_SPEC_FILE"'
    function trim(v) { gsub(/^ +| +$/, "", v); return v }
    { sub(/\r$/, ""); f = trim($2); s = spec_file($3) }
    f == "" || f ~ /^_/ || s !~ /\.md$/ { next }
    { sub(/\.md$/, "", s); print s "|" trim($4) "|" trim($5) }
  ' specs/README.md | while IFS='|' read -r _slug _status _cell; do
    if [ "$(resolve_branch "$_slug" "$_cell")" = "$1" ]; then printf '%s\t%s\n' "$_slug" "$_status"; fi
  done
}

section_lines() {
  [ -f "$1" ] || return 0
  awk -v name="$2" '
    { sub(/\r$/, "") }
    /^## / { inside = ($0 == "## " name); next }
    inside && /^- / && !/^- </ { print }
  ' "$1"
}

# plan_feature <state file>: the feature of a plan from its title line: the spec's file name without .md for
# "# Plan: <name> (spec: specs/<feature>.md)", or the slug for a fix, "# Plan: <slug> (fix)".
plan_feature() {
  [ -f "$1" ] || return 0
  head -n 1 "$1" | tr -d '\r' | sed -n \
    -e 's/^# Plan:.*(spec: specs\/\([^)]*\)\.md).*$/\1/p' \
    -e 's/^# Plan:[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*(fix)[[:space:]]*$/\1/p'
}

# plan_spec <state file>: the spec the plan's title names (specs/<feature>.md), empty for a fix.
plan_spec() {
  [ -f "$1" ] || return 0
  head -n 1 "$1" | tr -d '\r' | sed -n 's/^# Plan:.*(spec: \(specs\/[^)]*\.md\)).*$/\1/p'
}

# plan_criteria <state file>: the IDs of the "- **<ID>**" lines under "## Criteria", one per line.
plan_criteria() {
  [ -f "$1" ] || return 0
  awk '
    { sub(/\r$/, "") }
    /^## / { inside = ($0 == "## Criteria"); next }
    inside && /^- \*\*[A-Z][A-Za-z0-9_-]*-AC[0-9]+\*\*/ { id = $0; sub(/^- \*\*/, "", id); sub(/\*\*.*$/, "", id); print id }
  ' "$1"
}
