#!/bin/sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fake=$work/fake
mkdir -p "$work/bin" "$fake"

cat >"$work/bin/claude" <<'EOF'
#!/bin/sh
case $* in
  *"Reply with OK."*)
    [ -f "$FAKE_DIR/untrusted" ] && echo "Ignoring 13 permissions.allow entries from .claude/settings.json: this workspace has not been trusted." >&2
    echo '{"type":"result","result":"OK"}'
    exit 0
    ;;
esac
printf '%s|%s|%s|%s|%s\n' "$(git branch --show-current)" "${KIT_BASE:-}" "${KIT_APPROVAL:-}" "${KIT_IMPROVE:-}" "$(printf '%s' "$*" | tr '\n' ' ')" >>"$FAKE_DIR/calls"
n=$(($(cat "$FAKE_DIR/n" 2>/dev/null || echo 0) + 1))
echo "$n" >"$FAKE_DIR/n"
echo session >>"$FAKE_DIR/order"
set_status() {
  set_status_only "$1" "$2"
  git commit -qam "status $1 $2"
  case $2 in planned) write_ticked ;; esac
}
set_status_only() {
  awk -F '|' -v OFS='|' -v s="$1.md" -v t="$2" '{ x = $3; gsub(/[ `]/, "", x) } x == s || index(x, "[" s "]") == 1 { $4 = " " t " " } 1' specs/README.md >"$FAKE_DIR/readme"
  cat "$FAKE_DIR/readme" >specs/README.md
}
write_ticked() {
  [ -f ".work/$(git branch --show-current).md" ] || printf '# Plan: x (spec: specs/x.md)\n\n## Progress\n- [x] 1 done\n' >".work/$(git branch --show-current).md"
}
tick() { sed -i.bak "s/^- \[ \] $2 /- [x] $2 /" ".work/$1.md"; }
commit_task() { echo "$1" >>src.txt; git add src.txt; git commit -qm "task $1: work"; }
round() { printf -- '- group %s review 1 | full | a..b | %s\n' "$1" "$2" >>".work/$(git branch --show-current).md"; }
stage_round() { printf -- '- stack %s\n' "$1" >>".work/$(git branch --show-current).md"; }
stage_fix() { echo fix >>src.txt; git add src.txt; git commit -qm "stack fix"; stage_round "$1"; }
finish() { _slug=$1; _group=$2; shift 2; for _t in "$@"; do commit_task "$_t"; tick "$_slug" "$_t"; done; round "$_group" pass; }
finish_some() { _slug=$1; shift; for _t in "$@"; do commit_task "$_t"; tick "$_slug" "$_t"; done; }
spend() { mkdir -p ".work/$(git branch --show-current)"; printf 'main:s\tm\t%s\t0\t0\t0\n' "$1" >".work/$(git branch --show-current)/usage.tsv"; }
add_stop_line() { awk -v line="- step | $1 | failed | tried | open" '{ print } /^## Stops/ { print line }' ".work/$(git branch --show-current).md" >"$FAKE_DIR/state" && cat "$FAKE_DIR/state" >".work/$(git branch --show-current).md"; }
open_pr() {
  echo "$(git branch --show-current) https://example.invalid/pull/$(git branch --show-current)" >>"$FAKE_DIR/prs"
}
add_stop() {
  printf '# Plan: x (spec: specs/x.md)\n\n## Stops\n- task 1 | %s | failed | tried | open\n' "$1" >>".work/$(git branch --show-current).md"
}
RESULT=done
DENIED=""
TURNS=1
COST=0.5
EXTRA=""
SLEEP=0
eval "$(sed -n "${n}p" "$FAKE_DIR/script")"
printf '{"type":"system","subtype":"init"}\n'
[ -z "$EXTRA" ] || printf '%s\n' "$EXTRA"
sleep "$SLEEP"
printf '{"type":"result","session_id":"s%s","result":"%s","num_turns":%s,"total_cost_usd":%s,"permission_denials":[%s]}\n' "$n" "$RESULT" "$TURNS" "$COST" "$DENIED"
EOF
cat >"$work/bin/gh" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr view")
    if [ -f "$FAKE_DIR/pr-after" ]; then
      left=$(cat "$FAKE_DIR/pr-after")
      if [ "$left" -le 0 ]; then echo https://example.invalid/pull/late; exit 0; fi
      echo $((left - 1)) >"$FAKE_DIR/pr-after"
      exit 1
    fi
    awk -v b="$3" '$1 == b { print $2; found = 1 } END { exit !found }' "$FAKE_DIR/prs" 2>/dev/null ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$work/bin/claude" "$work/bin/gh"
PATH=$work/bin:$PATH
export PATH FAKE_DIR="$fake" KIT_BUDGET_TOKENS=100000
unset KIT_BASE KIT_APPROVAL KIT_IMPROVE AUTOPILOT_MAX_ANSWERS
export AUTOPILOT_POLL_SECONDS=1

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
same() { if [ "$1" = "$2" ]; then ok; else fail "$3: got '$1', wanted '$2'"; fi; }
contains() { case $1 in *"$2"*) ok ;; *) fail "$3: '$2' not in '$1'" ;; esac; }

