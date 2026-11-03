#!/bin/sh
# Tests for the status command (.claude/bin/status): the short line, the JSON object and the autopilot part.
# Run: sh plugins/agentic-workflow-kit/tests/status.test.sh
# The JSON checks need python3 (json module); mtimes are set with touch -t.
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
project=$work/project
mkdir -p "$project" "$work/pristine"
cp -R "$here/kit/." "$project/"
cp "$project/specs/README.md" "$work/pristine/README.md"
cp "$project/.claude/kit.conf" "$work/pristine/kit.conf"
cd "$project" || exit 1
unset KIT_BUDGET_TOKENS AUTOPILOT_MAX_IDLE_SECONDS EVIDENCE_DIR USAGE_DIR
git init -q -b main
git -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m base

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
same() { if [ "$1" = "$2" ]; then ok; else fail "$3: got '$1', wanted '$2'"; fi; }

VERIFY='' STOPS='' ROUNDS='' DECISIONS=''
out=''

reset() {
  rm -rf .work specs/*.md
  cp "$work/pristine/README.md" specs/README.md
  cp "$work/pristine/kit.conf" .claude/kit.conf
  git checkout -q -B "$1"
  VERIFY='' STOPS='' ROUNDS='' DECISIONS=''
  unset KIT_BUDGET_TOKENS AUTOPILOT_MAX_IDLE_SECONDS EVIDENCE_DIR
}

row() { printf '| %s | `%s.md` | %s | %s | 0 |' "$1" "$1" "$2" "$3"; }
readme() {
  {
    printf '# Features\n\n| Feature | Spec | Status | Branch | Open questions |\n|---|---|---|---|---|\n'
    printf '%s\n' "$@"
  } >specs/README.md
}

mkstate() {
  mkdir -p .work
  {
    printf '# Plan: Title (spec: specs/%s.md)\nBase: main\n\n## Progress\n' "$2"
    i=1
    while [ "$i" -le "$4" ]; do
      if [ "$i" -le "$3" ]; then printf -- '- [x] %s task %s\n' "$i" "$i"; else printf -- '- [ ] %s task %s\n' "$i" "$i"; fi
      i=$((i + 1))
    done
    printf '\n## Verify log\n| Criterion | Test | Red seen | Green | Notes |\n|-----------|------|----------|-------|-------|\n'
    [ -z "$VERIFY" ] || printf '%s\n' "$VERIFY"
    printf '\n## Stops\n- <step> | <class> | <trigger> | <what was tried> | <resolution>\n'
    [ -z "$STOPS" ] || printf '%s\n' "$STOPS"
    printf '\n## Rounds\n- <review|verify> <n> | <full|delta> | <commit range> | <pass, or fail: <classes>>\n'
    [ -z "$ROUNDS" ] || printf '%s\n' "$ROUNDS"
    printf '\n## Decisions to review\n- <gate> | <what was decided> | <why>\n'
    [ -z "$DECISIONS" ] || printf '%s\n' "$DECISIONS"
    printf '\n## Notes\n- note\n'
  } >".work/$1.md"
}

status_line() { .claude/bin/status --line "$@"; }
jx() { printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(eval(sys.argv[1]), ensure_ascii=False))' "$1"; }
valid_json() { printf '%s' "$1" | python3 -m json.tool >/dev/null 2>&1; }
stamp() { date -d "@$1" +%Y%m%d%H%M.%S 2>/dev/null || date -r "$1" +%Y%m%d%H%M.%S; }
dotted() { date -d "@$1" '+%d.%m.%Y %H:%M' 2>/dev/null || date -r "$1" '+%d.%m.%Y %H:%M'; }

command -v python3 >/dev/null || { echo "python3 is needed for the JSON checks"; exit 1; }


reset b1
readme "$(row x draft b1)"
same "$(status_line)" "x · spec" "COCKPIT-AC1: draft row, no state file"
same "$(status_line; echo "exit $?")" "x · spec
exit 0" "COCKPIT-AC1: exits 0"

reset b1
readme "$(row x planned b1)"
mkstate b1 x 0 7
same "$(status_line)" "x · plan · tasks 0/7" "COCKPIT-AC2: planned, 0 of 7 ticked"

mkstate b1 x 3 7
same "$(status_line)" "x · build · tasks 3/7" "COCKPIT-AC3: planned, 3 of 7 ticked is build"

readme "$(row x building b1)"
mkstate b1 x 0 7
same "$(status_line)" "x · build · tasks 0/7" "COCKPIT-AC4: building, 0 of 7 ticked"

mkstate b1 x 7 7
same "$(status_line)" "x · review · tasks 7/7" "COCKPIT-AC5: all tasks ticked is review"

ROUNDS='- review 1 | full | a..b | pass'
mkstate b1 x 6 7
same "$(status_line)" "x · review · tasks 6/7" "COCKPIT-AC6: a review round is review"

readme "$(row x in-review b1)"
ROUNDS=''
mkstate b1 x 7 7
same "$(status_line)" "x · verify · tasks 7/7" "COCKPIT-AC7: in-review is verify"

ROUNDS='- review 1 | full | a..b | pass
- verify 1 | full | a..b | pass'
mkstate b1 x 7 7
printf 'pr\n' >.work/b1-pr.md
same "$(status_line)" "x · pr · tasks 7/7" "COCKPIT-AC8: verify round and PR description is pr"

ROUNDS='- verify 1 | full | a..b | pass'
mkstate b1 x 7 7
rm -f .work/b1-pr.md
same "$(status_line)" "x · verify · tasks 7/7" "COCKPIT-AC8: a verify round without a PR description is verify"

readme "$(row x "done" b1)"
printf 'pr\n' >.work/b1-pr.md
same "$(status_line)" "x · done · tasks 7/7" "COCKPIT-AC9: done wins over a PR description"

readme "$(row x building b1)"
ROUNDS=''
mkstate b1 x 2 7
printf 'pr\n' >.work/b1-pr.md
same "$(status_line)" "x · pr · tasks 2/7" "COCKPIT-AC9: a PR description wins over build"
rm -f .work/b1-pr.md

readme "$(row x planned b1)"
mkstate b1 x 1 3
sed -e 's/- \[x\] 1 task 1/- [X] 1 task 1/' .work/b1.md >.work/b1.new && mv .work/b1.new .work/b1.md
same "$(status_line)" "x · build · tasks 1/3" "COCKPIT-AC3: an upper-case X counts as ticked"


reset b1
readme "$(row x building b1)"
mkstate b1 x 3 7
mkdir -p .work/b1
printf 'a1\tclaude-opus-5-5\t84300\t0\t0\t0\n' >.work/b1/usage.tsv
same "$(KIT_BUDGET_TOKENS=200000 status_line)" "x · build · tasks 3/7 · budget 42%" "COCKPIT-AC10: 84300 of 200000 is 42%"
printf 'a1\tclaude-opus-5-5\t230000\t0\t0\t0\n' >.work/b1/usage.tsv
same "$(KIT_BUDGET_TOKENS=200000 status_line)" "x · build · tasks 3/7 · budget 115%" "COCKPIT-AC11: over the budget shows above 100%"
printf 'a1\tclaude-opus-5-5\t199999\t0\t0\t0\n' >.work/b1/usage.tsv
same "$(KIT_BUDGET_TOKENS=200000 status_line)" "x · build · tasks 3/7 · budget 99%" "COCKPIT-AC10: the percent is rounded down"
printf 'KIT_BUDGET_TOKENS="100000"\n' >>.claude/kit.conf
same "$(status_line)" "x · build · tasks 3/7 · budget 199%" "COCKPIT-AC10: the budget comes from kit.conf"
same "$(KIT_BUDGET_TOKENS=1000000 status_line)" "x · build · tasks 3/7 · budget 19%" "COCKPIT-AC10: the environment wins over kit.conf"
same "$(KIT_BUDGET_TOKENS=0 status_line)" "x · build · tasks 3/7" "COCKPIT-AC36: a budget of 0 in the environment hides the part"
cp "$work/pristine/kit.conf" .claude/kit.conf
printf 'KIT_BUDGET_TOKENS="0"\n' >>.claude/kit.conf
same "$(status_line)" "x · build · tasks 3/7" "COCKPIT-AC36: a budget of 0 in kit.conf hides the part"
same "$(KIT_BUDGET_TOKENS=abc status_line)" "x · build · tasks 3/7" "COCKPIT-AC36: a budget that is not a number hides the part"
cp "$work/pristine/kit.conf" .claude/kit.conf
same "$(status_line)" "x · build · tasks 3/7" "COCKPIT-AC36: an unset budget hides the part"
rm -rf .work/b1

printf 'typecheck fail 1s\nlint pass 1s\nlint fail 2s\ntest fail 3s\ntest pass 4s\n' >.work/session-s1.checks
same "$(status_line --session s1)" "x · build · tasks 3/7 · 2 red" "COCKPIT-AC12: 2 red checks follow the tasks part"
same "$(status_line)" "x · build · tasks 3/7" "COCKPIT-AC12: without --session there is no red part"
same "$(status_line --session nobody)" "x · build · tasks 3/7" "COCKPIT-AC37: a session without a record has no red part"
printf 'lint fail 1s\nlint pass 2s\n' >.work/session-s2.checks
same "$(status_line --session s2)" "x · build · tasks 3/7" "COCKPIT-AC37: a check that passed again is not red"
cp .work/session-s1.checks ".work/session-s1x.checks"
same "$(status_line --session 's1/../x')" "x · build · tasks 3/7 · 2 red" "COCKPIT-AC12: the session id is sanitized like the hooks do"
same "$(KIT_BUDGET_TOKENS=1000 status_line --session s1)" "x · build · tasks 3/7 · 2 red · budget 0%" "COCKPIT-AC12: budget comes after red"
rm -f .work/session-*.checks
readme "$(row x draft b1)"
rm -f .work/b1.md
printf 'typecheck fail 1s\ntest fail 3s\n' >.work/session-s1.checks
same "$(status_line --session s1)" "x · spec · 2 red" "COCKPIT-AC12: 2 red checks follow the stage part without a tasks part"


reset b2
out=$(status_line)
same "$?:$out" "0:" "COCKPIT-AC29: no row and no state file prints nothing"

readme "$(row x draft b2)"
git checkout -q --detach
out=$(status_line)
same "$?:$out" "0:" "COCKPIT-AC30: a detached HEAD prints nothing"
git checkout -q -B b2

reset fix-branch
mkstate fix-branch fix-login 0 3
case $(status_line) in "fix-login · plan"*) ok ;; *) fail "COCKPIT-AC31: a state file without a row names the feature from its title: $(status_line)" ;; esac

reset 42-invite-users
same "$(status_line)" "" "COCKPIT-AC33: the example row never matches"
readme "$(row _x draft 42-invite-users)"
same "$(status_line)" "" "COCKPIT-AC33: a feature starting with _ never matches"

reset b1
readme "$(row x planned b1)"
mkdir -p .work
printf '# Plan: T (spec: specs/x.md)\n\n## Verify log\n' >.work/b1.md
same "$(status_line)" "x · plan" "COCKPIT-AC34: no Progress section, no tasks part"
printf '# Plan: T (spec: specs/x.md)\n\n## Progress\n- [ ] 1 <task>\n\n## Verify log\n' >.work/b1.md
same "$(status_line)" "x · plan" "COCKPIT-AC35: the template task line does not count"

readme "$(row x draft -)"
same "$(git checkout -q -B x; status_line)" "x · spec" "COCKPIT-AC29: an empty or dash branch cell matches the feature name as branch"
readme "$(row x draft '')"
same "$(status_line)" "x · spec" "COCKPIT-AC29: an empty branch cell matches the feature name"
readme "$(row x draft –)"
same "$(status_line)" "x · spec" "COCKPIT-AC29: an en dash branch cell matches the feature name"
readme "$(row x draft _tbd)"
same "$(status_line)" "x · spec" "COCKPIT-AC29: a branch cell starting with _ matches the feature name"

reset b1
readme "$(row x building b1)"
mkstate b1 x 1 3
tr -d '\r' <.work/b1.md | sed 's/$/\r/' >"$work/crlf.md"
cp "$work/crlf.md" .work/b1.md
same "$(status_line)" "x · build · tasks 1/3" "COCKPIT-AC3: a state file with CRLF line ends reads the same"

reset b1
readme "$(row x building b1)"
mkstate b1 x 0 1
chmod 000 specs/README.md
err=$(.claude/bin/status --json 2>&1 >/dev/null)
same "$?:$err" "3:cannot read specs/README.md" "COCKPIT-AC47: an unreadable feature list exits 3 and names it"
chmod 644 specs/README.md
chmod 000 .work/b1.md
err=$(.claude/bin/status --line 2>&1 >/dev/null)
same "$?:$err" "3:cannot read .work/b1.md" "COCKPIT-AC47: an unreadable state file exits 3 and names it"
chmod 644 .work/b1.md

reset b1
out=$(.claude/bin/status --bogus 2>&1)
same "$?" "2" "usage (no criterion): an unknown option exits 2"
.claude/bin/status --session >/dev/null 2>&1
same "$?" "2" "usage (no criterion): --session without an id exits 2"


reset b1
readme "$(row x building b1)"
cat >specs/x.md <<'EOF'
# X
ID prefix: X

## Acceptance criteria
- **X-AC1**: one
- **X-AC2**: two
- **X-AC3**: three
- **X-AC4**: four
- **X-AC5**: five
- **X-AC6**: six
- **X-AC7** (removed): gone
EOF
VERIFY='| X-AC1 | X-AC1: first try | yes | no | |
| X-AC1 | X-AC1: second try | – | green | |
| X-AC2 | X-AC2: only red | yes | | |
| X-AC4 | – | – | no | |
| X-AC5, X-AC6 | X-AC5: pair | yes | – | |
| X-AC3 | X-AC3: a \| b	c | – | – | |'
STOPS='- build | test | failed twice | tried a fix | asked'
mkstate b1 x 2 3
out=$(.claude/bin/status --json)
same "$?" "0" "COCKPIT-AC13: --json exits 0"
valid_json "$out" && ok || fail "COCKPIT-AC13: --json prints valid JSON: $out"
same "$(jx 'list(d.keys())')" '["line", "branch", "feature", "spec", "stage", "tasks", "criteria", "stops", "rounds", "decisions", "red", "budget", "evidence", "autopilot", "warnings"]' "COCKPIT-AC13: exactly the contract's keys"
same "$(jx '[[c["id"], c["state"], c["tests"]] for c in d["criteria"]]')" '[["X-AC1", "green", ["X-AC1: first try", "X-AC1: second try"]], ["X-AC2", "red", ["X-AC2: only red"]], ["X-AC3", "open", ["X-AC3: a | b c"]], ["X-AC4", "open", []], ["X-AC5", "red", ["X-AC5: pair"]], ["X-AC6", "red", ["X-AC5: pair"]]]' "COCKPIT-AC13: criteria in spec order; cells -, no and empty are not filled; a row naming two IDs counts for both; removed is skipped; an escaped pipe and a tab stay in one test"
same "$(jx 'd["line"]')" '"x · build · tasks 2/3"' "COCKPIT-AC13: line is inside the object"
same "$(jx '[d["branch"], d["feature"], d["spec"], d["stage"]]')" '["b1", "x", "specs/x.md", "build"]' "COCKPIT-AC13: branch, feature, spec and stage"
same "$(jx 'd["tasks"]')" '{"done": 2, "total": 3, "items": [{"text": "1 task 1", "done": true}, {"text": "2 task 2", "done": true}, {"text": "3 task 3", "done": false}]}' "COCKPIT-AC13: tasks with items"
same "$(jx '[d["red"], d["budget"], d["evidence"], d["autopilot"], d["warnings"]]')" '[null, null, null, null, []]' "COCKPIT-AC13: red, budget, evidence and autopilot are null without their source"
same "$(jx 'd["stops"]')" '["build | test | failed twice | tried a fix | asked"]' "COCKPIT-AC14: a Stops line without its leading dash"

STOPS='- build | test | failed twice | tried a fix | asked
- plan | plan | gap | none | fixed'
ROUNDS='- review 1 | full | a..b | 2 high
- review 2 | delta | b..c | pass
- verify 1 | full | c..d | pass'
DECISIONS='- plan | one | because
- gate | two | because
- split | three | because
- config | four | because'
mkstate b1 x 2 3
out=$(.claude/bin/status --json)
same "$(jx '[len(d["stops"]), len(d["rounds"]), len(d["decisions"])]')" '[2, 3, 4]' "COCKPIT-AC14: placeholder lines are left out"
same "$(jx 'd["rounds"][0]')" '"review 1 | full | a..b | 2 high"' "COCKPIT-AC14: a Rounds line as written"
same "$(jx 'd["decisions"][3]')" '"config | four | because"' "COCKPIT-AC14: a Decisions line as written"

readme "$(row x building b1)"
STOPS='- a "quote" and \ backslash'
mkstate b1 x 2 3
out=$(.claude/bin/status --json)
valid_json "$out" && ok || fail "COCKPIT-AC14: quotes and backslashes stay valid JSON: $out"
same "$(jx 'd["stops"][0]')" '"a \"quote\" and \\ backslash"' "COCKPIT-AC14: quotes and backslashes survive"

reset b1
readme "$(row x planned b1)"
mkstate b1 x 0 1
out=$(.claude/bin/status --json)
same "$?" "0" "COCKPIT-AC38: a missing spec still exits 0"
same "$(jx '[d["criteria"], "spec not found: specs/x.md" in d["warnings"]]')" '[[], true]' "COCKPIT-AC38: criteria empty and a warning names the path"

reset b1
readme "$(row x planned b1)" "$(row y approved b1)" "$(row z draft other)"
out=$(.claude/bin/status --json)
same "$(jx '[d["feature"], d["warnings"]]')" '["x", ["2 feature rows match branch b1", "spec not found: specs/x.md"]]' "COCKPIT-AC32: the first row wins and the warning counts the rows"
readme "$(row x planned b1)" "$(row y approved b1)" "$(row w draft b1)"
out=$(.claude/bin/status --json)
same "$(jx 'd["warnings"][0]')" '"3 feature rows match branch b1"' "COCKPIT-AC32: the real count"
same "$(status_line)" "x · plan" "COCKPIT-AC32: --line also takes the first row"

reset b2
out=$(.claude/bin/status --json)
valid_json "$out" && ok || fail "COCKPIT-AC29: the empty object is valid JSON: $out"
same "$(jx '[d["line"], d["stage"], d["feature"], d["tasks"], d["criteria"], d["autopilot"], d["warnings"]]')" '["", null, null, null, [], null, []]' "COCKPIT-AC29: no feature, no state file: empty object"
git checkout -q --detach
out=$(.claude/bin/status --json)
same "$?:$(jx '[d["line"], d["branch"]]')" '0:["", null]' "COCKPIT-AC30: detached HEAD in json"
git checkout -q -B b2


reset b1
readme "$(row x building b1)"
mkstate b1 x 1 2
out=$(.claude/bin/status --json)
same "$(jx 'd["evidence"]')" "null" "COCKPIT-AC39: no evidence pack is null"
mkdir -p .work/b1/evidence
head_now=$(git rev-parse HEAD)
printf '{\n  "branch": "b1",\n  "head": "%s",\n  "base": "main"\n}\n' "$head_now" >.work/b1/evidence/evidence.json
printf 'lint\tpass\t3\tfine\ntest\tfail\t9\tdetail\n' >.work/b1/evidence/gates.tsv
out=$(.claude/bin/status --json)
same "$(jx 'd["evidence"]')" "{\"current\": true, \"head\": \"$head_now\", \"gates\": [{\"name\": \"lint\", \"result\": \"pass\"}, {\"name\": \"test\", \"result\": \"fail\"}]}" "COCKPIT-AC15: a pack made on the current commit"
old=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
printf '{\n  "head": "%s"\n}\n' "$old" >.work/b1/evidence/evidence.json
out=$(.claude/bin/status --json)
same "$(jx '[d["evidence"]["current"], d["evidence"]["head"]]')" "[false, \"$old\"]" "COCKPIT-AC16: a pack made on an earlier commit"
mkdir -p "$work/other-pack"
printf '{\n  "head": "%s"\n}\n' "$head_now" >"$work/other-pack/evidence.json"
: >"$work/other-pack/gates.tsv"
out=$(EVIDENCE_DIR=$work/other-pack .claude/bin/status --json)
same "$(jx '[d["evidence"]["current"], d["evidence"]["gates"]]')" "[true, []]" "COCKPIT-AC15: EVIDENCE_DIR overrides the folder"
rm -rf .work/b1/evidence


autopilot_dir=.work/autopilot
run=20260101-100000
run_log() {
  mkdir -p "$autopilot_dir"
  cat >"$autopilot_dir/run-$run.md" <<'EOF'
# Autopilot run 01.01.2026 10:00

| Feature | Branch | Result | Details | Sessions |
|---|---|---|---|---|
| a | a-branch | in-review | https://example.invalid/pull/1; 3 min | s1 |
EOF
}
transcript() { : >"$autopilot_dir/$run-$1.jsonl"; touch -t "$(stamp "$(($(date +%s) - ${2:-0}))")" "$autopilot_dir/$run-$1.jsonl"; }
ap() { out=$(.claude/bin/status --json); }

reset b1
readme "$(row x building b1)"
mkstate b1 x 1 2
ap
same "$(jx 'd["autopilot"]')" "null" "COCKPIT-AC42: no run log is null"

run_log
ap
same "$(jx 'd["autopilot"]')" '{"active": false, "current": null, "features": [{"feature": "a", "branch": "a-branch", "result": "in-review"}]}' "COCKPIT-AC40: a run log without a transcript is not active"

transcript b-build 5
ap
same "$(jx '[d["autopilot"]["active"], d["autopilot"]["current"]]')" '[true, {"feature": "b", "phase": "build"}]' "COCKPIT-AC17: the newest transcript names feature b in phase build"
same "$(jx 'd["autopilot"]["features"]')" '[{"feature": "a", "branch": "a-branch", "result": "in-review"}]' "COCKPIT-AC18: an active run lists the finished row"

rm -f "$autopilot_dir"/*.jsonl
transcript a-plan 600
transcript b-build 5
ap
same "$(jx 'd["autopilot"]["current"]')" '{"feature": "b", "phase": "build"}' "COCKPIT-AC17: the transcript changed last wins"
rm -f "$autopilot_dir"/*.jsonl
transcript a-plan 5
transcript b-build 600
ap
same "$(jx 'd["autopilot"]["current"]')" '{"feature": "a", "phase": "plan"}' "COCKPIT-AC17: newest by mtime, not by name"

for pair in my-feat-plan:my-feat/plan a-build-restart-1:a/build a-build-wait-2:a/build a-build-3:a/build a-answer-1:a/answer my-feat-plan-wait-1:my-feat/plan; do
  rm -f "$autopilot_dir"/*.jsonl
  transcript "${pair%%:*}" 5
  ap
  want=${pair#*:}
  same "$(jx 'd["autopilot"]["current"]["feature"] + "/" + d["autopilot"]["current"]["phase"]')" "\"$want\"" "COCKPIT-AC17: transcript ${pair%%:*}"
done

rm -f "$autopilot_dir"/*.jsonl
transcript b-build 1100
ap
same "$(jx 'd["autopilot"]["active"]')" "true" "COCKPIT-AC40: 1100 s of 1200 s is still active"
transcript b-build 1200
ap
same "$(jx '[d["autopilot"]["active"], d["autopilot"]["current"]]')" "[false, null]" "COCKPIT-AC40: 1200 s or more is not active"
transcript b-build 100
out=$(AUTOPILOT_MAX_IDLE_SECONDS=60 .claude/bin/status --json)
same "$(jx 'd["autopilot"]["active"]')" "false" "COCKPIT-AC40: the idle limit comes from the environment"
printf 'AUTOPILOT_MAX_IDLE_SECONDS="60"\n' >>.claude/kit.conf
ap
same "$(jx 'd["autopilot"]["active"]')" "false" "COCKPIT-AC40: the idle limit comes from kit.conf"
out=$(AUTOPILOT_MAX_IDLE_SECONDS=300 .claude/bin/status --json)
same "$(jx 'd["autopilot"]["active"]')" "true" "COCKPIT-AC40: the environment wins over kit.conf"
cp "$work/pristine/kit.conf" .claude/kit.conf
err=$(AUTOPILOT_MAX_IDLE_SECONDS=abc .claude/bin/status --json 2>&1 >/dev/null)
out=$(AUTOPILOT_MAX_IDLE_SECONDS=abc .claude/bin/status --json 2>/dev/null)
same "$err:$(jx 'd["autopilot"]["active"]')" ":true" "COCKPIT-AC40: a non-numeric idle limit falls back to 1200 s"

now=$(date +%s)
rm -f "$autopilot_dir"/*.jsonl
transcript b-build 10800
run_log
printf '\n- a, build: waits for the usage limit to reset at %s\n' "$(dotted $((now + 3600)))" >>"$autopilot_dir/run-$run.md"
ap
same "$(jx 'd["autopilot"]["active"]')" "true" "COCKPIT-AC41: waiting for a reset 1 hour ahead is active"
same "$(jx 'd["autopilot"]["current"]')" '{"feature": "b", "phase": "build"}' "COCKPIT-AC41: current comes from the newest transcript"
run_log
printf '\n- a, build: waits for the usage limit to reset at %s\n' "$(dotted $((now - 300)))" >>"$autopilot_dir/run-$run.md"
ap
same "$(jx 'd["autopilot"]["active"]')" "true" "COCKPIT-AC41: a reset 5 minutes ago is within the idle limit"
run_log
printf '\n- a, build: waits for the usage limit to reset at %s\n' "$(dotted $((now - 7200)))" >>"$autopilot_dir/run-$run.md"
ap
same "$(jx 'd["autopilot"]["active"]')" "false" "COCKPIT-AC55: a reset passed more than the idle limit ago is not active"
run_log
printf '\n- a, build: waits for the usage limit to reset at %s\n- a, build: started again\n' "$(dotted $((now + 3600)))" >>"$autopilot_dir/run-$run.md"
ap
same "$(jx 'd["autopilot"]["active"]')" "false" "COCKPIT-AC55: only the last line says the run waits"

reset b2
run_log
transcript b-build 5
ap
same "$(jx '[d["feature"], d["autopilot"]["active"], d["autopilot"]["current"]]')" '[null, true, {"feature": "b", "phase": "build"}]' "COCKPIT-AC17: a branch without a feature still reports the run"
reset b1
readme "$(row x building b1)"
mkstate b1 x 1 2

run_log
printf '\nEvery feature has a PR. Review the PRs: a.\n' >>"$autopilot_dir/run-$run.md"
transcript b-build 5
ap
same "$(jx '[d["autopilot"]["active"], d["autopilot"]["current"], len(d["autopilot"]["features"])]')" "[false, null, 1]" "COCKPIT-AC19: a closing line ends the run and the rows stay"
cat >"$autopilot_dir/run-$run.md" <<'EOF'
# Autopilot run

| Feature | Branch | Result | Details | Sessions |
|---|---|---|---|---|
| a | a | in-review | pr | s1 |
| b | b | stopped: env | boom | s2 |

Stopped at b: boom
EOF
ap
same "$(jx '[d["autopilot"]["active"], [f["result"] for f in d["autopilot"]["features"]]]')" '[false, ["in-review", "stopped: env"]]' "COCKPIT-AC19: a Stopped at line ends the run too"

run_log
mkdir -p "$autopilot_dir"
cp "$autopilot_dir/run-$run.md" "$autopilot_dir/run-20260202-100000.md"
printf '\nStopped at a: old\n' >"$autopilot_dir/run-20250101-100000.md"
ap
same "$(jx 'd["autopilot"]["features"][0]["feature"]')" '"a"' "COCKPIT-AC19: the newest run log by name is used"


reset b1
readme "$(row x building b1)"
mkstate b1 x 2 3
mkdir -p .work/b1/evidence
printf '{\n  "head": "%s"\n}\n' "$(git rev-parse HEAD)" >.work/b1/evidence/evidence.json
printf 'lint\tpass\t3\tfine\n' >.work/b1/evidence/gates.tsv
printf 'test fail 3s\n' >.work/session-s1.checks
printf 'a1\tclaude-opus-5-5\t1000\t0\t0\t0\n' >.work/b1/usage.tsv
run_log
transcript b-build 5
touch "$work/marker"
find . -path ./.git -prune -o -exec touch -t 202001010000 {} +
touch -t 202001010000 "$work/marker"
snapshot() { find . -path ./.git -prune -o -print | sort | while IFS= read -r f; do [ -f "$f" ] && cksum "$f" || echo "$f"; done; }
before=$(snapshot)
i=0
while [ "$i" -lt 10 ]; do
  .claude/bin/status --json --session s1 >/dev/null
  KIT_BUDGET_TOKENS=5000 .claude/bin/status --line --session s1 >/dev/null
  .claude/bin/status >/dev/null
  i=$((i + 1))
done
same "$(snapshot)" "$before" "COCKPIT-AC43: file list and content are unchanged after 10 runs"
same "$(find . -path ./.git -prune -o -newer "$work/marker" -print)" "" "COCKPIT-AC43: no file or folder got a new modification time"

reset b1
rm -rf .work
readme "$(row x draft b1)"
.claude/bin/status --json --session s1 >/dev/null
.claude/bin/status --line >/dev/null
[ ! -e .work ] && ok || fail "COCKPIT-AC43: the command does not create .work/"

grep -q 'With the first task, set the feature.s status in `specs/README.md` from `planned` to `building` and commit it with that task' \
  "$here/kit/.claude/skills/ship-feature/SKILL.md" && ok || fail "COCKPIT-AC20: /ship-feature sets building with the first task's commit"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
