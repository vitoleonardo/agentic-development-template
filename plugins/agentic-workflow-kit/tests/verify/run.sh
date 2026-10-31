#!/bin/sh
# Headless /ship-feature with /verify-feature on a copy of the demo app (VERIFY-AC1, AC2, AC6).
# Needs Claude Code, Node, the Playwright Chromium build, and spends tokens, so it is not part of CI.
# Run: sh plugins/agentic-workflow-kit/tests/verify/run.sh [model]
# The remote is a bare repository in the temp folder, so nothing leaves the machine. bypassPermissions stands
# in for the user approving each command; the scripted answers say what to approve.
# shellcheck disable=SC2034 # $code is read inside the conditions that check() evaluates
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
export E2E_PORT=3418 KIT_BASE=main
git init -q -b main
git add -A
git -c user.name=t -c user.email=t@example.invalid commit -qm "demo with kit"
git init -q --bare "$work/remote.git"
git remote add origin "$work/remote.git"
git push -q origin main

session=$(python3 -I -c 'import uuid; print(uuid.uuid4())')
turn() {
  if [ -z "${started:-}" ]; then
    set -- --session-id "$session" "$@"
    started=1
  else
    set -- --resume "$session" "$@"
  fi
  claude -p --model "$model" --permission-mode bypassPermissions --settings .claude/settings.json \
    --output-format stream-json --verbose "$@" >>"$log" 2>&1
  python3 -I -c 'import json,sys
last = ""
for line in open(sys.argv[1]):
    try: d = json.loads(line)
    except ValueError: continue
    if d.get("type") == "result": last = d.get("result", "")
print(last[-1200:])' "$log"
  echo "-----"
}

turn "/ship-feature After a split, show the total of all expenses as 'Total spent: <amount>' below the transfers."
turn "Use your recommended answer for every open question. The spec is approved."
turn "The plan is approved. Approved dependencies: none. Build it."
for i in 1 2 3 4 5 6; do
  branch=$(git branch --show-current)
  [ -f ".work/$branch-pr.md" ] && break
  turn "Continue. When verify asks, push the evidence pack. Do not push the branch and do not create a pull request."
done

failed=0
check() { if eval "$2"; then echo "ok:   $1"; else echo "FAIL: $1"; failed=$((failed + 1)); fi; }
branch=$(git branch --show-current)
pack=.work/$branch/evidence
head=$(git rev-parse HEAD)
check "on a feature branch" '[ "$branch" != main ]'
for part in evidence.json gates.md edge-cases.md data-runs.md review.md; do
  check "the pack has $part (VERIFY-AC1)" '[ -s "$pack/$part" ]'
done
check "desktop and mobile screenshots on the branch (VERIFY-AC1)" 'ls "$pack"/screenshots/*-desktop.png "$pack"/screenshots/*-mobile.png >/dev/null 2>&1'
check "screenshots on main next to them (VERIFY-AC1)" 'ls "$pack"/screenshots/*.main.png >/dev/null 2>&1'
check "the reviewer judged the screenshots" '[ -s "$pack/screenshots-review.md" ]'
check "evidence.json names the head commit" 'grep -q "\"head\": \"$head\"" "$pack/evidence.json"'
check "the pack is on kit-evidence for the head (VERIFY-AC5 path)" '.claude/bin/evidence ci-check --head "$head" --key "$branch" >/dev/null'
check "the matrix passes" '.claude/bin/evidence matrix >/dev/null'
check "the PR description uses the pack" 'grep -qi "5 minutes" ".work/$branch-pr.md"'
.claude/bin/evidence comment --dir "$pack" --repo me/demo --key "$branch" >"$work/comment.md"
check "the comment has the gate table and a screenshot (VERIFY-AC6, rendered locally)" 'grep -q "| typecheck |" "$work/comment.md" && grep -q "!\[" "$work/comment.md"'

# VERIFY-AC2: a wrong label fails the e2e assertion, and the reviewer flags it from the screenshot alone.
git stash -q -u 2>/dev/null
git checkout -q -b wrong-label
grep -rl "Total spent" src >"$work/label-files"
if [ -s "$work/label-files" ]; then
  xargs sed -i 's/Total spent/Sum of costs/' <"$work/label-files"
  git -c user.name=t -c user.email=t@example.invalid commit -qam "wrong label"
  npm run e2e >"$work/e2e-wrong.log" 2>&1
  code=$?
  check "the e2e assertion fails on the wrong label (VERIFY-AC2)" '[ "$code" -ne 0 ]'
  EVIDENCE_DIR=$work/wrong .claude/bin/evidence screenshots --no-base >/dev/null 2>&1
  claude -p --model "$model" --permission-mode bypassPermissions --settings .claude/settings.json \
    "Use the reviewer agent to review the screenshots in $work/wrong/screenshots against specs/expense-split.md, as its agent file describes. Return its report." \
    >"$work/review-wrong.md" 2>&1
  check "the reviewer flags the wrong label from the screenshots (VERIFY-AC2)" 'grep -qi "mismatch" "$work/review-wrong.md" && grep -qi "high" "$work/review-wrong.md"'
else
  check "the feature shows 'Total spent'" 'false'
fi

echo "$failed failed. Transcript: $log"
[ "$failed" -eq 0 ]
