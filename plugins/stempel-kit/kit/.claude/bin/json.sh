# JSON in and out for the hooks, without jq (POSIX sh). Sourced by the core's hooks/lib.sh and the extensions' hooks.
# shellcheck shell=sh

# json_string <key>: the string value of a key in the hook input (last occurrence), with the common escapes undone.
# Good enough for paths and commands; not a general JSON parser.
json_string() {
  printf '%s' "$HOOK_INPUT" | tr '\n' ' ' |
    sed -nE 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' |
    sed -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\[nt]/ /g' -e 's/\\\\/\\/g'
}

# json_escape: stdin as the body of a JSON string (without the surrounding quotes), without colour codes.
json_escape() {
  esc=$(printf '\033')
  sed "s/${esc}\[[0-9;]*[A-Za-z]//g" | tr -d '\000-\010\013\014\016-\037' |
    awk 'BEGIN { ORS = "" } { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, ""); if (NR > 1) print "\\n"; print }'
}

# kit_hook_start: how every hook starts, in the core and in the extensions: work from the project root
# ($CLAUDE_PROJECT_DIR, else KIT_ROOT), load the package lookup and kit.conf (the environment wins for the
# approval, gate, budget and improve variables), and read the hook input into HOOK_INPUT. The core's hooks have
# sourced their own conf.sh already; an extension's hook takes the project's, and does nothing without it.
kit_hook_start() {
  KIT_ROOT=${CLAUDE_PROJECT_DIR:-${KIT_ROOT:-$PWD}}
  cd "$KIT_ROOT" || exit 1
  if ! command -v conf_value >/dev/null 2>&1; then
    [ -f ./.claude/bin/conf.sh ] || exit 0
    # shellcheck source=conf.sh
    . ./.claude/bin/conf.sh
  fi
  _kit_env=$(export -p | grep -E '^(export|declare -x) KIT_(APPROVAL|GATE_[A-Z]+|BUDGET_TOKENS|IMPROVE)=')
  # shellcheck source=/dev/null
  [ ! -f .claude/kit.conf ] || . ./.claude/kit.conf
  eval "$_kit_env"
  # shellcheck disable=SC2034 # read by json_string
  HOOK_INPUT=$(cat)
}

# state_file <name>: the per-session state file under .work/ (gitignored).
state_file() {
  sid=$(json_string session_id | tr -cd 'A-Za-z0-9_-')
  mkdir -p .work
  [ -f .work/.gitignore ] || printf '*\n!.gitignore\n' >.work/.gitignore
  printf '.work/session-%s.%s' "${sid:-unknown}" "$1"
}

# relative_path <path>: the path relative to the project root, or empty if the file is outside it.
relative_path() {
  case $1 in "$KIT_ROOT"/*) printf '%s' "${1#"$KIT_ROOT"/}" ;; /*) ;; *) printf '%s' "$1" ;; esac
}
