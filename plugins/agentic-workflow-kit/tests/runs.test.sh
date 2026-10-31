#!/bin/sh
# Tests for the run records (.claude/bin/runs) and `usage tsv`.
# Run: sh plugins/agentic-workflow-kit/tests/runs.test.sh
#
# Expected values, calculated by hand from the fixtures below:
#   usage.tsv: main 100+50+250 = 400, a1 (sonnet) 10+20+70 = 100, a2 (opus) 20+30+250 = 300, r1 (opus) 50+50+100 = 200
#     -> total 1000, standard 100, deep 500, main 400; tasks "task 1" and "Task 2" = 2 (the retry is still task 1);
#     escalations 1 ("retry deep"); review rounds 1 (r1; the screenshot check does not count).
#   reports: this run (1000 tokens, 2 tasks, 1 escalation, 1 round, main 400) plus two older ones:
#     old-a: 3000 tokens, 4 tasks, 0 escalations, 2 rounds, main 600; old-b: 2000 tokens, 0 tasks, 1 escalation, 0 rounds, main 1000
#     tokens per run 1000 2000 3000 -> median 2000, p75 3000. per task: 500, 750 -> median 625, p75 750.
#     main share: 40, 20, 50 -> median 40, p75 50. escalations 2 of 6 tasks -> 33 %.
#     stops: tier 1, kit 2 (one from old-a), spec 1 (old-b).
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT
cp -R "$here/kit/." "$project/"
cd "$project" || exit 1
git init -q -b 12-export
export RUNS_TODAY=2026-10-27

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
same() { if [ "$1" = "$2" ]; then ok; else fail "$3: got '$1', wanted '$2'"; fi; }

mkdir -p .work/12-export
tab=$(printf '\t')
cat >.work/12-export/usage.tsv <<EOF
main:s${tab}claude-opus-5-5${tab}100${tab}50${tab}9999${tab}250
a1${tab}claude-sonnet-5-5${tab}10${tab}20${tab}0${tab}70
a2${tab}claude-opus-5-5${tab}20${tab}30${tab}0${tab}250
r1${tab}claude-opus-5-5${tab}50${tab}50${tab}0${tab}100
EOF
cat >.work/12-export/agents.tsv <<EOF
a1${tab}task 1: export button${tab}implementer${tab}sonnet${tab}claude-sonnet-5-5
a2${tab}task 1 retry deep: export button${tab}implementer${tab}opus${tab}claude-opus-5-5
a3${tab}Task 2: csv format${tab}implementer${tab}sonnet${tab}claude-sonnet-5-5
r1${tab}review round 1${tab}reviewer${tab}opus${tab}claude-opus-5-5
r2${tab}screenshot check${tab}reviewer${tab}opus${tab}claude-opus-5-5
EOF
cat >.work/12-export.md <<'EOF'
# Plan: Export (spec: specs/export.md)

## Progress
- [x] 1 export button

## Stops
- <step> | <class> | <trigger> | <what was tried> | <resolution>
- task 1 | tier | typecheck failed on standard | retry on deep | passed on deep
- task 2 | kit | guard blocked `npm run gen` | ran it by hand | guard pattern too wide, proposed fix

## Notes
- task 1 added src/export.ts:12
EOF

same "$(.claude/bin/usage tsv)" "1000${tab}0${tab}100${tab}500${tab}400${tab}0${tab}1${tab}1${tab}2" "usage tsv: tokens per tier, rounds, escalations, tasks"

# --- off by default -------------------------------------------------------------

out=$(.claude/bin/runs record)
same "$?" 0 "record exits 0 when KIT_IMPROVE is empty"
case $out in *"Run records are off"*) ok ;; *) fail "record says it is off: $out" ;; esac
[ ! -e reports ] && ok || fail "record writes nothing when off"

# --- record ---------------------------------------------------------------------

sed -i 's/^KIT_IMPROVE=""/KIT_IMPROVE="1"/' .claude/kit.conf
.claude/bin/runs record >/dev/null 2>"$project/err"
r=reports/runs/12-export.tsv
same "$(grep '^run' "$r")" "run${tab}2026-10-27${tab}export${tab}12-export${tab}2${tab}1${tab}1${tab}1000${tab}0${tab}100${tab}500${tab}400" "the run row"
same "$(grep -c '^stop' "$r")" 2 "one stop row per Stops line, without the template line"
same "$(grep '^stop' "$r" | tail -n 1)" "stop${tab}task 2${tab}kit${tab}guard blocked \`npm run gen\`${tab}ran it by hand${tab}guard pattern too wide, proposed fix" "a stop row keeps its fields"
same "$(cat "$project/err")" "" "known classes give no warning"
cp .work/12-export.md "$project/state"
sed -i '/^- task 2 | kit/a - verify | weird | x | y | z' .work/12-export.md
.claude/bin/runs record >/dev/null 2>"$project/err"
case $(cat "$project/err") in *'class "weird"'*) ok ;; *) fail "an unknown class is reported" ;; esac
cp "$project/state" .work/12-export.md
.claude/bin/runs record >/dev/null 2>&1

# --- report ---------------------------------------------------------------------

printf 'run\t2026-09-01\told-a\told-a\t4\t0\t2\t3000\t0\t2400\t0\t600\nstop\ttask 3\tkit\tformat hook slow\t–\twaited\n' >reports/runs/old-a.tsv
printf 'run\t2026-09-10\told-b\told-b\t0\t1\t0\t2000\t0\t1000\t0\t1000\nstop\tspec\tspec\tcriterion 4 untestable\t–\tamended\n' >reports/runs/old-b.tsv
.claude/bin/runs report >/dev/null
m=reports/runs.md
grep -q 'Too few runs for reliable numbers\*\* (3)' "$m" && ok || fail "fewer than five runs are flagged"
grep -q 'Tasks: 6. Escalations: 2 (33% of tasks)' "$m" && ok || fail "escalation rate over all tasks"
grep -q '| Tokens per run | 2000 | 3000 | 3 |' "$m" && ok || fail "tokens per run, median and p75"
grep -q '| Tokens per task | 625 | 750 | 2 |' "$m" && ok || fail "tokens per task leaves out runs without tasks"
grep -q '| Main-session share of tokens (%) | 40 | 50 | 3 |' "$m" && ok || fail "main-session share"
grep -q '| kit | 2 |' "$m" && grep -q '| spec | 1 |' "$m" && grep -q '| tier | 1 |' "$m" && grep -q '| budget | 0 |' "$m" && ok || fail "stops by class"
grep -q '^- old-a, task 3: format hook slow. Tried: –. Resolution: waited.$' "$m" && ok || fail "stops are listed with their feature"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
