#!/bin/sh
# Tests for .claude/bin/plan-lint (specs/plan-lint.md). Run: sh plugins/agentic-workflow-kit-next/tests/plan-lint.test.sh
# Uses the kit's default Map in .claude/rules/structure.md on a scratch project.
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT
cp -R "$here/kit/." "$project/"
cd "$project" || exit 1
git init -q -b 12-invite
printf 'KIT_SOURCE_PATTERNS="*.ts *.tsx"\n' >.claude/kit.conf
mkdir -p .work specs
lint=.claude/bin/plan-lint
plan=.work/12-invite.md

passed=0
failed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
same() { if [ "$1" = "$2" ]; then ok; else fail "$3: got '$1', wanted '$2'"; fi; }

spec='# Invite users

ID prefix: INVITE

## Acceptance criteria
- **INVITE-AC1**: Given an admin, when they invite a new email address, then the invitee receives an email within 1 minute.
- **INVITE-AC2**: Given an invite, when the invitee opens it, then the page shows the team name.

## Edge cases
- **INVITE-AC3**: Given an address that is already a member, when the admin invites it, then the page shows "Already a member" and no email is sent.
'
printf '%s' "$spec" >specs/invite.md

good='# Plan: Invite users (spec: specs/invite.md)
Base: <the branch this one builds on; /ship-feature fills it in>

## Design
- Parts: the invite form and the member check
- Side effects: one email per invite, sent from the request after the role check; on failure the page shows the error
- Reused: searched src/lib for mail sending: none
- Approved dependencies: none
- Architecture: none
- Estimate: 120 lines

## Tasks
| # | Task | Files | Criteria | Test cases | Depends on | Tier | Group |
|---|------|-------|----------|------------|------------|------|-------|
| 1 | invite form | `src/features/invite/form.ts` | INVITE-AC1, INVITE-AC2 | `src/features/invite/form.test.ts`: INVITE-AC1: sends the email, INVITE-AC2: shows the team name | – | – | A |
| 2 | member check | `src/features/invite/members.ts` | INVITE-AC3 | `src/features/invite/members.test.ts`: INVITE-AC3: already a member | 1 | standard | A |

## Progress
- [ ] 1 invite form
- [ ] 2 member check

## Verify log
| Criterion | Test | Red seen | Green | Notes |
|-----------|------|----------|-------|-------|
'

fixgood='# Plan: login-redirect (fix)
Base: main

## Bug
- Source: pasted report
- Reproduce: open /login while logged in
- Expected: the home page
- Observed: the login form

## Criteria
- **LOGINFIX-AC1**: Given a logged-in user, when they open /login, then the home page opens.

## Design
- Cause: src/app/login/page.ts:12 never reads the session
- Side effects: none
- Reused: searched src/lib for the session helper: src/lib/session.ts:4
- Approved dependencies: none

## Tasks
| # | Task | Files | Criteria | Test cases | Depends on | Tier |
|---|------|-------|----------|------------|------------|------|
| 1 | reproduce | `src/app/login/page.test.ts` | LOGINFIX-AC1 | `src/app/login/page.test.ts`: LOGINFIX-AC1: logged-in user opens /login | – | – |
| 2 | fix | `src/app/login/page.ts` | LOGINFIX-AC1 | the tests of task 1 pass | 1 | standard |

## Progress
- [ ] 1 reproduce
- [ ] 2 fix
'

# replace <text> <sed expression>...: the text with each expression applied.
replace() {
  _text=$1
  shift
  for _e in "$@"; do _text=$(printf '%s\n' "$_text" | sed "$_e"); done
  printf '%s\n' "$_text"
}

