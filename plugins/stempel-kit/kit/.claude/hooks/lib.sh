# Shared helpers for the kit's hooks. POSIX sh, no jq or other runtime needed.
# shellcheck shell=sh

KIT_ROOT=${CLAUDE_PROJECT_DIR:-$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)}
cd "$KIT_ROOT" || exit 1

# shellcheck source=../bin/conf.sh
. "$(dirname -- "$0")/../bin/conf.sh"
# shellcheck source=../bin/json.sh
. "$(dirname -- "$0")/../bin/json.sh"
kit_from_environment=$(export -p | grep -E '^(export|declare -x) KIT_(APPROVAL|GATE_[A-Z]+|BUDGET_TOKENS|IMPROVE)=')
if [ -f .claude/kit.conf ]; then
  # shellcheck source=/dev/null
  . ./.claude/kit.conf
fi
eval "$kit_from_environment"

# file_value <path relative to the root> <variable>: the variable from the config of the file's package.
# In a monorepo a package's .claude/kit.conf decides its own source and test patterns.
file_value() {
  conf_value "$(package_of "$1")" "$2"
}

# Hook input arrives as one JSON document on stdin.
# shellcheck disable=SC2034 # read by json_string and json_bool in .claude/bin/json.sh
HOOK_INPUT=$(cat)

# Per-session state files under .work/ (gitignored).
state_file() {
  sid=$(json_string session_id | tr -cd 'A-Za-z0-9_-')
  mkdir -p .work
  [ -f .work/.gitignore ] || printf '*\n!.gitignore\n' >.work/.gitignore
  printf '.work/session-%s.%s' "${sid:-unknown}" "$1"
}

# Path relative to the project root, or empty if the file is outside it.
relative_path() {
  case $1 in
    "$KIT_ROOT"/*) printf '%s' "${1#"$KIT_ROOT"/}" ;;
    /*) ;;
    *) printf '%s' "$1" ;;
  esac
}

kit_check() {
  if [ "$1" = typecheck ] && [ -f .claude/baseline.tsv ]; then
    .claude/bin/check --against-baseline typecheck
  else
    .claude/bin/check "$@"
  fi
}
