#!/bin/sh
# Tests for .claude/bin/stack (specs/stacked-groups.md). Run: sh plugins/agentic-workflow-kit-next/tests/stack.test.sh
# A fixture repo with a bare local remote and a fake gh that records its calls, so no network is needed.
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
project=$work/project
mkdir -p "$project" "$work/bin"
cp -R "$here/kit/." "$project/"
cd "$project" || exit 1

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
same() { if [ "$1" = "$2" ]; then ok; else fail "$3: got '$1', wanted '$2'"; fi; }
contains() { case $1 in *"$2"*) ok ;; *) fail "$3: no '$2' in: $1" ;; esac; }
lacks() { case $1 in *"$2"*) fail "$3: found '$2' in: $1" ;; *) ok ;; esac; }
g() { git -c user.name=t -c user.email=t@example.invalid "$@"; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

# The fake gh: `extension list` names gh-stack when FAKE_STACK is set; `stack link` exits FAKE_LINK_EXIT and opens a
# PR for each branch it is given; pr view/create/edit work on a small file of open PRs ("<head> <base>").
cat >"$work/bin/gh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$GH_LOG"
prs=$GH_PRS
case "$1 $2" in
  "extension list") [ -n "${FAKE_STACK:-}" ] && printf 'gh stack\tgithub/gh-stack\tv0.1.0\n'; exit 0 ;;
  "stack link")
    git --git-dir="$REMOTE_GIT" ls-tree -r --name-only kit-evidence 2>/dev/null | grep -q '/evidence.json$' && echo "packs-before-link" >>"$GH_LOG"
    [ "${FAKE_LINK_EXIT:-0}" -eq 0 ] || exit "$FAKE_LINK_EXIT"
    shift 2
    base=""
    [ "$1" = --base ] && { base=$2; shift 2; }
    below=$base
    for b in "$@"; do grep -q "^$b " "$prs" 2>/dev/null || printf '%s %s\n' "$b" "$below" >>"$prs"; below=$b; done
    exit 0 ;;
  "pr view")
    line=$(grep "^$3 " "$prs" 2>/dev/null) || exit 1
    case "$*" in *body*) cat "$FAKE_BODIES/$(printf '%s' "$3" | tr '/' '_')" 2>/dev/null; exit 0 ;; esac
    case "$*" in *"--json number"*) grep -n "^$3 " "$prs" | cut -d: -f1; exit 0 ;; esac
    case "$*" in *"--json state"*) echo OPEN; exit 0 ;; esac
    printf 'https://github.com/o/r/pull/%s\n' "$(grep -n "^$3 " "$prs" | cut -d: -f1)"
    exit 0 ;;
  "pr create")
    shift 2
    while [ $# -gt 0 ]; do case $1 in --base) base=$2; shift 2 ;; --head) head=$2; shift 2 ;; *) shift ;; esac; done
    printf '%s %s\n' "$head" "$base" >>"$prs"
    exit 0 ;;
  "pr edit")
    b=$3
    shift 3
    while [ $# -gt 0 ]; do case $1 in --body-file) cp "$2" "$FAKE_BODIES/$(printf '%s' "$b" | tr '/' '_')"; shift 2 ;; *) shift ;; esac; done
    exit 0 ;;
  "repo view") echo o/r; exit 0 ;;
  "workflow view") [ -z "${FAKE_NO_WORKFLOW:-}" ]; exit ;;
  "workflow run") exit 0 ;;
  "run list") echo 77; exit 0 ;;
  "run watch") exit 0 ;;
  "run download")
    shift 2
    while [ $# -gt 0 ]; do case $1 in --dir) d=$2; shift 2 ;; *) shift ;; esac; done
    cp -R "$FAKE_ARTIFACTS/." "$d/"
    exit 0 ;;
  "api"*) exit 0 ;;
  "stack merge" | "stack sync" | "pr merge") exit 0 ;;
esac
exit 0
EOF
chmod +x "$work/bin/gh"
PATH=$work/bin:$PATH
export PATH GH_LOG="$work/gh.log" GH_PRS="$work/prs" REMOTE_GIT="$work/remote.git" FAKE_BODIES="$work/bodies" FAKE_ARTIFACTS="$work/artifacts"
mkdir -p "$work/bodies" "$work/artifacts"