# expect <pass|fail> <description> <plan text> [expected fragment]...: run plan-lint on the text.
expect() {
  want=$1 description=$2
  printf '%s' "$3" >"$plan"
  shift 3
  out=$("$lint" "$plan" 2>&1)
  code=$?
  good_code=0
  case $want:$code in pass:0 | fail:1) good_code=1 ;; esac
  if [ $good_code -eq 1 ]; then
    for fragment in "$@"; do
      if ! printf '%s' "$out" | grep -qF -- "$fragment"; then good_code=0; echo "  missing '$fragment'"; fi
    done
  fi
  if [ $good_code -eq 1 ]; then ok; else fail "$description (exit $code)"; printf '%s\n' "$out" | sed 's/^/    /'; fi
}
# expect_no <description> <plan text> <fragment>: the output must not contain the fragment.
expect_no() {
  printf '%s' "$2" >"$plan"
  out=$("$lint" "$plan" 2>&1)
  case $out in *"$3"*) fail "$1: found '$3' in: $out" ;; *) ok ;; esac
}

# --- running it ------------------------------------------------------------------------

expect pass "PLANLINT-AC1 a plan that follows every rule passes" "$good" "plan-lint: $plan passes."
expect fail "PLANLINT-AC2 two broken rules give two findings" "$(replace "$good" 's/^- Reused: .*/- Reused: <what you searched for>/' 's/^- \[ \] 2 member check$//')" "Reused" "task 2 is missing from Progress"
printf '%s' "$(replace "$good" 's/^- Reused: .*/- Reused: <what you searched for>/' 's/^- \[ \] 2 member check$//')" >"$plan"
same "$("$lint" "$plan" 2>&1 | grep -c "^$plan:")" 2 "PLANLINT-AC2 exactly two findings"
printf '%s' "$good" >"$plan"
out=$("$lint" 2>&1)
case $out in *".work/12-invite.md passes."*) ok ;; *) fail "PLANLINT-AC3 no argument checks the branch's plan: $out" ;; esac
bad=$(replace "$good" 's/^- Reused: .*/- Reused: <what you searched for>/' 's/, INVITE-AC2 //')
printf '%s' "$bad" >"$plan"
lf=$("$lint" "$plan" 2>&1)
printf '%s' "$bad" | sed 's/$/\r/' >"$plan"
crlf=$("$lint" "$plan" 2>&1)
same "$crlf" "$lf" "PLANLINT-AC4 CRLF gives the same findings as LF"
case $lf in *INVITE-AC2*) ok ;; *) fail "PLANLINT-AC4 the LF run found the missing criterion: $lf" ;; esac

# --- title and spec ---------------------------------------------------------------------

expect fail "PLANLINT-AC5 a missing spec is named on line 1" "$(replace "$good" 's|specs/invite.md|specs/missing.md|')" "$plan:1:" "specs/missing.md" "does not exist"
expect fail "PLANLINT-AC6 a first line in neither form shows both" "$(replace "$good" '1s/.*/# Plan for invites/')" "$plan:1:" "(spec: specs/<feature>.md)" "(fix)"

# --- criteria coverage ------------------------------------------------------------------

expect fail "PLANLINT-AC7 a criterion without a task is named" "$(replace "$good" 's/, INVITE-AC2 / /')" "INVITE-AC2: no task covers it"
printf '%s' "$(replace "$spec" 's/^- \*\*INVITE-AC2\*\*:.*/- **INVITE-AC2** (removed 01.11.2026: merged into AC1)/')" >specs/invite.md
expect pass "PLANLINT-AC8 a removed criterion needs no task" "$(replace "$good" 's/, INVITE-AC2 / /')"
printf '%s' "$spec" >specs/invite.md
expect fail "PLANLINT-AC9 a task naming an ID the spec lacks" "$(replace "$good" 's/| INVITE-AC3 |/| INVITE-AC9 |/')" "$plan:16:" "specs/invite.md has no INVITE-AC9"
covered=$(replace "$good" 's/^## Design$/## Criteria\n- **INVITE-AC3**: Given an address that is already a member, when the admin invites it, then the page shows "Already a member" and no email is sent.\n\n## Design/' 's/| INVITE-AC1, INVITE-AC2 |/| – |/')
expect pass "PLANLINT-AC10 the plan's own criteria replace the spec's set" "$covered"
expect fail "PLANLINT-AC11 a plan criterion the spec lacks" "$(replace "$covered" 's/\*\*INVITE-AC3\*\*/**INVITE-AC9**/' 's/| INVITE-AC3 |/| INVITE-AC9 |/')" "$plan:5:" "specs/invite.md has no INVITE-AC9"

