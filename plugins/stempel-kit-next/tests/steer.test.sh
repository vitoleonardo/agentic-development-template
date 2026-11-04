#!/bin/sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT
cp -R "$here/kit/." "$project/"
cd "$project" || exit 1
git init -q -b 12-export
export CLAUDE_PROJECT_DIR="$project"
unset KIT_AUTOPILOT_RUN

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
same() { if [ "$1" = "$2" ]; then ok; else fail "$3: got '$1', wanted '$2'"; fi; }
contains() { case $1 in *"$2"*) ok ;; *) fail "$3: '$2' not in '$1'" ;; esac; }

inbox=.work/autopilot/steer
main_call='{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}'
subagent_call='{"session_id":"s1","agent_id":"a7","agent_type":"implementer","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"src/a.ts"}}'

queue() {
  mkdir -p "$inbox"
  printf '%s\n' "$2" >"$inbox/$1.md"
}
hook() { printf '%s' "$1" | KIT_AUTOPILOT_RUN=${2-20261102-140000} .claude/hooks/steer; }
pending() { find "$inbox" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' '; }

queue 20261102-140000-1793600000-0001 'keep the CSV columns as in the spec'
queue 20261102-140000-1793600005-0002 'skip the "dark" mode'
out=$(hook "$main_call")
printf '%s' "$out" | python3 -I -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && ok || fail "STEER-AC14: the hook prints valid JSON: $out"
context=$(printf '%s' "$out" | python3 -I -c 'import json,sys; d=json.load(sys.stdin)["hookSpecificOutput"]; print(d["hookEventName"]); print(d["additionalContext"])' 2>/dev/null)
same "$(printf '%s\n' "$context" | sed -n 1p)" PostToolUse "STEER-AC14: the output is PostToolUse additional context"
same "$(printf '%s\n' "$context" | sed -n 2p)" "The person watching this autopilot run says:" "STEER-AC14: the context starts with the watcher's words"
same "$(printf '%s\n' "$context" | sed -n 3p)" "- keep the CSV columns as in the spec" "STEER-AC14: the older message comes first"
same "$(printf '%s\n' "$context" | sed -n 4p)" '- skip the "dark" mode' "STEER-AC14: the newer message comes second, quotes kept"
contains "$context" "steered-by-user | <text> | <what you did>" "STEER-AC14: the context asks to log each message under Decisions to review"
same "$(pending)" 0 "STEER-AC14: both messages leave the inbox"
same "$(find "$inbox/delivered" -name '*.md' | wc -l | tr -d ' ')" 2 "STEER-AC14: both messages are delivered"

same "$(hook "$main_call")" "" "STEER-AC15: a delivered message is not delivered again"

queue 20261102-140000-1793600010-0003 'add the header row'
same "$(hook "$subagent_call")" "" "STEER-AC16: a subagent's tool call gets no message"
same "$(pending)" 1 "STEER-AC16: the message stays undelivered after a subagent's call"

same "$(printf '%s' "$main_call" | .claude/hooks/steer)" "" "STEER-AC17: a session autopilot did not start gets no message"
same "$(hook "$main_call" '')" "" "STEER-AC17: an empty run gets no message"
same "$(pending)" 1 "STEER-AC17: the message stays undelivered outside autopilot"

queue 20261101-090000-1793500000-0001 'from yesterday'
contains "$(hook "$main_call")" "add the header row" "STEER-AC18: the current run's message is delivered"
same "$(pending)" 1 "STEER-AC18: an earlier run's message stays undelivered"
same "$(hook "$main_call")" "" "STEER-AC18: an earlier run's message is never delivered"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