project=""
setup() {
  project=$work/p$(date +%s)$$-$passed-$failed
  mkdir -p "$project"
  cp -R "$here/kit/." "$project/"
  rm -f "$fake/calls" "$fake/n" "$fake/untrusted" "$fake/prs" "$fake/pr-after" "$fake/order"
  : >"$fake/script"
  cd "$project" || exit 1
  printf '.work/\n' >.gitignore
  # Most tests end at the PR; the stack stage has its own section.
  printf 'KIT_STACK_CHECKS="off"\nKIT_GATE_MERGE="ask"\n' >>.claude/kit.conf
  {
    echo '| Feature | Spec | Status | Branch | Open questions |'
    echo '|---|---|---|---|---|'
    for row in "$@"; do
      # shellcheck disable=SC2016
      printf '| %s | `%s.md` | %s | %s | 0 |\n' "${row%%:*}" "${row%%:*}" "${row#*:}" '–'
    done
  } >specs/README.md
  git init -q -b main
  git add -A
  git -c user.name=t -c user.email=t@example.invalid commit -qm init
  git config user.name t
  git config user.email t@example.invalid
  mkdir -p .work
  for row in "$@"; do
    case ${row#*:} in planned | building | in-review) printf '# Plan: x (spec: specs/x.md)\n\n## Progress\n- [x] 1 done\n' >".work/${row%%:*}.md" ;; esac
  done
}
script() { printf '%s\n' "$@" >"$fake/script"; }
calls() { cat "$fake/calls" 2>/dev/null; }
call() { sed -n "${1}p" "$fake/calls"; }
autopilot() { .claude/bin/autopilot "$@" >"$work/out" 2>"$work/err"; }


setup alpha:approved beta:draft
autopilot alpha beta
same "$?" 2 "a draft spec in the queue blocks the start"
contains "$(cat "$work/err")" "specs/beta.md is draft, not approved" "the draft spec is named"
same "$(calls)" "" "no session starts before the preflight passes"

setup alpha:approved
(KIT_BUDGET_TOKENS="" autopilot)
same "$?" 2 "an unattended run needs a budget"
contains "$(cat "$work/err")" "KIT_BUDGET_TOKENS" "the budget is named"

setup alpha:approved
echo changed >>specs/README.md
autopilot
same "$?" 2 "uncommitted changes block the start"

setup alpha:approved
touch "$fake/untrusted"
autopilot
same "$?" 2 "an untrusted workspace blocks the start"
contains "$(cat "$work/err")" "accept the trust dialog" "the fix is named"
same "$(calls)" "" "no session starts in an untrusted workspace"

setup alpha:approved beta:approved gamma:draft
script 'set_status alpha planned' 'set_status alpha in-review; open_pr' 'set_status beta planned' 'set_status beta in-review; open_pr'
autopilot
same "$?" 0 "two approved features run through"
same "$(calls | wc -l | tr -d ' ')" 4 "one plan and one build session per feature; the draft is not queued"
same "$(call 1 | cut -d '|' -f 1-4)" "alpha|main|autonomous|1" "alpha runs on its own branch, from main, autonomous, with run records"
contains "$(call 1)" "-p /plan-feature alpha" "first session plans"
contains "$(call 2)" "-p /ship-feature alpha" "second session builds in a fresh context"
contains "$(call 1)" "--permission-prompts none" "nothing waits for a prompt"
contains "$(call 1)" "Bash(.claude/bin/*)" "the kit's own commands run unattended"
contains "$(call 1)" "--disallowedTools Bash(*autopilot*)" "a session cannot start autopilot itself"
contains "$(call 1)" "--append-system-prompt This is an unattended .claude/bin/autopilot session" "the session knows nobody is watching"
same "$(call 3 | cut -d '|' -f 1-2)" "beta|alpha" "beta is stacked on alpha"
same "$(git merge-base alpha beta)" "$(git rev-parse alpha)" "beta branches from alpha's head"
log=$(cat .work/autopilot/run-*.md)
contains "$log" "| alpha | alpha | in-review | https://example.invalid/pull/alpha;" "the run log has a row per feature with its PR"
contains "$log" "s1 s2" "the run log keeps the session ids"
same "$(ls .work/autopilot/*-alpha-plan.jsonl | wc -l | tr -d ' ')" 1 "each session keeps its transcript"

autopilot
same "$?" 0 "a second run succeeds"
same "$(calls | wc -l | tr -d ' ')" 4 "features in review are skipped"
setup alpha:planned
script 'RESULT="Which one?"' 'RESULT="ESCALATE: unclear"'
autopilot
sleep 1
script 'RESULT="Which one?"' 'RESULT="ESCALATE: unclear"'
rm -f "$fake/n"
autopilot
same "$(ls .work/autopilot/*-alpha-build-*.jsonl | wc -l | tr -d ' ')" 2 "a second run keeps the first run's transcripts"

setup alpha:planned beta:approved
script 'set_status alpha in-review; RESULT="Gate duplicates failed; install jscpd?"' 'RESULT="ESCALATE: a new dependency needs a human."'
autopilot
same "$?" 1 "in-review without a PR is not done: verify can still fail after the status is set"
same "$(calls | grep -c '^beta|' | tr -d ' ')" 0 "nothing is stacked on a feature without a PR"
script 'set_status alpha in-review; open_pr' 'set_status beta planned' 'set_status beta in-review; open_pr'
rm -f "$fake/calls" "$fake/n"
autopilot
same "$?" 0 "the next run resumes the in-review feature until its PR exists"
contains "$(call 1)" "-p /ship-feature alpha" "it resumes with the build session, not the plan"

setup alpha:planned
git checkout -q -b alpha
git checkout -q main
script 'set_status alpha in-review; open_pr'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "a planned feature skips the plan session"
same "$(call 1 | cut -d '|' -f 1)" "alpha" "an existing branch is reused"


setup alpha:planned
script 'RESULT="Which export format?"' 'RESULT="ANSWER: CSV, the spec names a spreadsheet."' 'set_status alpha in-review; open_pr'
autopilot
same "$?" 0 "an answered question lets the feature finish"
contains "$(call 2)" "--allowedTools Read Grep Glob" "the answerer can only read"
contains "$(call 2)" "Question: Which export format?" "the answerer gets the question"
contains "$(call 3)" "--resume s1" "the build session is resumed"
contains "$(call 3)" "Autopilot answer: CSV, the spec names a spreadsheet." "the answer is sent back"
contains "$(call 3)" "Decisions to review" "the session is told to log the answer"
contains "$(cat .work/autopilot/run-*.md)" "Q: Which export format? A: CSV" "the run log keeps question and answer"

setup alpha:planned
script 'RESULT="Should admins see it?"' 'RESULT="ESCALATE: the spec does not say."'
autopilot
same "$?" 1 "an escalated question stops the run"
contains "$(cat "$work/err")" "claude --resume s1" "the stop says how to answer"

setup alpha:planned
script 'RESULT="Need to push"; DENIED="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"npm run e2e\"}}"'
autopilot
same "$?" 1 "a denied protected action stops the run"
same "$(calls | wc -l | tr -d ' ')" 1 "a denial is never sent to the answerer"
contains "$(cat "$work/err")" "(permission)" "the stop names the denial"
contains "$(cat "$work/err")" "denied: npm run e2e;" "the stop names the denied command"

setup alpha:planned
script 'add_stop spec; RESULT="AC3 cannot be tested"'
autopilot
same "$?" 1 "a spec stop stops the run"
same "$(calls | wc -l | tr -d ' ')" 1 "a spec stop is never answered"
contains "$(cat "$work/err")" "(spec)" "the stop names its class"

setup alpha:planned
script 'add_stop test; RESULT="Flaky test, rewrite it?"' 'RESULT="ANSWER: yes"' 'RESULT="Another question?"'
(AUTOPILOT_MAX_ANSWERS=1 autopilot)
same "$?" 1 "the answer cap stops the run"
same "$(calls | wc -l | tr -d ' ')" 3 "only one answer per feature with the cap at 1"
contains "$(cat "$work/err")" "more than 1 answers needed" "the stop names the cap"

setup alpha:planned beta:approved
script 'RESULT="Which one?"' 'RESULT="ESCALATE: unclear"'
autopilot
same "$(calls | grep -c '^beta|' | tr -d ' ')" 0 "a stop halts the queue; later features wait"

setup alpha:approved
printf '| Beta | [beta.md](./beta.md) | approved | – | 0 |\n' >>specs/README.md
git commit -qam "linked row"
script 'set_status alpha planned' 'set_status alpha in-review; open_pr' 'set_status beta planned' 'set_status beta in-review; open_pr'
autopilot
same "$?" 0 "a row whose spec cell is a markdown link is queued"
contains "$(call 3)" "-p /plan-feature beta" "the linked spec is planned after alpha"

# --- sessions: metrics, watchdog, usage limit ------------------------------------

tool_call='{"type":"assistant","message":{"id":"m1","content":[{"type":"tool_use","id":"toolu_1","name":"Bash","input":{"command":"npm test"}}],"container":null,"stop_reason":null,"usage":{"output_tokens":7}},"parent_tool_use_id":null}'
segment='{"type":"result","session_id":"s1","result":"waiting for the background task","num_turns":53,"total_cost_usd":4.25}'

setup alpha:planned
script "EXTRA='$segment'; TURNS=30; COST=6.5; set_status alpha in-review; open_pr"
autopilot
same "$?" 0 "a session with several result segments runs through"
row=$(grep '^[0-9]' .work/autopilot/sessions.tsv | tail -n 1)
same "$(printf '%s' "$row" | cut -f 2-3,6-8)" "alpha	build	83	6.5	2" "turns are summed over every result line, the cost is the last (cumulative) one"
same "$(printf '%s' "$row" | cut -f 9)" "ended" "the session ended on its own"

setup alpha:planned
script "SLEEP=4" "set_status alpha in-review; open_pr"
AUTOPILOT_MAX_IDLE_SECONDS=2 autopilot
same "$?" 0 "an idle session is stopped and the phase starts once more"
contains "$(cat .work/alpha.md)" "| budget | watchdog: no output for 2 s | stopped the session | started a fresh session" "the watchdog stop is recorded"
contains "$(cut -f 9 .work/autopilot/sessions.tsv)" "watchdog: no output for 2 s" "the stopped session's row says why"
same "$(calls | wc -l | tr -d ' ')" 2 "one fresh session after the watchdog stop"

setup alpha:planned
script "SLEEP=4" "SLEEP=4"
AUTOPILOT_MAX_IDLE_SECONDS=2 autopilot
same "$?" 1 "a second watchdog stop halts the run"
contains "$(cat "$work/err")" "stopped at alpha (budget)" "the halt names the budget class"

setup alpha:planned
printf '%s\n%s\n%s\n' "$tool_call" "$tool_call" "$tool_call" >"$work/three-calls"
script "EXTRA=\"\$(cat '$work/three-calls')\"; SLEEP=4" "set_status alpha in-review; open_pr"
AUTOPILOT_MAX_IDENTICAL_CALLS=3 autopilot
contains "$(cat .work/alpha.md)" "watchdog: the same tool call 3 times in a row: Bash" "repeated identical tool calls stop the session"

setup alpha:planned
script "SLEEP=4" "set_status alpha in-review; open_pr"
AUTOPILOT_MAX_SESSION_SECONDS=2 autopilot
contains "$(cat .work/alpha.md)" "watchdog: ran longer than 2 s" "a session over its time limit is stopped"

setup alpha:planned
past=$(($(date +%s) - 300))
script "EXTRA='{\"type\":\"rate_limit_event\",\"rate_limit_info\":{\"status\":\"rejected\",\"resetsAt\":$past}}'; RESULT='You have hit your limit'" "set_status alpha in-review; open_pr"
autopilot
same "$?" 0 "a session stopped by the usage limit waits and starts again"
contains "$(cat .work/autopilot/run-*.md)" "waits for the usage limit" "the wait is logged"
contains "$(cut -f 9 .work/autopilot/sessions.tsv)" "usage limit" "the session row names the usage limit"
case $(cat .work/alpha.md 2>/dev/null) in *watchdog*) fail "a usage-limit wait is not a watchdog stop" ;; *) ok ;; esac

setup alpha:planned
script "EXTRA='{\"type\":\"rate_limit_event\",\"rate_limit_info\":{\"status\":\"allowed\",\"resetsAt\":$past,\"overageStatus\":\"rejected\",\"unifiedWindows\":{\"five_hour\":{\"status\":\"rejected\",\"resetsAt\":$past}}}}'; set_status alpha in-review; open_pr"
autopilot
same "$(cut -f 9 .work/autopilot/sessions.tsv | tail -n 1)" "ended" "an allowed session with a rejected overage does not wait"

setup alpha:approved
same "$(KIT_IMPROVE=1 .claude/bin/runs report)" "No run records in reports/runs/ yet." "KIT_IMPROVE from the environment turns run records on"

# --- group sessions (specs/group-sessions.md) --------------------------------------

