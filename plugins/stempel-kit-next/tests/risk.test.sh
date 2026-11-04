#!/bin/sh
# Tests for .claude/bin/risk (specs/risk-gates.md). Run: sh plugins/stempel-kit-next/tests/risk.test.sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
project=$work/project
mkdir -p "$project"
cp -R "$here/kit/." "$project/"
cd "$project" || exit 1

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
same() { if [ "$1" = "$2" ]; then ok; else fail "$3: got '$1', wanted '$2'"; fi; }
contains() { case $1 in *"$2"*) ok ;; *) fail "$3: no '$2' in: $1" ;; esac; }
g() { git -c user.name=t -c user.email=t@example.invalid "$@"; }

cat >.claude/kit.conf <<'EOF'
KIT_SOURCE_PATTERNS="*.ts"
KIT_MAX_CHANGED_LINES="100"
KIT_PUSH_ASK_PATTERNS="*auth*"
KIT_ARCHITECTURE_PATTERNS="src/core/* docs/adr/*"
KIT_CONTRACT_PATTERNS="src/api/*"
KIT_E2E_MAP=".kit/e2e-map.tsv"
EOF
printf '.work/\n' >.gitignore
mkdir -p src/app src/api src/auth src/core
printf 'export const a = 1;\n' >src/app/a.ts
g init -q -b main
g add -A
g commit -qm base

# change <branch> <file> <lines>: a branch off main whose one commit writes <lines> lines to <file>.
change() {
  git checkout -q main
  git checkout -qb "$1"
  mkdir -p "$(dirname "$2")"
  seq 1 "$3" | sed 's/^/export const x/;s/$/ = 1;/' >"$2"
  g add -A
  g commit -qm "$1"
}
rank() { out=$(.claude/bin/risk "$@" 2>&1); code=$?; }
first() { printf '%s\n' "$out" | head -n 1; }

# --- the diff -------------------------------------------------------------------------

change small src/app/b.ts 20
rank diff
same "$(first)" "risk 0 low" "RISK-AC9: a small change outside every pattern is low"
same "$code" 0 "a low rank exits 0"
rank diff
second=$out
rank diff
same "$out" "$second" "RISK-AC14: the same diff gets the same rank"

change auth src/auth/session.ts 5
rank diff
contains "$(first)" "high" "RISK-AC6: a file in KIT_PUSH_ASK_PATTERNS is high"
contains "$out" "src/auth/session.ts" "RISK-AC6: the reason names the file"
same "$code" 1 "a high rank exits 1"

change core src/core/queue.ts 5
rank diff
contains "$(first)" "high" "RISK-AC7: a file in KIT_ARCHITECTURE_PATTERNS is high"
contains "$out" "src/core/queue.ts" "RISK-AC7: the reason names the file"

for own in .github/workflows/ci.yml .claude/rules/extra.md .kit/e2e-map.tsv .kit/mutation-exceptions.tsv; do
  change "own-$(printf '%s' "$own" | tr -c 'a-z' '-')" "$own" 2
  rank diff
  contains "$(first)" "high" "RISK-AC8: a change to $own is high"
  contains "$out" "$own" "RISK-AC8: the reason names $own"
done

change big src/app/big.ts 150
rank diff
contains "$out" "150 changed lines, over KIT_MAX_CHANGED_LINES (100)" "RISK-AC10: the changed lines and the limit"

change snapshots drizzle/meta/0001_snapshot.json 150
rank diff
same "$(first)" "risk 0 low" "drizzle's generated migration snapshots do not count toward the changed lines"

git checkout -q main
git checkout -qb deps
printf '{\n  "dependencies": { "zod": "4.0.0" }\n}\n' >package.json
g add -A
g commit -qm deps
rank diff
contains "$out" "dependencies change: package.json" "RISK-AC11: a manifest change is named"

change api src/api/route.ts 5
rank diff
contains "$out" "a public contract changes: src/api/route.ts" "a contract path scores"

git checkout -q main
git checkout -qb spread
for d in a b c d e; do mkdir -p "src/$d"; printf 'x\n' >"src/$d/f.ts"; done
g add -A
g commit -qm spread
rank diff
contains "$out" "the change spreads over 5 areas" "the areas a change touches score"

git checkout -q main
git checkout -qb renamed
mkdir -p src/core
git mv src/app/a.ts src/core/a.ts
g commit -qm rename
rank diff
contains "$(first)" "high" "RISK-AC47: a rename into KIT_ARCHITECTURE_PATTERNS is high"

