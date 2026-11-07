# Start of every core hook (POSIX sh, no jq). The helpers live in .claude/bin/conf.sh and .claude/bin/json.sh,
# where the hooks of the extensions find them too; a core hook takes its own copies, so a plugin update never
# runs against older project scripts.
# shellcheck shell=sh

KIT_ROOT=${CLAUDE_PROJECT_DIR:-$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)}
cd "$KIT_ROOT" || exit 1
# shellcheck source=../bin/conf.sh
. "$(dirname -- "$0")/../bin/conf.sh"
# shellcheck source=../bin/json.sh
. "$(dirname -- "$0")/../bin/json.sh"
kit_hook_start