# A check that records its calls and exits with the next code from $fake/code-<name> (typecheck, related,
# base-typecheck, base-test); the last line repeats, and no file means 0. Committed, so the tree stays clean.
stub_check() {
  rm -f "$fake"/code-* "$fake/check-calls"
  cat >.claude/bin/check <<'EOF'
#!/bin/sh
echo "$*" >>"$FAKE_DIR/check-calls"
echo "check $*" >>"$FAKE_DIR/order"
[ ! -f "$FAKE_DIR/ignore-term" ] || trap '' TERM
case $* in
  "--against-baseline typecheck") name=base-typecheck ;;
  "--against-baseline test") name=base-test ;;
  typecheck) name=typecheck ;;
  test-related*) name=related ;;
  *) exit 0 ;;
esac
[ ! -f "$FAKE_DIR/sleep-$name" ] || sleep "$(cat "$FAKE_DIR/sleep-$name")"
file=$FAKE_DIR/code-$name
[ -f "$file" ] || exit 0
code=$(head -n 1 "$file")
[ "$(wc -l <"$file")" -le 1 ] || sed -i.bak 1d "$file"
echo "check output: $name failed with $code"
exit "$code"
EOF
  git add -A
  git commit -qm "stub check"
}
codes() { _name=$1; shift; printf '%s\n' "$@" >"$fake/code-$_name"; }

# plan <slug> <task:group:tier>...: a plan with a Group column. An empty group gives an empty cell.
plan() {
  _file=.work/$1.md
  shift
  mkdir -p .work
  {
    printf '# Plan: x (spec: specs/x.md)\n\n## Tasks\n| # | Task | Files | Criteria | Test cases | Depends on | Tier | Group |\n|---|---|---|---|---|---|---|---|\n'
    for _row in "$@"; do
      _n=${_row%%:*}; _rest=${_row#*:}; _g=${_rest%%:*}; _t=${_rest#*:}
      printf '| %s | t | f | c | c | - | %s | %s |\n' "$_n" "$_t" "$_g"
    done
    printf '\n## Progress\n'
    for _row in "$@"; do printf -- '- [ ] %s t\n' "${_row%%:*}"; done
    printf '\n## Stops\n\n## Rounds\n'
  } >"$_file"
}
# threes <slug> <task:tier>...: a plan without a Group column.
threes() {
  _file=.work/$1.md
  shift
  mkdir -p .work
  {
    printf '# Plan: x (spec: specs/x.md)\n\n## Tasks\n| # | Task | Files | Criteria | Test cases | Depends on | Tier |\n|---|---|---|---|---|---|---|\n'
    for _row in "$@"; do printf '| %s | t | f | c | c | - | %s |\n' "${_row%%:*}" "${_row#*:}"; done
    printf '\n## Progress\n'
    for _row in "$@"; do printf -- '- [ ] %s t\n' "${_row%%:*}"; done
    printf '\n## Stops\n\n## Rounds\n'
  } >"$_file"
}
tick_now() { sed -i.bak "s/^- \[ \] $2 /- [x] $2 /" ".work/$1.md"; }
log_of() { cat .work/autopilot/run-*.md; }

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:A:standard 3:A:standard 4:A:standard 5:B:standard
autopilot
same "$?" 1 "AC6: four tasks in a group stop the build"
same "$(calls)" "" "AC6: no session starts"
contains "$(log_of)" "Stopped at alpha: group A holds 4 tasks; a group takes at most 3 tasks" "AC6: the closing line names the group and the limit"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard 3:A:standard
autopilot
same "$(calls)" "" "AC7: no session for a group that is not consecutive"
contains "$(log_of)" "group A is not consecutive" "AC7: the closing line names the group"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2::standard
autopilot
same "$(calls)" "" "AC8: no session with an empty group cell"
contains "$(log_of)" "task 2 has no group" "AC8: the closing line names the task"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:A:deep 3:A:standard 4:B:standard
script 'finish alpha A 1 2 3' 'finish alpha B 4' 'open_pr'
autopilot
same "$?" 0 "AC9: a plan with two groups runs through"
same "$(calls | wc -l | tr -d ' ')" 3 "AC9, AC28: one session per group and one final"
contains "$(call 1)" "/ship-feature alpha --group A --tasks 1,2,3 --from " "AC9: group A first"
contains "$(call 2)" "/ship-feature alpha --group B --tasks 4 --from " "AC9: then group B"
contains "$(call 3)" "/ship-feature alpha --final" "AC28: then the final session"
contains "$(call 1)" "--model opus" "AC10: a group runs on its highest tier"
contains "$(call 2)" "--model sonnet" "AC10: the next group has its own tier"
contains "$(call 3)" "--model sonnet" "AC29: the final session runs on the verify role"
contains "$(cat "$fake/check-calls")" "test-related src.txt" "AC23: the build ran the related tests for the group diff"
same "$(ls .work/autopilot/*-alpha-build-*.jsonl | wc -l | tr -d ' ')" 3 "AC64: every session has its own transcript"
contains "$(tail -n 3 .work/autopilot/run-*.md)" "Every feature has a PR" "AC100: a push gate on auto ends with a PR"

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'finish_some alpha 1' '.claude/bin/status --json >"$FAKE_DIR/status"; open_pr'
autopilot
same "$?" 0 "AC31: one group needs no group round"
case $(cat .work/alpha.md) in *"- group "*) fail "AC31: the fixture records no group round" ;; *) ok ;; esac
contains "$(cat "$fake/status")" '"current":{"feature":"alpha","phase":"build"}' "AC65: status reads the session's name"

# --- the build's own checks

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
codes typecheck 1 0
script 'finish alpha A 1' 'RESULT=fixed' 'finish alpha B 2' 'open_pr'
autopilot
same "$?" 0 "AC26: a repaired group lets the build go on"
contains "$(call 2)" "--resume s1" "AC24: the same session is resumed"
contains "$(call 2)" "--model opus" "AC24: on a stronger model"
contains "$(call 2)" "check output: typecheck failed with 1" "AC24: with the failure output"
contains "$(call 3)" "--group B" "AC26: the next group starts"
contains "$(call 3)" "--model sonnet" "the next group is back on its own tier"

setup alpha:planned
stub_check
plan alpha 1:A:fast 2:B:standard
codes typecheck 1 0
script 'finish alpha A 1' 'RESULT=fixed' 'finish alpha B 2' 'open_pr'
autopilot
contains "$(call 1)" "--model haiku" "a group on the lowest tier starts there"
contains "$(call 2)" "--model sonnet" "AC87: its resume runs on the standard tier"

setup alpha:planned
stub_check
plan alpha 1:A:deep 2:B:standard
codes typecheck 1 0
script 'finish alpha A 1' 'RESULT=fixed' 'finish alpha B 2' 'open_pr'
autopilot
contains "$(call 2)" "--model opus" "AC25: a deep group stays on deep"
contains "$(call 2)" "--effort max" "AC25: at effort max"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
codes typecheck 1 1
script 'finish alpha A 1' 'RESULT=tried'
autopilot
same "$?" 1 "AC27: a second failed check stops the build"
same "$(calls | wc -l | tr -d ' ')" 2 "AC27: no further session"
contains "$(log_of)" "Stopped at alpha: the build's checks failed again for group A" "AC27: the closing line says so"
contains "$(cat .work/alpha.md)" "| tier | the build's checks failed again for group A" "AC88: Stops holds a line"
rm -f "$fake/calls" "$fake/n" "$fake/order"
codes typecheck 0
script 'finish alpha B 2' 'open_pr'
autopilot
same "$?" 0 "AC95: a rerun with passing checks goes on"
same "$(head -n 1 "$fake/order")" "check typecheck" "AC95: the checks run before any session"
contains "$(call 1)" "--group B" "AC95: before the next group"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
tick_now alpha 1
printf -- '- group A review 1 | full | a..b | pass\n' >>.work/alpha.md
codes typecheck 1 0
script 'RESULT=fixed' 'finish alpha B 2' 'open_pr'
autopilot
same "$?" 0 "AC96: a rerun repairs the failing done group"
contains "$(call 1)" "--group A --tasks none" "AC96: the first session is group A's"
contains "$(call 1)" "check output: typecheck failed with 1" "AC96: with the failure output"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
codes typecheck 3
codes related 4
script 'finish alpha A 1' 'finish alpha B 2' 'open_pr'
autopilot
same "$?" 0 "AC89: checks that are not configured or n/a do not fail"
same "$(calls | wc -l | tr -d ' ')" 3 "AC89: no resume"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
: >.claude/baseline.tsv
git add -A
git commit -qm baseline
codes typecheck 1
codes base-typecheck 0
codes related 1
codes base-test 0
script 'finish alpha A 1' 'finish alpha B 2' 'open_pr'
autopilot
same "$?" 0 "AC90, AC91: legacy failures alone do not fail a group"
contains "$(cat "$fake/check-calls")" "--against-baseline typecheck" "AC90: the typecheck is compared with the baseline"
contains "$(cat "$fake/check-calls")" "--against-baseline test" "AC91: a failing related test is confirmed against the baseline"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
: >.claude/baseline.tsv
git add -A
git commit -qm baseline
codes related 1
codes base-test 1 0
script 'finish alpha A 1' 'RESULT=fixed' 'finish alpha B 2' 'open_pr'
autopilot
contains "$(call 2)" "--resume s1" "AC92: a new failure resumes the session"

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'tick alpha 1' 'open_pr'
autopilot
case $(cat "$fake/check-calls") in *test-related*) fail "AC93: a group with no files runs no related tests" ;; *) ok ;; esac