# --- criteria of a fix ------------------------------------------------------------------

expect pass "PLANLINT-AC12 a fix plan with a well-formed criterion passes" "$fixgood"
expect fail "PLANLINT-AC12 a fix criterion without state, action and result" "$(replace "$fixgood" 's/^- \*\*LOGINFIX-AC1\*\*:.*/- **LOGINFIX-AC1**: The login page redirects home./')" "$plan:11:" 'write it as "Given <state>, when <action>, then <observable result>"'
expect fail "PLANLINT-AC13 a fix criterion with an untestable word" "$(replace "$fixgood" 's/then the home page opens\./then the home page opens quickly./')" "$plan:11:" '"quickly" cannot be tested'
expect fail "PLANLINT-AC14 a fix prefix a spec owns" "$(replace "$fixgood" 's/LOGINFIX-AC1/INVITE-AC1/g')" "belongs to specs/invite.md"
expect fail "PLANLINT-AC15 a duplicate fix criterion" "$(replace "$fixgood" 's/^- \*\*LOGINFIX-AC1\*\*:\(.*\)$/- **LOGINFIX-AC1**:\1\n- **LOGINFIX-AC1**: Given a guest, when they open \/login, then the login form shows./')" "$plan:12:" "LOGINFIX-AC1: already used on line 11"

# --- tasks table ------------------------------------------------------------------------

expect fail "PLANLINT-AC16 a header without the Test cases column" "$(replace "$good" 's/| Test cases |/| Checks |/')" "$plan:13:" 'no "Test cases" column'
expect fail "PLANLINT-AC17 an empty Files cell" "$(replace "$good" 's/| `src\/features\/invite\/members.ts` |/| |/')" "task 2" "Files cell is empty"
expect fail "PLANLINT-AC18 test cases that are not named" "$(replace "$good" 's/| `src\/features\/invite\/members.test.ts`: INVITE-AC3: already a member |/| add tests |/')" "$plan:16:" "task 2: name the test cases"
three=$(replace "$good" 's/^| 2 | member check \(.*\) | 1 | standard | A |$/| 2 | member check \1 | 3 | standard | A |\n| 3 | mail copy | `src\/features\/invite\/copy.ts` | INVITE-AC3 | `src\/features\/invite\/copy.test.ts`: INVITE-AC3: the text | – | – | A |/' 's/^- \[ \] 2 member check$/- [ ] 2 member check\n- [ ] 3 mail copy/')
expect fail "PLANLINT-AC19 a dependency on a later task" "$three" "$plan:16:" "task 2: depends on task 3; a task depends only on earlier tasks"
expect fail "PLANLINT-AC20 a dependency on a task that does not exist" "$(replace "$three" 's/| 3 | standard | A |$/| 7 | standard | A |/')" "$plan:16:" "task 2: depends on task 7, which does not exist"
expect fail "PLANLINT-AC27 a Files placeholder" "$(replace "$good" 's/| `src\/features\/invite\/members.ts` |/| <paths> |/')" "$plan:16:" "still holds a placeholder"
expect fail "PLANLINT-AC36 a table without a row" "$(replace "$good" '/^| [12] |/d' '/^- \[ \] /d')" "no task"

# --- tiers ------------------------------------------------------------------------------

expect fail "PLANLINT-AC21 an unknown tier" "$(replace "$good" 's/| 1 | standard | A |$/| 1 | opus | A |/')" "$plan:16:" "fast, standard or deep"
deep=$(replace "$good" 's/| 1 | standard | A |$/| 1 | deep | A |/')
expect fail "PLANLINT-AC22 a raised tier without its reason line" "$deep" "$plan:16:" 'Task 2 deep:'
expect pass "PLANLINT-AC23 a raised tier with its reason line" "$(replace "$deep" 's/^## Progress$/Task 2 deep: changes the permission check\nGroup A deep: task 2 changes the permission check\n\n## Progress/')"
expect pass "PLANLINT-AC23 the reason line may be a list item" "$(replace "$deep" 's/^## Progress$/- Task 2 deep: changes the permission check\n- Group A deep: task 2 changes the permission check\n\n## Progress/')"
printf 'KIT_SOURCE_PATTERNS="*.ts *.tsx"\nKIT_ROUTE_IMPLEMENT="deep"\n' >.claude/kit.conf
expect pass "PLANLINT-AC24 the default tier comes from route" "$deep"
expect fail "PLANLINT-AC24 standard needs a reason when deep is the default" "$good" "$plan:16:" 'Task 2 standard:'
printf 'KIT_SOURCE_PATTERNS="*.ts *.tsx"\n' >.claude/kit.conf
expect pass "PLANLINT-AC37 a – tier is the default" "$(replace "$good" 's/| 1 | standard | A |$/| 1 | – | A |/')"

