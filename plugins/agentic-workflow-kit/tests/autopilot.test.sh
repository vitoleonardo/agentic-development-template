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
printf '%s|%s|%s|%s|%s|%s\n' "$(git branch --show-current)" "${KIT_BASE:-}" "${KIT_APPROVAL:-}" "${KIT_IMPROVE:-}" "${KIT_AUTOPILOT_RUN:-}" "$*" >>"$FAKE_DIR/calls"
n=$(($(cat "$FAKE_DIR/n" 2>/dev/null || echo 0) + 1))
echo "$n" >"$FAKE_DIR/n"
set_status() {
  awk -F '|' -v OFS='|' -v s="$1.md" -v t="$2" '{ x = $3; gsub(/[ `]/, "", x) } x == s || index(x, "[" s "]") == 1 { $4 = " " t " " } 1' specs/README.md >"$FAKE_DIR/readme"
  cat "$FAKE_DIR/readme" >specs/README.md
  git commit -qam "status $1 $2"
}
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
printf '{"type":"system","subtype":"init","session_id":"s%s"}\n' "$n"

[ -z "$EXTRA" ] || printf '%s\n' "$EXTRA"
sleep "$SLEEP"
printf '{"type":"result","session_id":"s%s","result":"%s","num_turns":%s,"total_cost_usd":%s,"permission_denials":[%s]}\n' "$n" "$RESULT" "$TURNS" "$COST" "$DENIED"
EOF
cat >"$work/bin/gh" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr view") awk -v b="$3" '$1 == b { print $2; found = 1 } END { exit !found }' "$FAKE_DIR/prs" 2>/dev/null ;;
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
  rm -f "$fake/calls" "$fake/n" "$fake/untrusted" "$fake/prs"
  : >"$fake/script"
  cd "$project" || exit 1
  printf '.work/\n' >.gitignore
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
same "$(ls .work/autopilot/*-alpha-build.jsonl | wc -l | tr -d ' ')" 2 "a second run keeps the first run's transcripts"

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

# --- run lock, start, stop, steer --------------------------------------------------

wait_until() {
  _tries=0
  until eval "$1"; do
    _tries=$((_tries + 1))
    [ "$_tries" -lt "$2" ] || return 1
    sleep 1
  done
}
lock_file=.work/autopilot/lock

setup alpha:planned
script "cat $lock_file >\"\$FAKE_DIR/lock-seen\"; set_status alpha in-review; open_pr"
autopilot
same "$?" 0 "STEER-AC1: a run with a lock runs through"
run=$(ls .work/autopilot/run-*.md | sed 's|.*/run-||; s|\.md$||')
same "$(cut -d ' ' -f 2 "$fake/lock-seen")" "$run" "STEER-AC1: the lock names the run while a session runs"
[ -n "$(cut -d ' ' -f 1 "$fake/lock-seen")" ] && ok || fail "STEER-AC1: the lock names the process"
[ ! -e "$lock_file" ] && ok || fail "STEER-AC1: a finished run removes its lock"
same "$(call 1 | cut -d '|' -f 5)" "$run" "STEER-AC1: the session knows its run"

setup alpha:planned
script 'RESULT="ESCALATE: stop"' 'RESULT="ESCALATE: stop"'
autopilot
same "$?" 1 "STEER-AC1: a stopped run halts"
[ ! -e "$lock_file" ] && ok || fail "STEER-AC1: a halted run removes its lock"

setup alpha:planned
script "SLEEP=30" "set_status alpha in-review; open_pr"
.claude/bin/autopilot >"$work/out" 2>"$work/err" &
pilot=$!
wait_until '[ -s "$fake/calls" ]' 10
kill "$pilot"
wait "$pilot"
[ ! -e "$lock_file" ] && ok || fail "STEER-AC1: a terminated run removes its lock"

setup alpha:planned
mkdir -p .work/autopilot
sh -c 'sleep 60; :' autopilot-holder &
holder=$!
printf '%s 20261102-120000\n' "$holder" >"$lock_file"
autopilot
same "$?" 2 "STEER-AC2: a second run is refused"
same "$(cat "$work/err")" "autopilot: run 20261102-120000 is already running (pid $holder). Stop it with .claude/bin/autopilot stop." "STEER-AC2: the refusal names the running run"
autopilot start
same "$?" 2 "STEER-AC2: a second start is refused"
same "$(cat "$work/err")" "autopilot: run 20261102-120000 is already running (pid $holder). Stop it with .claude/bin/autopilot stop." "STEER-AC2: start names the running run"
same "$(calls)" "" "STEER-AC2: no session starts beside a running run"