setup alpha:planned
stub_check
plan alpha 1:A:standard
echo 30 >"$fake/sleep-typecheck"
script 'finish alpha A 1'
AUTOPILOT_MAX_SESSION_SECONDS=2 autopilot
same "$?" 1 "AC94: a check over the time limit stops the build"
contains "$(log_of)" "Stopped at alpha: a check ran longer than 2 s" "AC94: the closing line says so"
rm -f "$fake/sleep-typecheck"

# --- the budget

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
script 'finish alpha A 1; spend 100001'
autopilot
same "$?" 1 "AC44: over budget after a group stops the build"
same "$(calls | wc -l | tr -d ' ')" 1 "AC44: no further session"
contains "$(log_of)" "Stopped at alpha: budget reached" "AC44: the closing line names the budget"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
script 'finish alpha A 1; spend 100000'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC120: exactly the budget stops the build"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
script 'finish alpha A 1; spend 99999' 'finish alpha B 2' 'open_pr'
autopilot
same "$(calls | wc -l | tr -d ' ')" 3 "AC45: under budget goes on"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
codes typecheck 1
script 'finish alpha A 1; spend 100001'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC121: an over-budget build never resumes"
contains "$(log_of)" "budget reached" "AC121: the closing line names the budget"
rm -f "$fake/calls" "$fake/n"
script 'open_pr'
autopilot
same "$?" 1 "AC122: a new build over budget stops"
same "$(calls)" "" "AC122: no session starts"

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'spend 100001; RESULT="Which one?"'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC149: over budget after any session starts or resumes nothing"

tokens_line='{"type":"assistant","message":{"id":"msg_1","model":"m","usage":{"input_tokens":5000,"output_tokens":0}}}'
subagent_line='{"type":"assistant","parent_tool_use_id":"toolu_9","message":{"id":"msg_2","model":"m","usage":{"input_tokens":7000,"output_tokens":0}}}'
setup alpha:planned
stub_check
plan alpha 1:A:standard
printf '%s\n%s\n' "$tokens_line" "$subagent_line" >"$work/two-lines"
script "EXTRA=\"\$(cat '$work/two-lines')\"; SLEEP=4" 'finish alpha A 1' 'open_pr'
AUTOPILOT_MAX_IDLE_SECONDS=2 autopilot
same "$(.claude/bin/usage total)" 5000 "AC123: a killed session's own tokens count"

setup alpha:approved
(KIT_BUDGET_TOKENS=100k autopilot)
same "$?" 2 "AC124: a budget that is not a number refuses"
same "$(calls)" "" "AC124: no session starts"
(KIT_BUDGET_TOKENS=0 autopilot)
same "$?" 2 "AC125: a budget of 0 refuses"

# --- resuming

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:A:standard 3:A:standard
tick_now alpha 1
script 'RESULT=stop; finish_some alpha 2 3' 'open_pr'
autopilot
contains "$(call 1)" "--group A --tasks 2,3" "AC48: a partly done group goes on with its open tasks"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
tick_now alpha 1
script 'round A pass' 'finish alpha B 2' 'open_pr'
autopilot
contains "$(call 1)" "--group A --tasks none" "AC127: a ticked group without a round is not skipped"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
tick_now alpha 1
printf -- '- group A review 2 | delta | a..b | 1 high open\n' >>.work/alpha.md
script 'RESULT="still open"'
autopilot
contains "$(call 1)" "--group A" "AC128: open high findings keep the group first"
case $(calls) in *"--group B"*) fail "AC128: group B must not start" ;; *) ok ;; esac

setup alpha:planned
stub_check
plan alpha 1:A:standard
tick_now alpha 1
script 'open_pr'
autopilot
contains "$(call 1)" "--final" "AC49: every group done goes to the final session"

setup alpha:planned
stub_check
plan alpha 1:A:deep
script 'SLEEP=4' 'finish alpha A 1' 'open_pr'
AUTOPILOT_MAX_IDLE_SECONDS=2 autopilot
same "$?" 0 "AC50: a stopped group session gets a fresh one"
contains "$(call 2)" "--group A" "AC50: for the same group"
contains "$(call 2)" "--model opus" "AC76: on the group's model"

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'finish alpha A 1; SLEEP=4' 'open_pr'
AUTOPILOT_MAX_IDLE_SECONDS=2 autopilot
contains "$(call 2)" "--group A" "AC50: ticked tasks do not end a session the watchdog stopped"

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'SLEEP=4' 'SLEEP=4'
AUTOPILOT_MAX_IDLE_SECONDS=2 autopilot
same "$(calls | wc -l | tr -d ' ')" 2 "AC130: a second watchdog stop starts nothing more"
contains "$(log_of)" "Stopped at alpha: watchdog" "AC130: the closing line says so"

setup alpha:planned
stub_check
plan alpha 1:A:deep
script 'RESULT="Which one?"' 'RESULT="ANSWER: this one"' 'finish alpha A 1' 'open_pr'
autopilot
contains "$(call 3)" "--resume s1" "AC134: a question goes to the answer session"
contains "$(call 3)" "--model opus" "AC77: the resume stays on the group's model"

setup alpha:planned
stub_check
plan alpha 1:A:deep
past=$(($(date +%s) - 300))
script "EXTRA='{\"type\":\"rate_limit_event\",\"rate_limit_info\":{\"status\":\"rejected\",\"resetsAt\":$past}}'; RESULT=limit" 'finish alpha A 1' 'open_pr'
autopilot
contains "$(call 2)" "--model opus" "AC78: after the usage limit the group keeps its model"

# --- unfinished sessions

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
script 'add_stop_line env; RESULT="no database"'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC51: an env stop is never answered"
contains "$(log_of)" "Stopped at alpha: no database" "AC51: the closing line says why"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
script 'add_stop_line tier; RESULT="retry failed too"'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC86: a failed retry is not answered"
contains "$(log_of)" "Stopped at alpha: retry failed too" "AC86: the closing line says why"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
script 'finish alpha A 1; echo more >>src.txt'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC52: ticked with uncommitted changes starts nothing more"
contains "$(log_of)" "Stopped at alpha: group A ended with its tasks ticked and uncommitted changes" "AC52: the closing line says so"
autopilot
same "$?" 2 "AC157: a finished group's uncommitted fix refuses"
same "$(git stash list | wc -l | tr -d ' ')" 0 "AC157: nothing is stashed"
same "$(cat "$work/err")" "autopilot: commit or stash your changes first." "AC157: and it says why"

setup alpha:planned
stub_check
plan alpha 1:A:standard
git checkout -q -b alpha
tick_now alpha 1
echo half >>specs/README.md
autopilot
same "$?" 2 "AC141: no open task would redo that work, so a new build refuses"
same "$(git stash list | wc -l | tr -d ' ')" 0 "AC141: nothing is stashed"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
script 'commit_task 1; tick alpha 1'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC53: no group round starts nothing more"
contains "$(log_of)" "Stopped at alpha: group A ended without a group review round" "AC53: the closing line says so"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
script 'commit_task 1; tick alpha 1; round A "1 high open"; add_stop_line hotfix; RESULT="still open"'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC20: open high findings stop the build"
contains "$(log_of)" "Stopped at alpha:" "AC20: the closing line says so"

setup alpha:planned
rm -f .work/alpha.md
script 'open_pr'
autopilot
same "$(calls)" "" "AC54: no state file starts no session"
contains "$(log_of)" "Stopped at alpha: .work/alpha.md has no tasks under Progress" "AC54: the closing line says so"

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'git checkout -q -b elsewhere; RESULT=done'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC135: a session on another branch stops the build"
contains "$(log_of)" "Stopped at alpha: the build session ended on branch elsewhere" "AC135: the closing line says so"

setup alpha:approved
stub_check
script 'printf "| x |\n" >/dev/null; mkdir -p .work; write_ticked; set_status_only alpha planned' 'open_pr'
autopilot
same "$(git log -1 --format=%s specs/README.md)" "Set alpha to planned" "AC143: the plan's status is committed before the build"

# --- plans without groups

setup alpha:planned
stub_check
threes alpha 1:standard 2:standard 3:standard 4:standard 5:deep 6:standard 7:standard
script 'finish_some alpha 1 2 3' 'finish_some alpha 4 5 6' 'finish_some alpha 7' 'open_pr'
autopilot
same "$?" 0 "AC55: a plan without groups runs through"
contains "$(call 1)" "--group 1 --tasks 1,2,3" "AC55: tasks 1 to 3"
contains "$(call 2)" "--group 2 --tasks 4,5,6" "AC55: tasks 4 to 6"
contains "$(call 3)" "--group 3 --tasks 7" "AC55: task 7"
contains "$(log_of)" "- alpha: the plan has no Group column; grouped by threes." "AC56: the run log says so"
contains "$(call 2)" "--model opus" "AC57: its highest tier sets the model"