git init -q -b main
git init -q --bare "$work/remote.git"
git remote add origin "$work/remote.git"
printf 'KIT_SOURCE_PATTERNS="*.ts"\nKIT_MAX_CHANGED_LINES="400"\n' >.claude/kit.conf
printf '.work/\n' >.gitignore
mkdir -p src
printf 'export const a = 0;\n' >src/a.ts
g add -A
g commit -qm base
git push -q origin main

# plan <branch> <base> <rows: task:group ...>: a plan with a Group column and every task ticked.
plan() {
  _branch=$1 _base=$2
  shift 2
  mkdir -p "$(dirname ".work/$_branch.md")"
  {
    printf '# Plan: invite (spec: specs/invite.md)\nBase: %s\n\n## Tasks\n| # | Task | Files | Criteria | Test cases | Depends on | Tier | Group |\n|---|---|---|---|---|---|---|---|\n' "$_base"
    for _row in "$@"; do printf '| %s | t | f | INVITE-AC%s | c | - | standard | %s |\n' "${_row%%:*}" "${_row%%:*}" "${_row#*:}"; done
    printf '\n## Progress\n'
    for _row in "$@"; do printf -- '- [x] %s t\n' "${_row%%:*}"; done
    printf '\n## Rounds\n'
  } >".work/$_branch.md"
}
# commit_task <n> [lines]: one commit naming the task.
commit_task() {
  printf 'export const t%s = "%s";\n' "$1" "$(git branch --show-current)" >"src/t$1.ts"
  g add -A
  g commit -qm "task $1: build it"
}
# descriptions <branch> <groups...>: a description per layer; the last group is the branch's own.
descriptions() {
  _b=$1
  shift
  mkdir -p ".work/$_b/pr"
  for _g in "$@"; do :; done
  for _x in "$@"; do
    if [ "$_x" = "$_g" ]; then printf 'Invite (%s)\n\n## What\n- top\n' "$_x" >".work/$_b-pr.md"
    else printf 'Invite (%s)\n\n## What\n- layer\n' "$_x" >".work/$_b/pr/$_x.md"; fi
  done
}
# pack: an evidence pack for HEAD, as verify leaves it.
pack() {
  mkdir -p ".work/$1/evidence"
  printf '{\n  "branch": "%s",\n  "head": "%s",\n  "base": "main"\n}\n' "$1" "$(git rev-parse HEAD)" >".work/$1/evidence/evidence.json"
  printf 'size\tpass\t0\tok\n' >".work/$1/evidence/gates.tsv"
}

# --- layers ----------------------------------------------------------------------

git checkout -qb 12-invite
plan 12-invite main 1:A 2:A 3:A 4:B 5:B
commit_task 1; commit_task 2; commit_task 3
end_a=$(git rev-parse HEAD)
commit_task 4; commit_task 5
out=$(.claude/bin/stack layers)
same "$(printf '%s\n' "$out" | cut -f1 | tr '\n' ' ')" "12-invite-gA 12-invite " "STACK-AC1: a layer per group, the last one is the branch"
same "$(printf '%s\n' "$out" | head -n 1 | cut -f2)" "$end_a" "STACK-AC1: group A's layer ends before task 4's commit"
lacks "$out" "12-invite-gB" "STACK-AC2: the last group has no layer branch"

# --- submit with gh stack --------------------------------------------------------