# The run's signals from the state file.
git checkout -q small
mkdir -p .work
printf '# Plan: x (spec: specs/x.md)\n\n## Stops\n- task 2 | tier | failed | retried deep | open\n\n## Rounds\n- review 2 | full | a..b | 1 high open\n\n## Decisions to review\n' >.work/small.md
rank diff
contains "$out" "1 task retries a tier higher failed" "RISK-AC13: a failed retry is a reason"
contains "$out" "1 review rounds ended with high findings" "RISK-AC13: a round with high findings is a reason"

printf 'KIT_RISK_HUMAN="4"\n' >>.claude/kit.conf
rank diff
contains "$(first)" "risk 4 high" "RISK-AC15: a score at the human threshold is high"
git checkout -q .claude/kit.conf

# --- the plan -------------------------------------------------------------------------

git checkout -q main
plan_file=$work/plan.md
mkplan() {
  {
    printf '# Plan: invite (spec: specs/invite.md)\n\n## Design\n- Architecture: %s\n- Estimate: %s lines\n- Side effects: none\n\n## Tasks\n' "$1" "$2"
    printf '| # | Task | Files | Criteria | Test cases | Depends on | Tier | Group |\n|---|---|---|---|---|---|---|---|\n'
    printf '| 1 | form | `src/app/form.ts` | INVITE-AC1 | c | - | %s | A |\n' "${3:-standard}"
    printf '\n## Progress\n- [ ] 1 form\n'
  } >"$plan_file"
}
mkplan none 120
rank plan "$plan_file"
same "$(first)" "risk 2 low" "RISK-AC17: a small plan without architecture change is low"
mkplan 'a new queue between the API and the mailer' 120
rank plan "$plan_file"
contains "$(first)" "high" "RISK-AC16: an architecture change is high"
contains "$out" "a new queue between the API and the mailer" "RISK-AC16: the reason quotes it"
mkplan none 120 deep
rank plan "$plan_file"
contains "$out" "1 of 1 tasks need the deep tier" "deep tasks score"
mkplan none 300
rank plan "$plan_file"
contains "$out" "300 changed lines, over twice KIT_MAX_CHANGED_LINES (100)" "the estimate scores"

# --- the stack ------------------------------------------------------------------------

git checkout -q main
git checkout -qb 12-invite
mkdir -p .work
printf '# Plan: invite (spec: specs/invite.md)\nBase: main\n\n## Tasks\n| # | Task | Files | Criteria | Test cases | Depends on | Tier | Group |\n|---|---|---|---|---|---|---|---|\n| 1 | a | f | c | c | - | standard | A |\n| 2 | b | f | c | c | - | standard | B |\n\n## Progress\n- [x] 1 a\n- [x] 2 b\n\n## Rounds\n' >.work/12-invite.md
printf 'export const a = 2;\n' >src/app/one.ts; g add -A; g commit -qm "task 1: one"
mkdir -p src/auth; printf 'export const s = 1;\n' >src/auth/login.ts; g add -A; g commit -qm "task 2: login"
rank stack
same "$(first)" "risk 0 high" "RISK-AC25: the stack is high when one layer is high"
contains "$out" "layer 12-invite-gA 0 low" "each layer has its own rank"
contains "$out" "layer 12-invite 0 high" "the layer with the risky file is high"
contains "$out" "src/auth/login.ts is in KIT_PUSH_ASK_PATTERNS" "and names the file"
same "$code" 1 "a high stack exits 1"

# --- settings, templates and CI -------------------------------------------------------

settings=$here/kit/.claude/settings.json
grep -qF '"Bash(gh pr review *)"' "$settings" && grep -qF '"Bash(gh api *reviews*)"' "$settings" && ok || fail "RISK-AC42: sessions cannot approve reviews"
grep -qF '"Bash(gh pr merge *)"' "$settings" && grep -qF '"Bash(gh stack merge *)"' "$settings" && ok || fail "RISK-AC31: a session's merge asks"
for conf in "$here/kit/.claude/kit.conf" "$here"/adapters/*/.claude/kit.conf; do
  grep -qx 'KIT_APPROVAL="autonomous"' "$conf" && ok || fail "RISK-AC4: $conf sets KIT_APPROVAL=autonomous"
done
workflow=$here/adapters/typescript/.github/workflows/risk.yml
grep -q '^  pull_request_target:' "$workflow" && grep -q '^  pull_request_review:' "$workflow" && ok || fail "RISK-AC34: risk.yml runs on pull_request_target and on reviews"
grep -qF 'ref: ${{ github.event.pull_request.base.sha }}' "$workflow" && ok || fail "RISK-AC34: risk.yml checks out the base branch's files"
grep -qF '.user.login != \"$AUTHOR\"' "$workflow" && ok || fail "RISK-AC37: the author's own approval does not count"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