setup alpha:planned
stub_check
threes alpha 1:standard 2:standard 3:standard 4:standard 5:standard 6:standard 7:standard
tick_now alpha 1
tick_now alpha 2
script 'finish_some alpha 3' 'finish_some alpha 4 5 6' 'finish_some alpha 7' 'open_pr'
autopilot
contains "$(call 1)" "--group 1 --tasks 3 " "AC136: the first session holds task 3 only"

setup alpha:planned
stub_check
threes alpha 1:standard 2:standard 3:standard 4:standard 5:standard 6:standard
tick_now alpha 1
tick_now alpha 2
tick_now alpha 3
script 'finish_some alpha 4 5 6' 'open_pr'
autopilot
contains "$(call 1)" "--group 2 --tasks 4,5,6" "AC137: ticked groups need no round"

# --- uncommitted changes

setup alpha:planned
stub_check
plan alpha 1:A:standard
git checkout -q -b alpha
echo half >>specs/README.md
script 'finish alpha A 1' 'open_pr'
autopilot
same "$?" 0 "AC131: a rerun with changes on the feature's branch goes on"
contains "$(git stash list)" "autopilot " "AC131: the changes are in a named stash"
contains "$(log_of)" "stashed uncommitted changes as 'autopilot " "AC132: the run log names it"

setup alpha:planned
stub_check
plan alpha 1:A:standard
git checkout -q -b alpha
echo '# changed' >>.claude/kit.conf
autopilot
same "$?" 2 "AC144: changes under .claude refuse"
same "$(git stash list | wc -l | tr -d ' ')" 0 "AC144: nothing is stashed"

setup alpha:planned
stub_check
plan alpha 1:A:standard
git checkout -q -b other
echo half >>specs/README.md
autopilot
same "$?" 2 "AC133: changes on another branch refuse"
same "$(cat "$work/err")" "autopilot: commit or stash your changes first." "AC133: with today's message"

# --- the stack stage (specs/stack-stage.md) ------------------------------------------

# stub_stack: a stack command whose `checks` exits with the next code from $fake/stack-codes (the last repeats, none is
# 0); code 1 leaves e2e/a.spec.ts red.
stub_stack() {
  rm -f "$fake/stack-codes" "$fake/stack-calls"
  sed -i.bak 's/^KIT_STACK_CHECKS=.*/KIT_STACK_CHECKS="ci"/' .claude/kit.conf && rm -f .claude/kit.conf.bak
  cat >.claude/bin/stack <<'EOF'
#!/bin/sh
echo "$*" >>"$FAKE_DIR/stack-calls"
b=$(git branch --show-current)
case $1 in
  checks)
    mkdir -p ".work/$b/stack"
    code=0
    if [ -f "$FAKE_DIR/stack-codes" ]; then
      code=$(head -n 1 "$FAKE_DIR/stack-codes")
      [ "$(wc -l <"$FAKE_DIR/stack-codes")" -le 1 ] || sed -i.bak 1d "$FAKE_DIR/stack-codes"
    fi
    if [ "$code" = 1 ]; then
      printf 'e2e/a.spec.ts\n' >".work/$b/stack/red.txt"
      printf 'e2e\tfail\t1\trelated\n' >".work/$b/stack/data-runs.tsv"
      echo "e2e: fail, red: e2e/a.spec.ts"
    else
      : >".work/$b/stack/red.txt"
      printf 'e2e\tpass\t1\trelated\n' >".work/$b/stack/data-runs.tsv"
      echo "e2e: pass"
    fi
    echo "mutation: score 80 threshold 60 killed 8 survived 2 mutants 10"
    exit "$code" ;;
esac
exit 0
EOF
  chmod +x .claude/bin/stack
  git add -A
  git commit -qm "stub stack"
}

setup alpha:planned
stub_check
stub_stack
plan alpha 1:A:standard
script 'finish alpha A 1' 'open_pr' 'stage_round "review 1 | full | a..b | pass"'
autopilot
same "$?" 0 "a green stage ends the build"
same "$(cat "$fake/stack-calls")" "checks
bodies" "STAGE-AC4: one stage run, then the descriptions"
contains "$(call 3)" "--stack review" "STAGE-AC34: a green stage gets its screenshots reviewed"
contains "$(call 3)" "--model sonnet" "the stack session runs on the verify role's model"
grep -q "${tab:-$(printf '\t')}stack${tab:-$(printf '\t')}" .work/autopilot/sessions.tsv && ok || fail "STAGE-AC37: sessions.tsv has a stack row: $(cat .work/autopilot/sessions.tsv)"

setup alpha:planned
stub_check
stub_stack
printf '1\n0\n' >"$fake/stack-codes"
plan alpha 1:A:standard
script 'finish alpha A 1' 'open_pr' 'stage_fix "1 | fix | a..b | test"' 'stage_round "review 1 | full | a..b | pass"'
autopilot
same "$?" 0 "a fixed stage ends the build"
same "$(cat "$fake/stack-calls")" "checks
checks --tests e2e/a.spec.ts
bodies" "STAGE-AC17: after a fix only the red test runs again"
contains "$(call 3)" "e2e: fail, red: e2e/a.spec.ts" "STAGE-AC19: the fix session gets the failure output"
contains "$(call 3)" "--model sonnet" "STAGE-AC19: on the verify role's model"
same "$(git branch --show-current)" "alpha" "STAGE-AC20: the fix stays on the top layer"

setup alpha:planned
stub_check
stub_stack
printf '1\n' >"$fake/stack-codes"
plan alpha 1:A:standard
script 'finish alpha A 1' 'open_pr' 'stage_fix "1 | fix | a..b | test"' 'stage_fix "2 | fix | a..b | test"' 'stage_fix "3 | fix | a..b | test"'
autopilot
same "$(calls | wc -l | tr -d ' ')" 4 "STAGE-AC21: two fixes, then no further session"
contains "$(log_of)" "Stopped at alpha: the stack stage is still red after 2 fixes" "STAGE-AC21: the closing line says so"

setup alpha:planned
stub_check
stub_stack
printf '2\n' >"$fake/stack-codes"
plan alpha 1:A:standard
script 'finish alpha A 1' 'open_pr'
autopilot
same "$(calls | wc -l | tr -d ' ')" 2 "a stage that cannot run starts no session"
contains "$(log_of)" "Stopped at alpha: the stack stage cannot run" "and the closing line says so"

# --- merge by risk (specs/risk-gates.md) ---------------------------------------------

# stub_risk <first line> [layer lines]: a risk command that prints a fixed rank; "high" exits 1.
stub_risk() {
  sed -i.bak '/^KIT_GATE_MERGE=/d' .claude/kit.conf && rm -f .claude/kit.conf.bak
  {
    echo '#!/bin/sh'
    echo "cat <<'RANK'"
    printf '%s\n' "$@"
    echo 'RANK'
    case $1 in *high*) echo 'exit 1' ;; *) echo 'exit 0' ;; esac
  } >.claude/bin/risk
  chmod +x .claude/bin/risk
  git add -A
  git commit -qm "stub risk"
}
stub_merge() {
  rm -f "$fake/stack-calls"
  cat >.claude/bin/stack <<'EOF'
#!/bin/sh
echo "$*" >>"$FAKE_DIR/stack-calls"
exit 0
EOF
  chmod +x .claude/bin/stack
  git add -A
  git commit -qm "stub stack merge"
}

setup alpha:planned
stub_check
stub_merge
stub_risk "risk 1 low" "layer alpha 1 low"
plan alpha 1:A:standard
script 'finish alpha A 1' 'open_pr'
autopilot
same "$?" 0 "RISK-AC24: a low stack merges"
contains "$(cat "$fake/stack-calls")" "merge" "RISK-AC24: through stack merge"
contains "$(log_of)" "Every feature has a PR, and the stack is merged" "RISK-AC32: the closing line says the stack is merged"

setup alpha:planned
stub_check
stub_merge
stub_risk "risk 2 high" "layer alpha 2 high" "  high: src/auth/session.ts is in KIT_PUSH_ASK_PATTERNS"
plan alpha 1:A:standard
script 'finish alpha A 1' 'open_pr'
autopilot
same "$?" 1 "RISK-AC25: a high layer stops the build"
case $(cat "$fake/stack-calls" 2>/dev/null) in *merge*) fail "RISK-AC25: no merge runs" ;; *) ok ;; esac
contains "$(log_of)" "Stopped at alpha: the pull requests of alpha wait for approval by a person: src/auth/session.ts is in KIT_PUSH_ASK_PATTERNS" "RISK-AC25: the closing line names the pull request and why"
contains "$(cat .work/alpha.md)" "| approval |" "RISK-AC25: Stops holds an approval line"
same "$(calls | wc -l | tr -d ' ')" 2 "RISK-AC26: an approval stop starts no answer session"

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'echo "$GH_CONFIG_DIR" >"$FAKE_DIR/ghdir"; finish alpha A 1' 'open_pr'
KIT_BOT_GH_CONFIG=$work/bot-gh autopilot
same "$(cat "$fake/ghdir")" "$work/bot-gh" "RISK-AC40: a session's gh uses the bot's login"
ready_err=$(.claude/bin/autopilot --ready 2>&1 >/dev/null)
contains "$ready_err" "KIT_BOT_GH_CONFIG is not set" "RISK-AC41: --ready warns that the build pushes as the developer"