# A review fix of the final session lands on the top layer.
printf 'export const fixed = 1;\n' >src/fix.ts; g add -A; g commit -qm "review round 1: fix group A's check"
same "$(.claude/bin/stack layers | head -n 1 | cut -f2)" "$end_a" "STACK-AC30: a final-session fix stays out of group A's layer"
git branch 12-invite-gA HEAD
descriptions 12-invite A B
pack 12-invite
: >"$GH_LOG"; : >"$GH_PRS"
FAKE_STACK=1 .claude/bin/stack submit >"$work/out" 2>&1 || fail "STACK-AC7: submit exits 0: $(cat "$work/out")"
contains "$(cat "$GH_LOG")" "stack link --base main 12-invite-gA 12-invite" "STACK-AC7: gh stack link with the base and the layers in order"
same "$(git rev-parse 12-invite-gA)" "$end_a" "STACK-AC1, STACK-AC6: the layer branch moves to the group end"
same "$(grep -A1 '^stack link' "$GH_LOG" | head -n 2 | tail -n 1)" "packs-before-link" "STACK-AC20: the layer packs are pushed before gh stack link runs"
same "$(grep '^12-invite-gA ' "$GH_PRS" | cut -d' ' -f2)" "main" "STACK-AC8: the first layer is based on main"
same "$(grep '^12-invite ' "$GH_PRS" | cut -d' ' -f2)" "12-invite-gA" "STACK-AC8: the top layer is based on the layer below"
git --git-dir="$work/remote.git" rev-parse -q --verify 12-invite-gA >/dev/null && ok || fail "the layer branch is pushed"
key_sha=$(git --git-dir="$work/remote.git" show "kit-evidence:12-invite-gA/$end_a/evidence.json" 2>/dev/null | sed -n 's/^ *"head": *"\([0-9a-f]*\)".*/\1/p')
same "$key_sha" "$end_a" "STACK-AC17: the layer pack names the layer's head"
top_sha=$(git --git-dir="$work/remote.git" show "kit-evidence:12-invite-gA/$end_a/evidence.json" 2>/dev/null | sed -n 's/^ *"stack_top": *"\([0-9a-f]*\)".*/\1/p')
same "$top_sha" "$(git rev-parse HEAD)" "STACK-AC18: the layer pack names the stack top"
.claude/bin/evidence ci-check --head "$end_a" --key 12-invite-gA >/dev/null 2>&1 && ok || fail "STACK-AC19: ci-check finds the layer pack"

# A second submit opens nothing new.
: >"$GH_LOG"
FAKE_STACK=1 .claude/bin/stack submit >"$work/out" 2>&1 || fail "STACK-AC11: a second submit exits 0: $(cat "$work/out")"
same "$(wc -l <"$GH_PRS" | tr -d ' ')" 2 "STACK-AC11: no pull request is opened twice"

# --- the plain chain ---------------------------------------------------------------

git checkout -q main
git checkout -qb 13-chain
plan 13-chain main 1:A 2:B
commit_task 1
commit_task 2
descriptions 13-chain A B
pack 13-chain
: >"$GH_LOG"
.claude/bin/stack submit >"$work/out" 2>&1 || fail "STACK-AC9: submit without gh stack exits 0: $(cat "$work/out")"
contains "$(cat "$work/out")" "gh extension install github/gh-stack" "STACK-AC9: the missing extension is named"
contains "$(cat "$GH_LOG")" "pr create --base main --head 13-chain-gA" "STACK-AC9: the first layer on the base"
contains "$(cat "$GH_LOG")" "pr create --base 13-chain-gA --head 13-chain" "STACK-AC9: the top on the layer below"

git checkout -q main
git checkout -qb 14-off
plan 14-off main 1:A 2:B
commit_task 1; commit_task 2
descriptions 14-off A B
pack 14-off
: >"$GH_LOG"
FAKE_STACK=1 FAKE_LINK_EXIT=9 .claude/bin/stack submit >"$work/out" 2>&1 || fail "STACK-AC10: submit with stacks off exits 0: $(cat "$work/out")"
contains "$(cat "$work/out")" "turned off for this repository" "STACK-AC10: stacks off is named"
contains "$(cat "$GH_LOG")" "pr create --base 14-off-gA --head 14-off" "STACK-AC10: the chain is opened instead"

# --- one layer ---------------------------------------------------------------------

git checkout -q main
git checkout -qb 15-one
plan 15-one main 1:A 2:A
commit_task 1; commit_task 2
out=$(.claude/bin/stack layers)
same "$(printf '%s\n' "$out" | cut -f1)" "15-one" "STACK-AC3: one group is one layer"

