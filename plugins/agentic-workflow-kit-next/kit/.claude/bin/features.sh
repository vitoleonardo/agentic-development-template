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

# plan_rows <state file>: "<task>|<group>|<tier>|<1 when open>" for each numbered task under Progress, in order.
# Group and tier come from the Tasks table, read by header name. A plan without a Group column gets groups of
# three, counted over all its tasks, so the numbers stay the same however many are ticked.
plan_rows() {
  [ -f "$1" ] || return 0
  awk '
    function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    { sub(/\r$/, "") }
    /^## / { section = substr($0, 4); next }
    section == "Tasks" && /^\|/ {
      n = split($0, c, "|")
      if (!head) {
        for (i = 2; i < n; i++) {
          h = tolower(trim(c[i]))
          if (h == "#") col_task = i; else if (h == "group") col_group = i; else if (h == "tier") col_tier = i
        }
        head = 1
        next
      }
      id = col_task ? trim(c[col_task]) : ""
      if (id ~ /^[0-9]+$/) { group[id] = col_group ? trim(c[col_group]) : ""; tier[id] = col_tier ? trim(c[col_tier]) : "" }
      next
    }
    section == "Progress" && /^- \[[ xX]\] [0-9]+/ && !/</ {
      id = $0
      sub(/^- \[[ xX]\] /, "", id)
      sub(/[^0-9].*$/, "", id)
      ids[++count] = id
      open[count] = ($0 ~ /^- \[ \]/) ? 1 : 0
    }
    END {
      for (i = 1; i <= count; i++) {
        id = ids[i]
        printf "%s|%s|%s|%d\n", id, (col_group ? group[id] : int((i + 2) / 3)), tier[id], open[i]
      }
    }
  ' "$1"
}

# plan_has_groups <state file>: true when the Tasks table has a Group column.
plan_has_groups() {
  [ -f "$1" ] || return 1
  awk '
    /^## / { inside = ($0 == "## Tasks"); next }
    inside && /^\|/ { n = split(tolower($0), c, "|"); for (i = 2; i < n; i++) { gsub(/[ \t\r]/, "", c[i]); if (c[i] == "group") found = 1 } exit }
    END { exit !found }
  ' "$1"
}

# plan_shape_problem: from plan_rows on stdin, what breaks the group rules, if anything.
plan_shape_problem() {
  awk -F '|' '
    $2 == "" { print "task " $1 " has no group"; exit }
    {
      size[$2]++
      if (size[$2] > 3) { print "group " $2 " holds " size[$2] " tasks; a group takes at most 3 tasks"; exit }
      if (size[$2] > 1 && $2 != last) { print "group " $2 " is not consecutive in plan order"; exit }
      last = $2
    }
  '
}