setup alpha:approved
stub_check
script 'printf "# Plan: x (spec: specs/x.md)\n\n## Stops\n- plan | approval | risk 9 high: a new queue | – | user: approve the plan\n" >".work/$(git branch --show-current).md"'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "RISK-AC22: a plan that needs approval starts no group session or answer"
contains "$(log_of)" "Stopped at alpha:" "RISK-AC22: the closing line starts with Stopped at"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
printf '\n## Design\n- Architecture: none\n- Estimate: 40 lines\n' >>.work/alpha.md
script 'sed -i.bak "s/^- Estimate: 40 lines/- Estimate: 4 lines/" .work/alpha.md; finish alpha A 1'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "RISK-AC23: a session that changes the ranked lines starts nothing more"
contains "$(log_of)" "Architecture or Estimate line" "RISK-AC23: the closing line names them"

# --- the size limit

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
script 'finish alpha A 1; seq 1 900 >big.txt; git add big.txt; git commit -qm big'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC155: over the size limit after a group starts nothing more"
contains "$(log_of)" "over its size limit of 800" "AC155: the closing line names the limit"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard 3:C:standard
script 'finish alpha A 1' 'finish alpha B 2; seq 1 900 >big.txt; git add big.txt; git commit -qm "task 2: big"'
autopilot
same "$(calls | wc -l | tr -d ' ')" 2 "STACK-AC24: a group over the limit starts nothing more"
contains "$(log_of)" "(group B) has 9" "STACK-AC24: the closing line names the group"
contains "$(log_of)" "over its size limit of 800" "STACK-AC24: and the limit"

setup alpha:planned
stub_check
plan alpha 1:A:standard
printf 'Approved size: 2000 lines\n' >>.work/alpha.md
script 'finish alpha A 1; seq 1 900 >big.txt; git add big.txt; git commit -qm big' 'open_pr'
autopilot
same "$?" 0 "AC152: an approved size lets a larger branch through"

setup alpha:planned
stub_check
plan alpha 1:A:standard
printf 'Approved size: 2000 lines\n' >>.work/alpha.md
script 'sed -i.bak "s/^Approved size: 2000/Approved size: 9000/" .work/alpha.md; finish alpha A 1'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC156: a session that changes the limit stops the build"
contains "$(log_of)" "Approved size" "AC156: the closing line names it"

# --- asking before a push

setup alpha:planned
stub_check
plan alpha 1:A:standard
tick_now alpha 1
script 'add_stop_line push; RESULT="verified; push needs approval"'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC117: a push stop goes to no answer session"
contains "$(log_of)" "Stopped at alpha: verified; push needs approval" "AC41: the closing line says so"

setup alpha:planned
stub_check
plan alpha 1:A:standard
tick_now alpha 1
printf -- '- verify 1 | full | a..b | pass\n' >>.work/alpha.md
git checkout -q -b alpha
mkdir -p .work/alpha/evidence
printf '{\n  "head": "%s"\n}\n' "$(git rev-parse HEAD)" >.work/alpha/evidence/evidence.json
echo 'KIT_GATE_PUSH="ask"' >>.claude/kit.conf
git add -A
git commit -qm "push asks"
printf '{\n  "head": "%s"\n}\n' "$(git rev-parse HEAD)" >.work/alpha/evidence/evidence.json
autopilot
same "$(calls)" "" "AC119: a verified feature waiting for its push starts no session"
contains "$(log_of)" "the push gate asks" "AC119: the closing line names the push"

# --- one build at a time

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'echo $$ >"$FAKE_DIR/session-pid"; SLEEP=60'
(AUTOPILOT_MAX_IDLE_SECONDS=120 .claude/bin/autopilot >"$work/out" 2>"$work/err") &
_tries=0
until [ -f .work/autopilot/lock/pid ] && [ -f "$fake/calls" ]; do sleep 1; _tries=$((_tries + 1)); [ "$_tries" -lt 20 ] || break; done
_build=$(head -n 1 .work/autopilot/lock/pid)
autopilot
same "$?" 2 "AC58: a second build is refused"
same "$(cat "$work/err")" "autopilot: a build is already running (pid $_build). Stop it with .claude/bin/autopilot --stop." "AC58: with the message"
autopilot
same "$?" 2 "AC138: a third build is refused too"
same "$(.claude/bin/autopilot --ready >/dev/null; echo $?)" 1 "--ready says a build is running"
_stop_out=$(.claude/bin/autopilot --stop)
contains "$_stop_out" "stopped the build (pid $_build)" "AC60: --stop reports it"
if kill -0 "$_build" 2>/dev/null; then fail "AC60: the build's process has ended"; else ok; fi
if kill -0 "$(cat "$fake/session-pid")" 2>/dev/null; then fail "AC60: the session has ended"; else ok; fi
contains "$(log_of)" "Stopped at alpha: stopped by .claude/bin/autopilot --stop" "AC139: the closing line says so"
if [ -d .work/autopilot/lock ]; then fail "AC61: the lock is gone"; else ok; fi
wait
rm -f "$fake/calls" "$fake/n"
script 'finish alpha A 1' 'open_pr'
autopilot
same "$?" 0 "AC61, AC63: a new build runs after a stopped one"
same "$(.claude/bin/autopilot --stop)" "autopilot: no build is running." "AC62: --stop with no build"
same "$(.claude/bin/autopilot --ready >/dev/null 2>&1; echo $?)" 0 "--ready says it can start"
ready_err=$(.claude/bin/autopilot --ready 2>&1 >/dev/null)
contains "$ready_err" "gh extension install github/gh-stack" "STACK-AC28: --ready warns that gh stack is missing"
same "$(.claude/bin/autopilot --ready >/dev/null 2>&1; echo $?)" 0 "STACK-AC28: and still says it can start"
contains "$(log_of)" "gh stack is not installed" "STACK-AC9: the run log names the missing gh stack"

setup alpha:planned
stub_check
plan alpha 1:A:standard
sleep 30 &
_other=$!
mkdir -p .work/autopilot/lock
echo "$_other" >.work/autopilot/lock/pid
same "$(.claude/bin/autopilot --stop)" "autopilot: no build is running." "AC140: another process's pid is no build"
if kill -0 "$_other" 2>/dev/null; then ok; else fail "AC140: that process got no signal"; fi
kill "$_other" 2>/dev/null
wait "$_other" 2>/dev/null
mkdir -p .work/autopilot/lock
echo 999999 >.work/autopilot/lock/pid
script 'finish alpha A 1' 'open_pr'
autopilot
same "$?" 0 "AC59: a stale lock does not block"

# --- started by /ship-feature

ship() { .claude/bin/autopilot --ship "$@" >"$work/out" 2>"$work/err"; }
ship_wait() {
  _tries=0
  while [ -d .work/autopilot/lock ] && [ "$_tries" -lt 40 ]; do sleep 1; _tries=$((_tries + 1)); done
}

setup alpha:planned
stub_check
# These criteria are about a project at strict, which is no longer the default (specs/risk-gates.md).
printf 'KIT_APPROVAL="strict"\n' >>.claude/kit.conf
git commit -qam "strict"
git checkout -q -b 12-invite
plan 12-invite 1:A:standard
printf 'Base: develop\n' >/dev/null
git branch develop main
sed -i.bak '1a\
Base: develop' .work/12-invite.md
gates='for g in commit deps config push; do echo "$g=$(.claude/bin/gate $g)"; done >"$FAKE_DIR/gates-$n"; echo "improve=${KIT_IMPROVE:-empty} claudecode=${CLAUDECODE:-none} branch=$(git branch --show-current) base=${KIT_BASE:-none} level=$(.claude/bin/gate level)" >"$FAKE_DIR/env-$n"'
script "$gates; finish 12-invite A 1" "$gates; RESULT=asks; add_stop_line push"
CLAUDECODE=1 ship alpha
same "$?" 0 "AC35: --ship starts a build"
contains "$(cat "$work/out")" "Run log: .work/autopilot/run-" "AC35: it prints the run log's path"
contains "$(cat "$work/out")" "Do not edit this checkout until the build ends." "AC37: it says to leave the checkout alone"
if command -v setsid >/dev/null 2>&1; then
  _running=$(head -n 1 .work/autopilot/lock/pid 2>/dev/null)
  if [ -n "$_running" ] && [ "$(ps -o sid= -p "$_running" | tr -d ' ')" = "$(ps -o sid= -p $$ | tr -d ' ')" ]; then fail "AC36: the build runs in its own session"; else ok; fi