git checkout -q main
git checkout -qb 16-nogroups
mkdir -p .work
printf '# Plan: x (spec: specs/x.md)\nBase: main\n\n## Tasks\n| # | Task | Files | Criteria | Test cases | Depends on | Tier |\n|---|---|---|---|---|---|---|\n| 1 | t | f | c | c | - | standard |\n| 4 | t | f | c | c | - | standard |\n\n## Progress\n- [x] 1 t\n- [x] 4 t\n' >.work/16-nogroups.md
commit_task 1; commit_task 4
out=$(.claude/bin/stack layers)
same "$(printf '%s\n' "$out" | cut -f1)" "16-nogroups" "STACK-AC4: a plan without a Group column is one layer"

git checkout -q main
git checkout -qb 17-gap
plan 17-gap main 1:A 2:B 3:B
commit_task 1; commit_task 2
printf 'x\n' >src/no-task.ts; g add -A; g commit -qm "untitled"
out=$(.claude/bin/stack layers 2>&1)
contains "$out" "one layer" "STACK-AC5: a group whose start no commit shows makes one layer"
same "$(printf '%s\n' "$out" | grep -v '^stack:' | cut -f1)" "17-gap" "STACK-AC5: and the layer is the branch"

# --- the chain of features ---------------------------------------------------------

git checkout -q 12-invite
git checkout -qb 18-next
plan 18-next 12-invite 1:A 2:B
commit_task 1; commit_task 2
descriptions 18-next A B
pack 18-next
: >"$GH_LOG"
FAKE_STACK=1 .claude/bin/stack submit >"$work/out" 2>&1 || fail "STACK-AC12: a stacked feature submits: $(cat "$work/out")"
contains "$(cat "$GH_LOG")" "stack link --base main 12-invite-gA 12-invite 18-next-gA 18-next" "STACK-AC12: the stack continues the feature below"

# --- a pushed layer never moves ------------------------------------------------------

git checkout -q 13-chain
git branch -f 13-chain-gA "$(git rev-parse HEAD)"
git push -q -f origin 13-chain-gA
out=$(.claude/bin/stack submit 2>&1)
code=$?
same "$code" 1 "STACK-AC33: a pushed layer that would move is refused"
contains "$out" "fixes go on the top layer" "STACK-AC33: the refusal says where fixes go"
same "$(git rev-parse 13-chain-gA)" "$(git rev-parse HEAD)" "STACK-AC33: the refused layer branch does not move"

# --- edge cases --------------------------------------------------------------------

git checkout -q main
git checkout -qb feat/invite
plan feat/invite main 1:A 2:B
commit_task 1; commit_task 2
out=$(.claude/bin/stack layers)
same "$(printf '%s\n' "$out" | head -n 1 | cut -f1)" "feat/invite-gA" "STACK-AC29: a branch with a slash gets its layer by suffix"

git checkout -q main
git checkout -qb 19-missing
plan 19-missing main 1:A 2:B
commit_task 1; commit_task 2
pack 19-missing
out=$(.claude/bin/stack submit 2>&1)
same "$?" 1 "submit refuses a layer without its description"
contains "$out" ".work/19-missing/pr/A.md" "the missing description is named"

git checkout -q main
git checkout -qb 20-nopack
plan 20-nopack main 1:A
commit_task 1
descriptions 20-nopack A
out=$(.claude/bin/stack submit 2>&1)
same "$?" 0 "STACK-AC34: submit without an evidence pack still opens the pull request"
contains "$out" "until /verify-feature pushes it" "STACK-AC34: and says CI's evidence job fails until then"

# --- the stack stage (specs/stack-stage.md) ----------------------------------------

