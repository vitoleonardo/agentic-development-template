#!/bin/sh
# Tests for the /fix-bug skill and the sentences it needs in the agents and sibling skills (specs/fix-bug.md).
# The flow itself runs only live (tests/fix-bug/run.sh); these cases pin what the files say.
# Run: sh plugins/stempel-kit/tests/fix-bug.test.sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
kit=$here/kit/.claude
skill=$kit/skills/fix-bug/SKILL.md

passed=0
failed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
# has <description> <file> <fragment>: the file holds the fragment.
has() { if grep -qF -- "$3" "$2"; then ok; else fail "$1: no '$3' in ${2#"$here"/}"; fi; }
# lacks <description> <file> <fragment>: the file does not hold the fragment.
lacks() { if grep -qF -- "$3" "$2"; then fail "$1: found '$3' in ${2#"$here"/}"; else ok; fi; }
# before <description> <file> <fragment a> <fragment b>: the first line with a comes before the first line with b.
before() {
  a=$(grep -nF -- "$3" "$2" | head -n 1 | cut -d: -f1)
  b=$(grep -nF -- "$4" "$2" | head -n 1 | cut -d: -f1)
  if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then ok; else fail "$1: '$3' (line ${a:-none}) is not before '$4' (line ${b:-none})"; fi
}

[ -f "$skill" ] && ok || fail "the skill exists"
has "the skill has its name" "$skill" "name: fix-bug"
has "the skill never writes a feature spec" "$skill" "Never writes a feature spec"

# --- reading the report ---------------------------------------------------------------
has "FIXBUG-AC2 an issue is read with gh" "$skill" 'gh issue view <n> --json title,body,url'
has "FIXBUG-AC3 a failing test is run with check test-related" "$skill" '.claude/bin/check test-related'
has "FIXBUG-AC34 a gh failure asks for the text" "$skill" "ask for the report as text"

# --- the contract and the plan --------------------------------------------------------
has "FIXBUG-AC4 a covered bug reuses the criterion" "$skill" "Reuse that criterion"
has "FIXBUG-AC6 a gap bug adds exactly one criterion" "$skill" "Add exactly one criterion to that spec"
before "FIXBUG-AC7 gate spec runs before any dispatch" "$skill" ".claude/bin/gate spec" "Dispatch the"
has "FIXBUG-AC8 an unspecified bug uses a prefix no spec has" "$skill" "a prefix no spec uses"
before "FIXBUG-AC9 plan-lint runs before gate plan" "$skill" ".claude/bin/plan-lint .work/<branch>.md" ".claude/bin/gate plan"
has "FIXBUG-AC10 the feature list is not touched" "$skill" "The feature list is not touched"
has "FIXBUG-AC11 task 1 is reproduce" "$skill" "| 1 | reproduce | <test file> | <IDs> | <test file>: <ID>: <case> | – | – |"
has "FIXBUG-AC11 task 2 is fix and depends on 1" "$skill" "| 2 | fix | <source files> | <IDs> | the tests of task 1 pass | 1 | standard |"
has "FIXBUG-AC30 a feature open on another branch gets no plan" "$skill" "write no plan"

# --- building -------------------------------------------------------------------------
has "FIXBUG-AC12 task 1 goes to the test-writer on route tests" "$skill" 'Dispatch the `test-writer` (description `task 1: reproduce <slug>`, `model` from `.claude/bin/route tests`)'
has "FIXBUG-AC13 a test that never failed dispatches no fix" "$skill" "A test passed without ever failing: no fix is dispatched"
has "FIXBUG-AC13 and writes a Stops line of class test" "$skill" 'Write a Stops line of class `test`'
has "FIXBUG-AC31 the spec's own behaviour is class spec" "$skill" 'Write a Stops line of class `spec`, change no spec, and ask'
has "FIXBUG-AC32 untestable code is class plan" "$skill" 'stop with a Stops line of class `plan`'
has "FIXBUG-AC14 task 2 goes to the implementer on the row's tier" "$skill" 'Dispatch the `implementer` (description `task 2: fix <slug>`, `model` from `.claude/bin/route <tier>` with the row'"'"'s Tier)'
has "FIXBUG-AC14 with the red test's file and message" "$skill" "the red test's file and its failure message"
has "FIXBUG-AC15 the retry is one tier higher" "$skill" '`.claude/bin/route up <tier>`'
has "FIXBUG-AC15 with the retry description" "$skill" '`task 2 retry <tier>: fix <slug>`'
has "FIXBUG-AC16 the second failure stops" "$skill" "If it fails again, stop and ask the user"
has "FIXBUG-AC17 one commit after gate commit" "$skill" "commit the test and the fix in one commit (gate commit)"
has "FIXBUG-AC18 Simplify is skipped" "$skill" "Simplify is skipped"
lacks "FIXBUG-AC18 no simplify dispatch" "$skill" 'description `simplify`'
has "FIXBUG-AC33 a plan with a Bug section resumes" "$skill" 'has a `## Bug` section, this fix is in progress'

# --- review, verify, PR ---------------------------------------------------------------
has "FIXBUG-AC19 the reviewer is dispatched as review round n" "$skill" 'Dispatch the `reviewer` agent with the Agent tool (description `review round <n>`)'
has "FIXBUG-AC19 later rounds follow /ship-feature" "$skill" "as in \"Independent review\" of \`/ship-feature\`"
has "FIXBUG-AC20 a wrong product is gate round hotfix" "$skill" '`.claude/bin/gate round hotfix <n>`'
has "FIXBUG-AC21 the Why links the report" "$skill" "The Why links the report's source"

# --- agents and sibling skills --------------------------------------------------------
has "FIXBUG-AC27 the implementer runs an existing red test" "$kit/agents/implementer.md" "If the task names an existing red test, run it and confirm it fails for the reported reason instead of writing one; never change it."
has "FIXBUG-AC27 the implementer reads the plan's criteria" "$kit/agents/implementer.md" 'a `## Criteria` section in the state file holds the criteria of a fix'
has "FIXBUG-AC28 the test-writer takes the plan's criteria" "$kit/agents/test-writer.md" 'When `.work/<branch>.md` has a `## Criteria` section, those are the criteria.'
has "FIXBUG-AC28 the reviewer takes the plan's criteria" "$kit/agents/reviewer.md" 'If no row names the branch, take the spec from the title of `.work/<branch>.md`; its `## Criteria` section, when present, lists the criteria to judge.'
has "FIXBUG-AC29 verify sets the status only for a feature row" "$kit/skills/verify-feature/SKILL.md" 'when the feature'"'"'s row in `specs/README.md` names this branch, set its status to `in-review` (a fix branch leaves the list alone)'
has "FIXBUG-AC29 verify reads the plan's criteria for a fix" "$kit/skills/verify-feature/SKILL.md" 'or its `## Criteria` for a fix'
has "FIXBUG-AC21 the PR skill finds the spec through the title" "$kit/skills/pr-description/SKILL.md" 'through the title of `.work/<branch>.md`; a fix'"'"'s criteria are its `## Criteria`'
has "FIXBUG-AC21 the PR skill links the report for a fix" "$kit/skills/pr-description/SKILL.md" 'for a fix, the issue URL or the `## Bug` source instead'
has "the plan skill names the fix title" "$kit/skills/plan-feature/SKILL.md" '# Plan: <slug> (fix)'

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