setup alpha:planned
script "set_status alpha in-review; open_pr"
mkdir -p .work/autopilot
printf '%s 20261102-120000\n' "$holder" >"$lock_file"
autopilot steer "keep the CSV columns as in the spec"
same "$?" 0 "STEER-AC12: a message to a running run is queued"
same "$(cat "$work/out")" "autopilot: message queued; the session reads it after its next tool call." "STEER-AC12: the queueing is confirmed"
same "$(cat .work/autopilot/steer/20261102-120000-*-0001-*.md)" "keep the CSV columns as in the spec" "STEER-AC12: the message holds the text, named after the run"
autopilot steer "   "
same "$?" 2 "STEER-AC13: a blank message is refused"
same "$(ls .work/autopilot/steer/*.md | wc -l | tr -d ' ')" 1 "STEER-AC13: a blank message queues nothing"
autopilot stop &
stopper=$!
wait_until '[ -e .work/autopilot/stop ]' 5 && ok || fail "STEER-AC6: the stop is requested"
kill "$holder"
wait "$holder" 2>/dev/null
wait "$stopper"
same "$?:$(cat "$work/out")" "0:autopilot: stopped run 20261102-120000." "STEER-AC6: stop returns once the run has stopped"
sleep 60 &
reused=$!
printf '%s 20261102-120000\n' "$reused" >"$lock_file"
autopilot
code=$?
kill "$reused"
wait "$reused" 2>/dev/null
same "$code" 0 "STEER-AC3: a lock whose process is no autopilot does not block the run"
same "$(calls | wc -l | tr -d ' ')" 1 "STEER-AC11: a stop left from an earlier run does not stop the new run"

setup alpha:planned
autopilot stop
same "$?:$(cat "$work/err")" "1:autopilot: no run is running." "STEER-AC10: stop without a run"
autopilot steer "hello"
same "$?:$(cat "$work/err")" "1:autopilot: no run is running." "STEER-AC10: steer without a run"

setup alpha:planned
script "sleep 2; set_status alpha in-review; open_pr"
autopilot start alpha
same "$?" 0 "STEER-AC4: start returns while the run goes on"
run=$(ls .work/autopilot/run-*.md | sed 's|.*/run-||; s|\.md$||')
same "$(cat "$work/out")" "autopilot: started run $run. Run log: .work/autopilot/run-$run.md" "STEER-AC4: start names the run and its log"
[ -e "$lock_file" ] && ok || fail "STEER-AC4: the run is still running after start returned"
wait_until '[ ! -e "$lock_file" ]' 20
contains "$(cat .work/autopilot/run-*.md)" "Every feature has a PR" "STEER-AC4: the detached run finishes on its own"

setup alpha:planned
(KIT_BUDGET_TOKENS="" autopilot start)
same "$?" 2 "STEER-AC5: a failed check fails the start with its code"
contains "$(cat "$work/err")" "KIT_BUDGET_TOKENS" "STEER-AC5: the start prints the check's message"
[ ! -e "$lock_file" ] && ok || fail "STEER-AC5: a failed start leaves no lock"

setup alpha:planned
script "SLEEP=30" "set_status alpha in-review; open_pr"
.claude/bin/autopilot >"$work/out" 2>"$work/err" &
pilot=$!
wait_until '[ -s "$fake/calls" ]' 10
asked=$(date +%s)
.claude/bin/autopilot stop >"$work/stop-out"
wait "$pilot"
code=$?
took=$(($(date +%s) - asked))
same "$code" 1 "STEER-AC6: a stopped run exits 1"
[ "$took" -le 5 ] && ok || fail "STEER-AC6: the session ends within 5 s, took $took s"
log=$(cat .work/autopilot/run-*.md)
contains "$log" "| alpha | alpha | stopped: user | stopped by the user | s1 |" "STEER-AC6: the run log has the stopped row"
contains "$log" "Stopped at alpha: stopped by the user" "STEER-AC6: the run log has the closing line"
contains "$(cat "$work/err")" "claude --resume s1" "STEER-AC7: the resume command names the session from its first line"
contains "$(cat "$work/stop-out")" "Resume it with: claude --resume s1" "STEER-AC6: stop prints the resume command"
contains "$(cat .work/alpha.md)" "- stopped-by-user | build session | " "STEER-AC9: the stop is logged under Decisions to review"
contains "$(cut -f 9 .work/autopilot/sessions.tsv | tail -n 1)" "user" "STEER-AC6: the session row says the user ended it"
[ ! -e .work/autopilot/stop ] && ok || fail "STEER-AC6: the stop request is used up"