git checkout -q 12-invite
# artifacts <e2e result> <red files> <mutation line>: what the CI run leaves for download.
artifacts() {
  rm -rf "$work/artifacts"
  mkdir -p "$work/artifacts/kit-stack-e2e/screenshots" "$work/artifacts/kit-stack-mutation"
  printf 'seed\tn/a\t0\t\ne2e\t%s\t60\trelated: 2 e2e test files\n' "$1" >"$work/artifacts/kit-stack-e2e/data-runs.tsv"
  printf '%s' "$2" >"$work/artifacts/kit-stack-e2e/red.txt"
  : >"$work/artifacts/kit-stack-e2e/screenshots/INVITE-AC1-form-desktop.png"
  printf '%s\n' "$3" >"$work/artifacts/kit-stack-mutation/mutation.txt"
}
artifacts fail 'e2e/invite.spec.ts
' 'score 80 threshold 60 killed 8 survived 2 mutants 10'
: >"$GH_LOG"
out=$(STACK_POLL_SECONDS=0 .claude/bin/stack checks 2>&1)
same "$?" 1 "a red e2e run makes the stage red"
contains "$(cat "$GH_LOG")" "workflow run stack-checks.yml --ref 12-invite -f base=main -f layers=$end_a $(git rev-parse HEAD)" "STAGE-AC6: one dispatch on the stack top with the base and every layer head"
contains "$(cat "$GH_LOG")" "-f kit_run=" "STAGE-AC6: with the kit's run id"
contains "$(cat "$GH_LOG")" "run list --workflow stack-checks.yml --branch 12-invite --event workflow_dispatch" "STAGE-AC7: the build looks for its own run"
contains "$out" "red: e2e/invite.spec.ts" "the red test file is reported"
[ -f .work/12-invite/stack/screenshots/INVITE-AC1-form-desktop.png ] && ok || fail "STAGE-AC9: the run's screenshots are downloaded"
: >"$GH_LOG"
artifacts pass '' 'score 80 threshold 60 killed 8 survived 2 mutants 10'
STACK_POLL_SECONDS=0 .claude/bin/stack checks --tests "e2e/invite.spec.ts" >"$work/out" 2>&1
same "$?" 0 "STAGE-AC18: a green rerun of the red tests makes the stage green"
contains "$(cat "$GH_LOG")" "-f tests=e2e/invite.spec.ts" "STAGE-AC17: the rerun names only the red files"
artifacts pass '' 'score 59 threshold 60 killed 59 survived 41 mutants 100'
out=$(STACK_POLL_SECONDS=0 .claude/bin/stack checks 2>&1)
same "$?" 1 "a mutation score below the threshold makes the stage red"
contains "$out" "mutation: score 59 threshold 60" "the score is reported"
out=$(FAKE_NO_WORKFLOW=1 .claude/bin/stack checks 2>&1)
same "$?" 2 "STAGE-AC40: without the workflow on the default branch the stage cannot run"
contains "$out" "stack-checks.yml is not on the default branch" "STAGE-AC40: and says so"
printf 'KIT_STACK_CHECKS="off"\n' >>.claude/kit.conf
out=$(.claude/bin/stack checks 2>&1)
same "$?" 0 "KIT_STACK_CHECKS=off has no stage"
git checkout -q .claude/kit.conf

# Locally: the e2e command and the mutation tests run in the checkout.
cat >"$work/bin/fake-e2e" <<'EOF'
#!/bin/sh
printf 'local e2e %s\n' "$*" >>"$GH_LOG"
mkdir -p .work
printf '<testsuites><testcase classname="e2e/invite.spec.ts" name="INVITE-AC1: form"/></testsuites>\n' >.work/e2e-junit.xml
[ -n "${KIT_SCREENSHOT_DIR:-}" ] && : >"$KIT_SCREENSHOT_DIR/INVITE-AC1-form-desktop.png"
exit 0
EOF
chmod +x "$work/bin/fake-e2e"
printf 'KIT_STACK_CHECKS="local"\nKIT_E2E="%s"\nKIT_E2E_REPORT=".work/e2e-junit.xml"\nKIT_MUTATION="n/a: no mutation tool in this fixture"\n' "'$work/bin/fake-e2e'" >>.claude/kit.conf
: >"$GH_LOG"
out=$(.claude/bin/stack checks 2>&1)
same "$?" 0 "STAGE-AC13: a green local stage"
same "$(grep -c '^local e2e' "$GH_LOG")" 1 "STAGE-AC12: the e2e command runs once in the checkout"
lacks "$(cat "$GH_LOG")" "workflow run" "STAGE-AC12: no dispatch"
contains "$(cat "$GH_LOG")" "statuses/$end_a -f state=success -f context=kit/e2e" "STAGE-AC13: kit/e2e on the lower layer"
contains "$(cat "$GH_LOG")" "-f context=kit/mutation" "STAGE-AC13: and kit/mutation"
git checkout -q .claude/kit.conf

