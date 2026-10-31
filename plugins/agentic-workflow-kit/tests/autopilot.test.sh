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
printf '%s|%s|%s|%s|%s\n' "$(git branch --show-current)" "${KIT_BASE:-}" "${KIT_APPROVAL:-}" "${KIT_IMPROVE:-}" "$*" >>"$FAKE_DIR/calls"
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
eval "$(sed -n "${n}p" "$FAKE_DIR/script")"
printf '{"type":"system","subtype":"init"}\n{"type":"result","session_id":"s%s","result":"%s","permission_denials":[%s]}\n' "$n" "$RESULT" "$DENIED"
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

setup alpha:approved
same "$(KIT_IMPROVE=1 .claude/bin/runs report)" "No run records in reports/runs/ yet." "KIT_IMPROVE from the environment turns run records on"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