fi
ship_wait
same "$(cat "$fake/gates-1" | tr '\n' ' ')" "commit=auto deps=auto config=auto push=ask " "AC39, AC111, AC112: build gates are auto at strict"
same "$(cat "$fake/gates-2" | tr '\n' ' ')" "commit=auto deps=auto config=auto push=ask " "AC147, AC40: the final session commits and still asks to push"
same "$(cat "$fake/env-1")" "improve=empty claudecode=none branch=12-invite base=develop level=strict" "AC103, AC104, AC105, AC106: the session keeps this branch, base and level"
contains "$(log_of)" "Stopped at alpha: asks" "AC41: an asked-for push stops the build"
if [ -d .work/autopilot/lock ]; then fail "the lock is gone after the build"; else ok; fi

setup alpha:planned
stub_check
git checkout -q -b alpha
plan alpha 1:A:standard
{ echo 'KIT_APPROVAL="strict"'; echo 'KIT_GATE_COMMIT="ask"'; echo 'KIT_GATE_DEPS="ask"'; echo 'KIT_GATE_CONFIG="ask"'; } >>.claude/kit.conf
git add -A
git commit -qm "explicit gates"
script "$gates; finish alpha A 1" 'open_pr'
ship alpha
ship_wait
same "$(cat "$fake/gates-1" | tr '\n' ' ')" "commit=auto deps=ask config=ask push=ask " "AC110, AC148, AC113, AC114: an explicit ask stays, except for commits"

setup alpha:planned
stub_check
git checkout -q -b alpha
plan alpha 1:A:standard
(KIT_BUDGET_TOKENS="" ship alpha)
same "$?" 2 "AC102: a failed preflight refuses"
contains "$(cat "$work/err")" "KIT_BUDGET_TOKENS" "AC102: it prints the reason"
if [ -d .work/autopilot/lock ]; then fail "AC102: no lock remains"; else ok; fi
same "$(KIT_BUDGET_TOKENS=100k .claude/bin/autopilot --ready >/dev/null; echo $?)" 2 "AC126: --ready refuses an invalid budget"

setup alpha:approved
script "$gates"
.claude/bin/autopilot >"$work/out" 2>"$work/err"
same "$(sed -n 's/.*level=//p' "$fake/env-1")" "autonomous" "AC43: a build from a shell stays autonomous"

setup alpha:planned
stub_check
plan alpha 1:A:standard
tick_now alpha 1
git checkout -q -b alpha
script 'open_pr'
same "$(.claude/bin/usage tsv | cut -f 9)" 1 "AC66: the tasks field counts ticked tasks"

# --- found by the code review: each of these failed before its fix

# hold_lock <pid>: the lock as a build writes it.
hold_lock() { { echo "$1"; LC_ALL=C TZ=UTC ps -p "$1" -o lstart=; } >.work/autopilot/lock/pid; }

# Review 1: a starter that has made the lock but not yet written its pid still owns it.
setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'finish alpha A 1' 'open_pr'
mkdir -p .work/autopilot/lock
sleep 30 &
_holder=$!
(sleep 1; hold_lock "$_holder") &
_writer=$!
autopilot
same "$?" 2 "lock: a lock still being written is not taken over"
same "$(calls)" "" "lock: no session starts while another starter holds the lock"
wait "$_writer" 2>/dev/null
kill "$_holder" 2>/dev/null
wait "$_holder" 2>/dev/null

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'finish alpha A 1' 'open_pr'
mkdir -p .work/autopilot/lock
autopilot
same "$?" 0 "lock: a lock that never gets a pid counts as stale"

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'finish alpha A 1; SLEEP=4' 'open_pr'
for _i in 1 2 3 4; do
  (.claude/bin/autopilot >"$work/out-$_i" 2>&1; echo $? >"$work/code-$_i") &
done
wait
same "$(cat "$work"/code-[1-4] | sort | tr '\n' ' ')" "0 2 2 2 " "lock: of four builds started together, one runs"
same "$(calls | grep -c -- '--group A' | tr -d ' ')" 1 "lock: and group A starts once"

# Review 2: a check repair is held to the same rules as any session.
setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
printf 'Approved size: 2000 lines\n' >>.work/alpha.md
codes typecheck 1 0
script 'finish alpha A 1' 'sed -i.bak "s/^Approved size: 2000/Approved size: 9000/" .work/alpha.md' 'finish alpha B 2' 'open_pr'
autopilot
same "$(calls | wc -l | tr -d ' ')" 2 "AC156: a repair that changes the limit starts nothing more"
contains "$(log_of)" "Approved size" "AC156: the closing line names it"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
codes typecheck 1 0
script 'finish alpha A 1' 'git checkout -q -b elsewhere' 'finish alpha B 2' 'open_pr'
autopilot
same "$(calls | wc -l | tr -d ' ')" 2 "AC135: a repair on another branch starts nothing more"
contains "$(log_of)" "ended on branch elsewhere" "AC135: the closing line names the branch"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
codes typecheck 1 0
script 'finish alpha A 1' 'sed -i.bak "s/^- \[x\] 1 /- [ ] 1 /" .work/alpha.md' 'finish alpha B 2' 'open_pr'
autopilot
same "$(calls | wc -l | tr -d ' ')" 2 "AC26: a group no longer done after its repair starts nothing more"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
codes typecheck 1 0
script 'finish alpha A 1' 'add_stop_line spec; RESULT="AC3 cannot be tested"' 'finish alpha B 2' 'open_pr'
autopilot
same "$(calls | wc -l | tr -d ' ')" 2 "a repair that records a stop starts nothing more"
contains "$(log_of)" "stopped: spec" "and the stop's class closes the build"

# Found while fixing review 2: a session with no result line must not resume the group before it.
setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
codes typecheck 0 1
script 'finish alpha A 1' 'finish alpha B 2; exit 0' 'open_pr'
autopilot
same "$(calls | wc -l | tr -d ' ')" 2 "AC24: a failed check with no session id to resume starts nothing more"
contains "$(log_of)" "Stopped at alpha: group B" "AC24: the closing line names the group"

# Review 3: --stop ends the answerer too.
setup alpha:planned
stub_check
plan alpha 1:A:standard
rm -f "$fake/session-pid"
script 'RESULT="Which one?"' 'echo $$ >"$FAKE_DIR/session-pid"; SLEEP=60'
(AUTOPILOT_MAX_IDLE_SECONDS=120 .claude/bin/autopilot >"$work/out" 2>"$work/err") &
_tries=0
until [ -f "$fake/session-pid" ]; do sleep 1; _tries=$((_tries + 1)); [ "$_tries" -lt 20 ] || break; done
.claude/bin/autopilot --stop >"$work/stop-out" 2>&1
same "$?" 0 "AC60: --stop ends a build while the answerer runs"
if kill -0 "$(cat "$fake/session-pid")" 2>/dev/null; then fail "AC60: the answerer has ended"; else ok; fi
contains "$(log_of)" "Stopped at alpha: stopped by .claude/bin/autopilot --stop" "AC139: the closing line says so"
wait

# Review 4: a process that ignores TERM cannot hold the build up.
setup alpha:planned
stub_check
plan alpha 1:A:standard
echo 30 >"$fake/sleep-typecheck"
touch "$fake/ignore-term"
script 'finish alpha A 1'
_before=$(date +%s)
AUTOPILOT_MAX_SESSION_SECONDS=2 AUTOPILOT_KILL_GRACE_SECONDS=1 autopilot
same "$?" 1 "AC94: a check that ignores TERM stops the build"
if [ $(($(date +%s) - _before)) -lt 20 ]; then ok; else fail "AC94: the build did not wait the check out"; fi
contains "$(log_of)" "Stopped at alpha: a check ran longer than 2 s" "AC94: the closing line says so"
rm -f "$fake/sleep-typecheck" "$fake/ignore-term"

setup alpha:planned
stub_check
plan alpha 1:A:standard
rm -f "$fake/session-pid"
script 'trap "" TERM; echo $$ >"$FAKE_DIR/session-pid"; SLEEP=60'
(AUTOPILOT_MAX_IDLE_SECONDS=120 AUTOPILOT_KILL_GRACE_SECONDS=1 .claude/bin/autopilot >"$work/out" 2>"$work/err") &
_tries=0
until [ -f "$fake/session-pid" ]; do sleep 1; _tries=$((_tries + 1)); [ "$_tries" -lt 20 ] || break; done
.claude/bin/autopilot --stop >"$work/stop-out" 2>&1
same "$?" 0 "AC60: --stop ends a build whose session ignores TERM"
if kill -0 "$(cat "$fake/session-pid")" 2>/dev/null; then fail "AC60: that session has ended"; else ok; fi
wait

# Review 5: only the process that took the lock is a build.
setup alpha:planned
stub_check
plan alpha 1:A:standard
sh -c 'sleep 30; :' /elsewhere/.claude/bin/autopilot &
_other=$!
mkdir -p .work/autopilot/lock
echo "$_other" >.work/autopilot/lock/pid
same "$(.claude/bin/autopilot --stop)" "autopilot: no build is running." "AC140: a command line that names autopilot is no build"
if kill -0 "$_other" 2>/dev/null; then ok; else fail "AC140: that process got no signal"; fi
mkdir -p .work/autopilot/lock
printf '%s\nMon Jan  1 00:00:00 2001\n' "$_other" >.work/autopilot/lock/pid
same "$(.claude/bin/autopilot --stop)" "autopilot: no build is running." "AC140: nor is a reused pid"
if kill -0 "$_other" 2>/dev/null; then ok; else fail "AC140: the reused pid got no signal"; fi
kill "$_other" 2>/dev/null
wait "$_other" 2>/dev/null