# Into the pull requests.
mkdir -p .work/12-invite/evidence/screenshots
: >.work/12-invite/evidence/screenshots/INVITE-AC1-form-desktop.png
printf 'Invite (A)\n\n## What\n- layer\n' >"$work/bodies/12-invite-gA"
artifacts pass '' 'score 80 threshold 60 killed 8 survived 2 mutants 10'
STACK_POLL_SECONDS=0 .claude/bin/stack checks >/dev/null 2>&1
.claude/bin/stack bodies >"$work/out" 2>&1 || fail "bodies exits 0: $(cat "$work/out")"
contains "$(cat "$work/bodies/12-invite-gA")" "kit-evidence/12-invite/$(git rev-parse HEAD)/screenshots/INVITE-AC1-form-desktop.png" "STAGE-AC30: the layer's criterion screenshot is in its body"
contains "$(cat "$work/bodies/12-invite-gA")" "## What" "the description itself stays"
lacks "$(cat "$work/bodies/12-invite")" "### Screenshots" "STAGE-AC31: a layer whose criteria have no screenshot gets none"
contains "$(cat "$work/bodies/12-invite")" "**Mutation:** score 80 threshold 60 killed 8 survived 2" "STAGE-AC33: every layer shows the mutation score"
.claude/bin/stack bodies >/dev/null 2>&1
same "$(grep -c '^<!-- kit-stage -->$' "$work/bodies/12-invite-gA")" 1 "STAGE-AC32: a second update keeps one stage block"

# --- merging the stack (specs/risk-gates.md) ------------------------------------------

git checkout -q 18-next
same "$(.claude/bin/stack base)" "main" "stack base names the bottom layer's base"
: >"$GH_LOG"
FAKE_STACK=1 .claude/bin/stack merge >"$work/out" 2>&1 || fail "stack merge exits 0: $(cat "$work/out")"
contains "$(cat "$GH_LOG")" "stack merge $(grep -n '^18-next ' "$GH_PRS" | cut -d: -f1) --yes --squash" "RISK-AC33: gh stack merge through the top pull request, squash by default"
contains "$(cat "$GH_LOG")" "stack sync --prune" "the merged branches are pruned"
: >"$GH_LOG"
.claude/bin/stack merge >"$work/out" 2>&1 || fail "a chain merges without gh stack: $(cat "$work/out")"
contains "$(cat "$GH_LOG")" "pr merge 12-invite-gA --squash --delete-branch" "a chain merges from the bottom up"
contains "$(cat "$GH_LOG")" "pr edit 18-next --base main" "each pull request moves onto the base before it merges"

# --- the skills -------------------------------------------------------------------

desc=$here/kit/.claude/skills/pr-description/SKILL.md
ship=$here/kit/.claude/skills/ship-feature/SKILL.md
grep -qF '.work/<branch>/pr/<group>.md' "$desc" && grep -qF '`.work/<branch>-pr.md`' "$desc" && ok || fail "STACK-AC13: a description per layer, the top one at .work/<branch>-pr.md"
grep -qF "only the criteria of that layer's group's tasks" "$desc" && ok || fail "STACK-AC14: a layer's evidence names its group's criteria"
grep -qF '`(<n>/<N>)`' "$desc" && ok || fail "STACK-AC15: a layer's title ends with (n/N)"
grep -qF 'Reviewed and verified on the stack top, <branch>.' "$desc" && ok || fail "STACK-AC16: lower layers say where review and verify ran"
grep -qF 'With `ask` in a final session, do not run it' "$ship" && ok || fail "STACK-AC25: an ask at the push gate submits nothing"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
