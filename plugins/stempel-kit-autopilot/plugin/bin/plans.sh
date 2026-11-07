# shellcheck shell=sh
# The build's helpers on top of the core's features.sh: the feature list, a plan's spec and criteria, its groups and
# layers, and the build lock. Sourced by autopilot, stack and status, after features.sh; evidence uses
# feature_layers when it is installed.

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

# The group helpers read the plan in $state, the caller's state file (.work/<branch>.md).

# group_list: the plan's groups in plan order.
# shellcheck disable=SC2154
group_list() { plan_rows "$state" | cut -d '|' -f 2 | awk '!seen[$0]++'; }
# group_rows <group>: the plan_rows lines of one group.
# shellcheck disable=SC2154
group_rows() { plan_rows "$state" | awk -F '|' -v g="$1" '$2 == g'; }
# group_from <group>: the commit before the group's work. If a ticked task has no commit naming it, the base.
group_from() {
  _ticked=$(group_rows "$1" | awk -F '|' '$4 == 0 { print $1 }')
  if [ -z "$_ticked" ]; then git rev-parse HEAD; return; fi
  _mb=$(merge_base)
  _first=""
  for _t in $_ticked; do
    _c=$(git log --format=%H -E -i --grep="task $_t([^0-9]|\$)" "$_mb..HEAD" | tail -n 1)
    if [ -z "$_c" ]; then printf '%s' "$_mb"; return; fi
    if [ -z "$_first" ] || git merge-base --is-ancestor "$_c" "$_first"; then _first=$_c; fi
  done
  git rev-parse -q --verify "$_first^" 2>/dev/null || printf '%s' "$_mb"
}

# feature_layers <branch>: the stacked layers of the feature on <branch> (the current HEAD), bottom to top, as
# "<layer branch> TAB <commit> TAB <group>" (specs/stacked-groups.md). Every group of a plan with several groups
# whose next group has started ends a layer, "<branch>-g<group>", at the commit before the next group's first task
# commit; the rest, up to HEAD, is the layer "<branch>" itself. A plan with one group or without a Group column is
# one layer, and so is a plan whose history does not show where a group starts (a note goes to stderr).
# shellcheck disable=SC2154
feature_layers() {
  _fl_top=$(git rev-parse HEAD)
  _fl_groups=$(group_list)
  if ! plan_has_groups "$state" || [ "$(printf '%s\n' "$_fl_groups" | grep -c .)" -le 1 ]; then
    printf '%s\t%s\t%s\n' "$1" "$_fl_top" "$(printf '%s\n' "$_fl_groups" | tail -n 1)"
    return 0
  fi
  _fl_mb=$(merge_base)
  _fl_previous=$_fl_mb _fl_out="" _fl_last=""
  for _fl_group in $_fl_groups; do
    if [ -n "$_fl_last" ]; then
      [ -n "$(group_rows "$_fl_group" | awk -F '|' '$4 == 0')" ] || break
      _fl_end=$(group_from "$_fl_group")
      if [ "$_fl_end" = "$_fl_mb" ] || [ "$_fl_end" = "$_fl_previous" ] || ! git merge-base --is-ancestor "$_fl_previous" "$_fl_end" 2>/dev/null; then
        echo "no commit shows where group $_fl_group starts; the feature is one layer." >&2
        printf '%s\t%s\t%s\n' "$1" "$_fl_top" "$(printf '%s\n' "$_fl_groups" | tail -n 1)"
        return 0
      fi
      _fl_out=$(printf '%s%s-g%s\t%s\t%s\n_' "$_fl_out" "$1" "$_fl_last" "$_fl_end" "$_fl_last")
      _fl_out=${_fl_out%_}
      _fl_previous=$_fl_end
    fi
    _fl_last=$_fl_group
  done
  printf '%s%s\t%s\t%s\n' "$_fl_out" "$1" "$_fl_top" "$_fl_last"
}

# The build lock's pid file: the build's pid, that process's start time and the build's run. A reused pid never passes
# for a build, because its start time differs.
build_lock=.work/autopilot/lock
process_start() { LC_ALL=C TZ=UTC ps -p "$1" -o lstart= 2>/dev/null; }
lock_pid() { sed -n 1p "$build_lock/pid" 2>/dev/null; }
lock_run() { sed -n 3p "$build_lock/pid" 2>/dev/null; }
is_build() {
  [ -n "$1" ] || return 1
  _process_start=$(process_start "$1")
  [ -n "$_process_start" ] && [ "$_process_start" = "$(sed -n 2p "$build_lock/pid" 2>/dev/null)" ]
}