# --- new files --------------------------------------------------------------------------

misplaced=$(replace "$good" 's/| `src\/features\/invite\/members.ts` |/| `src\/helpers.ts` |/')
expect fail "PLANLINT-AC25 a new file outside the Map" "$misplaced" "$plan:16: task 2: src/helpers.ts: no home in the Map"
mkdir -p src
printf 'export const x = 1;\n' >src/helpers.ts
expect pass "PLANLINT-AC26 an existing file outside the Map" "$misplaced"
rm src/helpers.ts
expect pass "PLANLINT-AC42 backticked paths with notes" "$(replace "$good" 's/| `src\/features\/invite\/members.ts` |/| `src\/features\/invite\/send.ts` (new), `src\/lib\/mail.ts` |/')"
mv .claude/rules .claude/rules.off
printf '%s' "$misplaced" >"$plan"
err=$("$lint" "$plan" 2>&1 >/dev/null)
code=$?
same "$code" 0 "PLANLINT-AC38 no Map: exit 0"
same "$err" "plan-lint: structure not configured; new paths not checked" "PLANLINT-AC38 no Map: the note on stderr"
mv .claude/rules.off .claude/rules

# --- design -----------------------------------------------------------------------------

expect fail "PLANLINT-AC28 a missing Approved dependencies line" "$(replace "$good" '/^- Approved dependencies:/d')" 'Design has no "- Approved dependencies:" line'
expect fail "PLANLINT-AC29 a Design placeholder" "$(replace "$good" 's/^- Reused: .*/- Reused: <what you searched for, with path:line>/')" "$plan:7:" 'Design line "Reused" still holds its placeholder'
expect pass "PLANLINT-AC39 the Base placeholder is not checked" "$good"
expect_no "PLANLINT-AC40 no Contract line is fine" "$good" "Contract"

# --- progress ---------------------------------------------------------------------------

expect fail "PLANLINT-AC30 a task missing from Progress" "$(replace "$three" 's/| 3 | standard | A |$/| 1 | standard | A |/' '/^- \[ \] 3 mail copy$/d')" "task 3 is missing from Progress"
expect fail "PLANLINT-AC31 a task listed twice" "$(replace "$good" 's/^- \[ \] 2 member check$/- [ ] 1 invite form\n- [ ] 2 member check/')" "$plan:20:" "task 1 is listed twice in Progress"
expect fail "PLANLINT-AC41 the template line" "$(replace "$good" 's/^- \[ \] 1 invite form$/- [ ] 1 <task>/')" "$plan:19:" "template line"

# --- edge cases -------------------------------------------------------------------------

rm -f "$plan"
out=$("$lint" 2>&1)
code=$?
same "$code" 2 "PLANLINT-AC34 no plan: exit 2"
same "$out" "plan-lint: no plan at .work/12-invite.md" "PLANLINT-AC34 no plan: the message"
expect fail "PLANLINT-AC35 a fix plan without criteria" "$(replace "$fixgood" '/^## Criteria$/,/^$/d' 's/| LOGINFIX-AC1 |/| – |/')" "## Criteria"

# --- groups (specs/group-sessions.md) ----------------------------------------------------

