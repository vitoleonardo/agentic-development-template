# Start of every core hook. POSIX sh, no jq or other runtime needed. The helpers live in .claude/bin/json.sh and
# .claude/bin/conf.sh, where the hooks of the extensions find them too.
# shellcheck shell=sh

# shellcheck disable=SC2034 # read by kit_hook_start
KIT_ROOT=${CLAUDE_PROJECT_DIR:-$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)}
# shellcheck source=../bin/json.sh
. "$(dirname -- "$0")/../bin/json.sh"
kit_hook_start
