#!/bin/sh
# Headless /fix-bug on a copy of the demo app (specs/fix-bug.md: the covered and the gap case).
# Needs Claude Code, Node, the Playwright Chromium build, and spends tokens, so it is not part of CI.
# Run: sh plugins/agentic-workflow-kit/tests/fix-bug/run.sh [model] [covered|gap|all]   (FIXBUG_E2E_PORT, default 3419)
# The remote is a bare repository in the temp folder, so nothing leaves the machine. bypassPermissions stands
# in for the user approving each command; KIT_APPROVAL=autonomous answers the gates (push included, so the pack
# reaches the bare remote; a headless session cannot answer an ask gate), and the prompt forbids pushing the branch.
# shellcheck disable=SC2034 # $code is read inside the conditions that check() evaluates
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
model=${1:-sonnet}
cases=${2:-all}
failed=0
check() { if eval "$2"; then echo "ok:   $1"; else echo "FAIL: $1"; failed=$((failed + 1)); fi; }

# fresh <name>: a copy of the demo app with the kit, on main, with a bare origin. Sets $repo and $log.
fresh() {
  work=$(mktemp -d)
  repo=$work/demo
  log=$work/transcript.jsonl
  echo "== $1: working in $work (kept for inspection)"
  cp -R "$here/examples/demo-app" "$repo"
  rm -rf "$repo/node_modules" "$repo/.next" "$repo/.work"
  "$here/install.sh" "$repo" --adapter typescript --preset nextjs >/dev/null
  cd "$repo" || exit 1
  npm ci >/dev/null 2>&1
  # The demo ships without jscpd; the duplicates gate is "not configured" without it and verify stops there.
  npm install --save-dev --no-audit --no-fund jscpd@5 >/dev/null 2>&1
  git init -q -b main
  git add -A
  git -c user.name=t -c user.email=t@example.invalid commit -qm "demo with kit"
  git init -q --bare "$work/remote.git"
  git remote add origin "$work/remote.git"
  started=''
  session=$(python3 -I -c 'import uuid; print(uuid.uuid4())')
}