# Review 6: the budget holds after every session that leaves work to do.
setup alpha:approved
stub_check
script 'mkdir -p .work; write_ticked; spend 100000; set_status alpha planned' 'open_pr'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC149: a plan session that reaches the budget starts nothing more"
contains "$(log_of)" "budget reached" "AC149: the closing line names the budget"

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'RESULT="Which one?"' 'spend 100000; RESULT="ANSWER: the first"' 'open_pr'
autopilot
same "$(calls | wc -l | tr -d ' ')" 2 "AC149: an answerer that reaches the budget resumes nothing"
contains "$(log_of)" "budget reached" "AC149: the closing line names the budget"

setup alpha:planned
stub_check
plan alpha 1:A:standard
script 'finish alpha A 1' 'spend 100001; open_pr'
autopilot
same "$?" 0 "a final session that opened its PR is not stopped by the budget"
contains "$(log_of)" "Every feature has a PR" "AC100: nothing is left for the budget to stop"

# Review 7: a fresh session only gets the tasks still open.
setup alpha:planned
stub_check
plan alpha 1:A:standard 2:A:standard 3:A:standard
script 'finish_some alpha 1; SLEEP=4' 'finish alpha A 2 3' 'open_pr'
AUTOPILOT_MAX_IDLE_SECONDS=2 autopilot
contains "$(call 1)" "--tasks 1,2,3 --from " "AC50: the first session gets all three"
contains "$(call 2)" "--tasks 2,3 --from " "AC50: the fresh session gets only what is open"
same "$(call 2 | sed 's/.*--from \([^ ]*\).*/\1/')" "$(call 1 | sed 's/.*--from \([^ ]*\).*/\1/')" "AC129: the group diff keeps its start"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:A:standard
past=$(($(date +%s) - 300))
script "finish_some alpha 1; EXTRA='{\"type\":\"rate_limit_event\",\"rate_limit_info\":{\"status\":\"rejected\",\"resetsAt\":$past}}'; RESULT=limit" 'finish alpha A 2' 'open_pr'
autopilot
contains "$(call 2)" "--tasks 2 --from " "AC78: after the usage limit too"

# Review 8: a stash that fails stops the build.
setup alpha:planned
stub_check
plan alpha 1:A:standard
git checkout -q -b alpha
echo one >conflict.txt
git add conflict.txt
git commit -qm conflict
git checkout -q -b theirs
echo two >conflict.txt
git commit -qam theirs
git checkout -q alpha
echo three >conflict.txt
git commit -qam ours
git merge theirs >/dev/null 2>&1
script 'finish alpha A 1' 'open_pr'
autopilot
same "$?" 2 "a stash that fails stops the build"
same "$(calls)" "" "no session starts on the changes it could not stash"
contains "$(log_of)" "Stopped at the start: could not stash" "the closing line says so"
case $(log_of) in *"stashed uncommitted changes"*) fail "the run log does not claim a stash" ;; *) ok ;; esac

# Review 9: the size limit also holds before a repair and on a rerun.
setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
codes typecheck 1 0
script 'finish alpha A 1; seq 1 900 >big.txt; git add big.txt; git commit -qm big' 'RESULT=fixed' 'finish alpha B 2'
autopilot
same "$(calls | wc -l | tr -d ' ')" 1 "AC155: over the limit with a failed check starts no repair"
contains "$(log_of)" "over its size limit of 800" "AC155: the closing line names the limit"
rm -f "$fake/calls" "$fake/n" .work/autopilot/run-*.md
codes typecheck 0
autopilot
same "$(calls)" "" "AC155: a rerun over the limit starts nothing"
contains "$(log_of)" "over its size limit of 800" "AC155: and says so"

# Review 10: a task may name an HTML tag; only the template's placeholder is no task.
setup alpha:planned
stub_check
plan alpha 1:A:standard 2:A:standard
sed -i.bak 's/^- \[ \] 2 t$/- [ ] 2 Render <dialog> on small screens/' .work/alpha.md
script 'finish alpha A 1 2' 'open_pr'
autopilot
contains "$(call 1)" "--tasks 1,2 --from " "a task that names a tag is a task"
same "$(.claude/bin/usage tsv | cut -f 9)" 2 "and the usage record counts it"
contains "$(.claude/bin/status --line)" "tasks 2/2" "and so does the status command"

setup alpha:planned
stub_check
git checkout -q -b alpha
printf '# Plan: x (spec: specs/x.md)\n\n## Progress\n- [ ] 1 <task>\n' >.work/alpha.md
script 'open_pr'
autopilot
same "$(calls)" "" "AC54: the template's placeholder is no task"
contains "$(log_of)" "has no tasks under Progress" "AC54: the closing line says so"

# Review 11: a state file with CRLF line ends reads the same.
crlf() { awk '{ printf "%s\r\n", $0 }' "$1" >"$1.new" && mv "$1.new" "$1"; }
setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
tick_now alpha 1
crlf .work/alpha.md
script 'RESULT="Which one?"' 'RESULT="ESCALATE: stop here"'
autopilot
contains "$(call 1)" "--group A" "AC127: CRLF: a ticked group with no round is still first"

setup alpha:planned
stub_check
plan alpha 1:A:standard 2:A:standard 3:A:standard 4:A:standard
crlf .work/alpha.md
autopilot
same "$(calls)" "" "AC6: CRLF: a group of four starts nothing"
contains "$(log_of)" "at most 3 tasks" "AC6: CRLF: the closing line says so"

# Review 12: a killed session counts once.
setup alpha:planned
git checkout -q -b alpha
mkdir -p .work/alpha
killed_tokens='{"type":"assistant","message":{"id":"msg_1","model":"m","usage":{"input_tokens":5000,"output_tokens":0}},"session_id":"s1"}'
printf '{"type":"system","subtype":"init","session_id":"s1"}\n%s\n' "$killed_tokens" >"$work/killed.jsonl"
printf 'main:s1\tm\t4000\t0\t0\t0\n' >.work/alpha/usage.tsv
.claude/bin/usage add-killed "$work/killed.jsonl"
same "$(.claude/bin/usage total)" 5000 "AC123: tokens the hook already recorded count once"
printf 'main:s1\tm\t13000\t0\t0\t0\n' >.work/alpha/usage.tsv
.claude/bin/usage add-killed "$work/killed.jsonl"
same "$(.claude/bin/usage total)" 13000 "AC123: a resumed session keeps its larger record"
printf 'agent1\tm\t700\t0\t0\t0\n' >.work/alpha/usage.tsv
.claude/bin/usage add-killed "$work/killed.jsonl"
same "$(.claude/bin/usage total)" 5700 "AC123: a session the hook never saw adds its tokens"

# Review 13: --ship reports a child that refused to start.
setup alpha:planned
stub_check
git checkout -q -b alpha
plan alpha 1:A:standard
echo half >>specs/README.md
echo 1 >"$fake/pr-after"
script 'finish alpha A 1' 'open_pr'
ship alpha
same "$?" 2 "--ship: a build that refuses to start is not reported as started"
contains "$(cat "$work/err")" "commit or stash your changes first." "--ship: with the build's reason"
case $(cat "$work/out") in *"build started"*) fail "--ship: it does not claim a start" ;; *) ok ;; esac
if [ -d .work/autopilot/lock ]; then fail "AC102: no lock remains"; else ok; fi
same "$(calls)" "" "--ship: no session starts"

# Review 14: changes made after the earlier stop's fix was committed are not that fix.
setup alpha:planned
stub_check
plan alpha 1:A:standard 2:B:standard
script 'finish alpha A 1; echo more >>src.txt'
autopilot
git add src.txt
git commit -qm "the fix"
echo half >>specs/README.md
rm -f "$fake/calls" "$fake/n"
script 'finish alpha B 2' 'open_pr'
autopilot
same "$?" 0 "AC131: with the old fix committed, new changes stash as usual"
contains "$(git stash list)" "autopilot " "AC131: they are in the named stash"

# Review 15: a rename into .claude is a change under .claude.
setup alpha:planned
stub_check
plan alpha 1:A:standard
git checkout -q -b alpha
echo helper >helper.txt
git add helper.txt
git commit -qm helper
git mv helper.txt .claude/helper.txt
autopilot
same "$?" 2 "AC144: a rename into .claude refuses"
same "$(git stash list | wc -l | tr -d ' ')" 0 "AC144: nothing is stashed"

# Review 16: a status row the plan session only staged is committed too, and alone.
setup alpha:approved
stub_check
script 'mkdir -p .work; write_ticked; set_status_only alpha planned; git add specs/README.md; echo other >other.txt; git add other.txt' 'open_pr'
autopilot
same "$(git log -1 --format=%s specs/README.md)" "Set alpha to planned" "AC143: a staged status row is committed"
same "$(git show --name-only --format= "$(git log -1 --format=%H specs/README.md)")" "specs/README.md" "AC143: and nothing else with it"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