expect fail "GROUP-AC158 a feature plan without a Group column" "$(replace "$good" 's/ Group |$/|/' 's/-------|$//' 's/ | A |$/ |/')" "$plan:13:" 'no "Group" column'
covered_fix=$(replace "$good" 's/^## Design$/## Bug\n- Source: pasted report\n\n## Design/' 's/ Group |$/|/' 's/-------|$//' 's/ | A |$/ |/')
expect pass "GROUP-AC166 a fix of a feature (## Bug) needs no Group column" "$covered_fix"
expect pass "GROUP-AC166 a fix plan needs no Group column" "$fixgood"
four=$(replace "$three" 's/^| 3 | mail copy \(.*\) | – | – | A |$/| 3 | mail copy \1 | – | – | A |\n| 4 | mail log | `src\/features\/invite\/log.ts` | INVITE-AC3 | `src\/features\/invite\/log.test.ts`: INVITE-AC3: the log | – | – | A |/' 's/^- \[ \] 3 mail copy$/- [ ] 3 mail copy\n- [ ] 4 mail log/' 's/| 3 | standard | A |$/| 1 | standard | A |/')
expect fail "GROUP-AC159 a group of 4 tasks" "$four" "$plan:12:" "group A holds 4 tasks; a group takes at most 3 tasks"
split=$(replace "$three" 's/| 3 | standard | A |$/| 1 | standard | B |/')
expect fail "GROUP-AC160 a group that is not consecutive" "$split" "group A is not consecutive in plan order"
expect fail "GROUP-AC161 a task without a group" "$(replace "$good" 's/| 1 | standard | A |$/| 1 | standard | |/')" "task 2 has no group"
deepgroup=$(replace "$deep" 's/^## Progress$/Task 2 deep: changes the permission check\n\n## Progress/')
expect fail "GROUP-AC162 a group above the default tier without its reason line" "$deepgroup" "$plan:15:" 'Group A deep:'
expect pass "GROUP-AC163 a group above the default tier with its reason line" "$(replace "$deepgroup" 's/^## Progress$/Group A deep: task 2 changes the permission check\n\n## Progress/')"
expect fail "GROUP-AC164 an Approved size placeholder" "$(replace "$good" 's/^## Tasks$/Approved size: <only when this plan stays one PR above the default limit: <n> lines>\n\n## Tasks/')" "$plan:12:" "Approved size line still holds its placeholder"
expect fail "GROUP-AC164 an Approved size without lines" "$(replace "$good" 's/^## Tasks$/Approved size: about 3000\n\n## Tasks/')" "$plan:12:" '"Approved size: <n> lines"'
expect pass "GROUP-AC165 an Approved size of n lines" "$(replace "$good" 's/^## Tasks$/Approved size: 3000 lines\n\n## Tasks/')"

# --- the ranked lines (specs/risk-gates.md) ---------------------------------------------

expect fail "RISK-AC20 a feature plan without an Architecture line" "$(replace "$good" '/^- Architecture:/d')" 'Design has no "- Architecture:" line'
expect fail "RISK-AC21 a feature plan without an Estimate line" "$(replace "$good" '/^- Estimate:/d')" 'Design has no "- Estimate: <n> lines" line'
expect fail "RISK-AC21 an Estimate that is not a number of lines" "$(replace "$good" 's/^- Estimate: .*/- Estimate: about a day/')" "$plan:10:" '"- Estimate: <n> lines"'
expect pass "a fix plan needs neither line" "$fixgood"

# --- wiring -----------------------------------------------------------------------------

skill=.claude/skills/plan-feature/SKILL.md
lint_line=$(grep -n 'plan-lint' "$skill" | head -n 1 | cut -d: -f1)
gate_line=$(grep -n 'gate plan' "$skill" | head -n 1 | cut -d: -f1)
if [ -n "$lint_line" ] && [ -n "$gate_line" ] && [ "$lint_line" -lt "$gate_line" ]; then ok; else fail "PLANLINT-AC32 /plan-feature runs plan-lint (line ${lint_line:-none}) before gate plan (line ${gate_line:-none})"; fi
if grep -qF '"Bash(.claude/bin/plan-lint *)"' .claude/settings.json; then ok; else fail "PLANLINT-AC33 settings.json allows plan-lint"; fi

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