turn() {
  if [ -z "$started" ]; then
    set -- --session-id "$session" "$@"
    started=1
  else
    set -- --resume "$session" "$@"
  fi
  KIT_APPROVAL=autonomous KIT_GATE_PUSH=auto E2E_PORT=${FIXBUG_E2E_PORT:-3419} KIT_BASE=main \
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

# run_fix <report>: /fix-bug on the report, then continue until the PR description exists or six turns passed.
run_fix() {
  turn "/fix-bug $1"
  for i in 1 2 3 4 5 6; do
    branch=$(git branch --show-current)
    [ -f ".work/$branch-pr.md" ] && break
    turn "Continue. When verify asks, push the evidence pack. Do not push the branch and do not create a pull request."
  done
  branch=$(git branch --show-current)
  state=.work/$branch.md
  agents=.work/$branch/agents.tsv
}

# common_checks <spec criterion>: what every fix run must leave behind.
common_checks() {
  check "on a fix branch, not the feature's (FIXBUG-AC10)" '[ "$branch" != main ] && [ "$branch" != expense-split ]'
  check "the plan's title names the spec" 'head -n 1 "$state" | grep -q "(spec: specs/expense-split.md)"'
  check "## Criteria holds $1 and nothing else (FIXBUG-AC4)" '[ "$(.claude/bin/features.sh 2>/dev/null; . .claude/bin/features.sh; plan_criteria "$state")" = "'"$1"'" ]'
  check "## Bug has Source, Reproduce, Expected and Observed (FIXBUG-AC1)" 'for k in Source Reproduce Expected Observed; do grep -q "^- $k:" "$state" || exit 1; done'
  check "task 1 went to the test-writer as reproduce (FIXBUG-AC12)" 'grep -i "task 1: reproduce" "$agents" | grep -q test-writer'
  check "task 2 went to the implementer as fix (FIXBUG-AC14)" 'grep -i "task 2: fix" "$agents" | grep -q implementer'
  check "no simplify dispatch (FIXBUG-AC18)" '! grep -qi "	simplify" "$agents"'
  check "review round 1 ran (FIXBUG-AC19)" 'grep -q "review round 1" "$agents"'
  check "the fix commit holds the red test and the fix together (FIXBUG-AC17)" 'first=$(git rev-list --reverse main..HEAD | head -n 1); git show --stat --format= "$first" | grep -q "settle.test.ts\|parse.test.ts" && git show --stat --format= "$first" | grep -q "src/features/split/[a-z]*\.ts "'
  check "the red test is named after the criterion" 'git diff main..HEAD -- src e2e | grep "^+" | grep -q "'"$1"'"'
  check "the feature list is unchanged (FIXBUG-AC10)" '[ -z "$(git diff main..HEAD -- specs/README.md)" ]'
  check "the evidence pack is on kit-evidence for the head" '.claude/bin/evidence ci-check --head "$(git rev-parse HEAD)" --key "$branch" >/dev/null'
  check "the PR description exists and its Why names the report (FIXBUG-AC21)" '[ -s ".work/$branch-pr.md" ] && awk "/^## Why/{p=1;next} /^## /{p=0} p" ".work/$branch-pr.md" | grep -qi "report\|issue"'
  check "status reads the fix plan" '.claude/bin/status --line | grep -q "^expense-split · pr"'
  check "plan-lint passes on the plan (FIXBUG-AC9)" '.claude/bin/plan-lint "$state" >/dev/null'
}

if [ "$cases" = covered ] || [ "$cases" = all ]; then
  fresh covered
  # Plant the bug: every transfer is capped at 10.00, so a larger debt becomes several transfers between the
  # same two people, and the test that pinned SPLIT-AC5 is gone.
  sed -i 's/const amountCents = Math.min(creditors\[c\]\[1\], debtors\[d\]\[1\]);/const amountCents = Math.min(creditors[c][1], debtors[d][1], 1000);/' src/features/split/settle.ts
  python3 -I - src/features/split/settle.test.ts <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s2 = re.sub(r'\n  it\("SPLIT-AC5:.*?\n  \}\);\n', '\n', s, count=1, flags=re.S)
assert s2 != s
p.write_text(s2)
PY
  grep -q '1000);' src/features/split/settle.ts && ! grep -q SPLIT-AC5 src/features/split/settle.test.ts || { echo "planting failed"; exit 1; }
  npm test >/dev/null 2>&1 || { echo "the planted bug must leave the suite green"; exit 1; }
  git -c user.name=t -c user.email=t@example.invalid commit -qam "cap transfers"
  git push -q origin main
  run_fix "With the input 'Alice paid 90 for Alice, Bob, Carol' the page shows 6 transfers of 10.00: three from Bob to Alice and three from Carol to Alice. SPLIT-AC5 says at most n - 1 transfers, so 2 here: Bob pays Alice 30.00 and Carol pays Alice 30.00."
  common_checks SPLIT-AC5
  check "the spec is unchanged (FIXBUG-AC5)" '[ -z "$(git diff main..HEAD -- specs/expense-split.md)" ]'
  check "the cap is gone" '! grep -q "1000);" src/features/split/settle.ts'
  echo "covered: transcript $log"
fi

if [ "$cases" = gap ] || [ "$cases" = all ]; then
  fresh gap
  git push -q origin main
  run_fix "The line 'Alice paid 30,50 for Alice, Bob' is rejected with 'Line 1: write it as \"Alice paid 30.50 for Alice, Bob\".' Everyone here writes amounts with a decimal comma; 30,50 must count as 30.50."
  common_checks SPLIT-AC7
  check "the spec gained exactly one criterion, SPLIT-AC7 (FIXBUG-AC6)" '[ "$(git diff main..HEAD -- specs/expense-split.md | grep -c "^+- \*\*SPLIT-AC")" -eq 1 ] && git diff main..HEAD -- specs/expense-split.md | grep -q "^+- \*\*SPLIT-AC7\*\*"'
  check "the spec gained one Decisions entry (FIXBUG-AC6)" '[ "$(git diff main..HEAD -- specs/expense-split.md | grep -c "^+- [0-9][0-9]\.[0-9][0-9]\.20[0-9][0-9]:")" -eq 1 ]'
  check "spec-lint passes on the amended spec (FIXBUG-AC6)" '.claude/bin/spec-lint specs/expense-split.md >/dev/null'
  check "gate spec was logged under Decisions to review (FIXBUG-AC7)" 'awk "/^## Decisions to review/{p=1;next} /^## /{p=0} p" "$state" | grep -qi "^- spec"'
  echo "gap: transcript $log"
fi

echo "$failed failed."
[ "$failed" -eq 0 ]