setup alpha:approved
script ": >.work/autopilot/stop; set_status alpha planned" "set_status alpha in-review; open_pr"
autopilot
same "$?" 1 "STEER-AC8: a stop between sessions stops the run"
same "$(calls | wc -l | tr -d ' ')" 1 "STEER-AC8: the next session does not start"
contains "$(cat .work/autopilot/run-*.md)" "Stopped at alpha: stopped by the user" "STEER-AC8: the run log has the closing line"
contains "$(cat .work/alpha.md)" "- stopped-by-user | " "STEER-AC9: the stop between sessions is logged under Decisions to review"

setup alpha:planned
script "SLEEP=30" "set_status alpha in-review; open_pr"
AUTOPILOT_POLL_SECONDS=60 .claude/bin/autopilot >"$work/out" 2>"$work/err" &
pilot=$!
wait_until '[ -s "$fake/calls" ]' 10
asked=$(date +%s)
.claude/bin/autopilot stop >/dev/null
wait "$pilot"
took=$(($(date +%s) - asked))
[ "$took" -le 5 ] && ok || fail "STEER-AC6: with the default poll the session ends within 5 s, took $took s"

setup alpha:planned
script 'RESULT="Which columns?"' 'RESULT="ANSWER: the ones in the spec"' "set_status alpha in-review; open_pr"
autopilot
contains "$(call 2)" "You answer one question" "STEER-AC17: the second call is the answerer"
same "$(call 2 | cut -d '|' -f 5)" "" "STEER-AC17: the answerer does not get the run, so it gets no messages"
same "$(call 3 | cut -d '|' -f 5)" "$(ls .work/autopilot/run-*.md | sed 's|.*/run-||; s|\.md$||')" "STEER-AC17: the resumed session gets the run"

setup alpha:planned
script 'RESULT="Which columns?"' 'SLEEP=30; RESULT="ANSWER: late"'
.claude/bin/autopilot >"$work/out" 2>"$work/err" &
pilot=$!
wait_until '[ "$(calls | wc -l | tr -d " ")" -ge 2 ]' 10
asked=$(date +%s)
.claude/bin/autopilot stop >/dev/null
wait "$pilot"
took=$(($(date +%s) - asked))
[ "$took" -le 6 ] && ok || fail "STEER-AC6: a stop during the answerer ends it within 5 s, took $took s"
same "$(grep -c 'stopped:' .work/autopilot/run-*.md)" 1 "STEER-AC6: a stop during the answerer writes one stopped row"
contains "$(cat .work/autopilot/run-*.md)" "| alpha | alpha | stopped: user |" "STEER-AC6: the answerer's stop is the user's"

setup alpha:planned
future=$(($(date +%s) + 3600))
script "EXTRA='{\"type\":\"rate_limit_event\",\"rate_limit_info\":{\"status\":\"rejected\",\"resetsAt\":$future}}'; RESULT='You have hit your limit'"
.claude/bin/autopilot >"$work/out" 2>"$work/err" &
pilot=$!
wait_until 'grep -q "waits for the usage limit" .work/autopilot/run-*.md 2>/dev/null' 10
asked=$(date +%s)
.claude/bin/autopilot stop >/dev/null
wait "$pilot"
took=$(($(date +%s) - asked))
[ "$took" -le 5 ] && ok || fail "STEER-AC8: a stop during a usage-limit wait stops within 5 s, took $took s"
contains "$(cat .work/autopilot/run-*.md)" "Stopped at alpha: stopped by the user" "STEER-AC8: the wait ends in a user stop"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
