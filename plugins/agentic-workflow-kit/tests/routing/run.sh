#!/bin/sh
# Headless model-routing run on a copy of the demo app (ROUTE-AC1), and whether a forked skill fires
# SubagentStop. Needs Claude Code and Node, and spends tokens, so it is not part of CI.
# Run: sh plugins/agentic-workflow-kit/tests/routing/run.sh [model]
# shellcheck disable=SC2034 # variables are read inside the conditions that check() evaluates
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
model=${1:-sonnet}
work=$(mktemp -d)
repo=$work/demo
log=$work/transcript.jsonl
echo "Working in $work (kept for inspection)"

cp -R "$here/examples/demo-app" "$repo"
rm -rf "$repo/node_modules" "$repo/.next" "$repo/.work"
"$here/install.sh" "$repo" --adapter typescript --preset nextjs >/dev/null
cd "$repo" || exit 1
npm ci >/dev/null 2>&1
export E2E_PORT=3419 KIT_BASE=main
git init -q -b main
git add -A
git -c user.name=t -c user.email=t@example.invalid commit -qm "demo with kit"

session=$(python3 -I -c 'import uuid; print(uuid.uuid4())')
turn() {
  if [ -z "${started:-}" ]; then set -- --session-id "$session" "$@"; started=1; else set -- --resume "$session" "$@"; fi
  claude -p --model "$model" --permission-mode bypassPermissions --settings .claude/settings.json \
    --output-format stream-json --verbose "$@" >>"$log" 2>&1
  python3 -I -c 'import json,sys
last = ""
for line in open(sys.argv[1]):
    try: d = json.loads(line)
    except ValueError: continue
    if d.get("type") == "result": last = d.get("result", "")
print(last[-1000:])' "$log"
  echo "-----"
}

turn "/ship-feature Above the transfers, show how many people the expenses involve, as 'People: <n>'."
turn "Use your recommended answer for every open question. The spec is approved."
turn "The plan is approved. Approved dependencies: none. Build every task, then stop before simplify and review and report the tasks and the models you dispatched them on."

failed=0
check() { if eval "$2"; then echo "ok:   $1"; else echo "FAIL: $1"; failed=$((failed + 1)); fi; }
branch=$(git branch --show-current)
plan=.work/$branch.md
check "the plan has a Tier column (ROUTE-AC1)" 'grep -q "| Tier |" "$plan"'
agents=.work/$branch/agents.tsv
usage=.work/$branch/usage.tsv
check "implementers were recorded with their task" 'grep -q "implementer" "$agents"'
# Each implementer's requested model is the alias for its task's tier, and its tokens were spent on that model.
awk -F '\t' '$3 ~ /implementer$/ { print $1 "\t" $2 "\t" $4 "\t" $5 }' "$agents" >"$work/implementers"
cat "$work/implementers"
mismatch=0
while IFS="$(printf '\t')" read -r id desc requested resolved; do
  task=$(printf '%s' "$desc" | sed -nE 's/^task ([0-9]+).*/\1/p')
  tier=$(awk -F '|' -v t="$task" '$2 ~ "^ *" t " *$" { gsub(/ /, "", $(NF - 1)); print $(NF - 1); exit }' "$plan")
  case $desc in *retry*) tier=$(.claude/bin/route up "$tier") ;; esac
  want=$(.claude/bin/route "${tier:-standard}" 2>/dev/null)
  ran=$(awk -F '\t' -v id="$id" '$1 == id { print $2 }' "$usage" | head -n 1)
  echo "task ${task:-?} tier ${tier:-?}: requested $requested, resolved $resolved, transcript $ran"
  [ "$requested" = "$want" ] && case $ran in *"$want"*) true ;; *) false ;; esac || mismatch=$((mismatch + 1))
done <"$work/implementers"
check "each implementer ran on its task's tier (ROUTE-AC1)" '[ -s "$work/implementers" ] && [ "$mismatch" -eq 0 ]'
check "the main session's tokens are recorded" 'grep -q "^main" "$usage"'

# Does a forked skill (context: fork) fire SubagentStop? Then usage.tsv gains an agent with no Agent dispatch.
before=$(cut -f1 "$usage" | sort -u | grep -vc '^main$')
claude -p --model "$model" --permission-mode bypassPermissions --settings .claude/settings.json "/review-diff main" >"$work/review.md" 2>&1
after=$(cut -f1 "$usage" | sort -u | grep -vc '^main$')
if [ "$after" -gt "$before" ]; then
  echo "finding: the forked /review-diff fired SubagentStop; its tokens are recorded ($before -> $after agents)"
else
  echo "finding: the forked /review-diff did not add a usage line; forked skills are not counted ($before -> $after agents)"
fi

echo "$failed failed. Transcript: $log"
[ "$failed" -eq 0 ]
