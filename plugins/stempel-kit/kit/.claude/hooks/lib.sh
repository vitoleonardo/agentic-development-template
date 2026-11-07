# Start of every core hook. POSIX sh, no jq or other runtime needed. The helpers live in .claude/bin/json.sh and
# .claude/bin/conf.sh, where the hooks of the extensions find them too.
# shellcheck shell=sh

KIT_ROOT=${CLAUDE_PROJECT_DIR:-$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)}
cd "$KIT_ROOT" || exit 1
# The hook's own helpers, so a plugin update never runs against older project scripts.
# shellcheck source=../bin/conf.sh
. "$(dirname -- "$0")/../bin/conf.sh"
# shellcheck source=../bin/json.sh
. "$(dirname -- "$0")/../bin/json.sh"
kit_hook_start
