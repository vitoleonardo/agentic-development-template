#!/bin/sh
# Tests for .claude/bin/evidence. Run: sh plugins/agentic-workflow-kit/tests/evidence.test.sh
# A fixture repo with fake checks and a bare local remote, so no network or real test runner is needed.
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
expect_code() {
  want=$1 description=$2
  shift 2
  out=$("$@" 2>&1)
  code=$?
  if [ "$code" -eq "$want" ]; then ok; else fail "$description (exit $code, wanted $want): $out"; fi
}
expect_out() { case $out in *"$1"*) ok ;; *) fail "$2: no '$1' in: $out" ;; esac; }
g() { git -c user.name=t -c user.email=t@example.invalid "$@"; }
# evidence push makes its own commit; CI runners have no git identity.
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

mkdir -p src bin
cat >bin/fake-tests <<'EOF'
#!/bin/sh
mkdir -p .work
{
  echo '<testsuites>'
  echo '<testcase classname="src/total.test.ts" name="total &gt; SHOP-AC1: shows the total"/>'
  echo '<testcase classname="src/total.test.ts" name="total &gt; SHOP-AC1: empty cart shows 0.00"/>'
  echo '</testsuites>'
} >.work/junit.xml
EOF
chmod +x bin/fake-tests
cat >.claude/kit.conf <<EOF
KIT_TYPECHECK="true"
KIT_LINT="true"
KIT_BUILD="n/a: library, no build step"
KIT_TEST="'$project/bin/fake-tests'"
KIT_TEST_REPORT=".work/junit.xml"
KIT_COVERAGE="true"
KIT_COVERAGE_FILES="printf 'src/total.ts\t9\t10\nsrc/lib/many.ts\t80\t80\n'"
KIT_DUPLICATES="true"
KIT_SOURCE_PATTERNS="*.ts"
KIT_PROTECTED_PATHS="vendor/ee"
KIT_MAX_CHANGED_LINES="20"
KIT_SEED="echo seeding; echo 'seed: fixtures-v2'"
KIT_E2E="echo e2e ok"
KIT_TEST_MOCKED="n/a: the app calls no external service"
EOF
printf '{\n  "name": "shop",\n  "dependencies": {\n    "zod": "4.0.0"\n  }\n}\n' >package.json
printf 'export const total = 0;\n' >src/total.ts
printf 'it("SHOP-AC1: shows the total", () => {});\n' >src/total.test.ts
mkdir -p vendor/ee && printf 'secret sauce\n' >vendor/ee/x.ts
git init -q -b main
g add -A
g commit -qm base
git init -q --bare "$work/remote.git"
git remote add origin "$work/remote.git"
g push -q origin main
git checkout -qb 42-total
mkdir -p .work
printf '# Plan\n\n- Approved dependencies: none\n' >.work/42-total.md
printf 'export const total = 1;\n' >src/total.ts
g commit -qam "change total"

# --- hard gates -----------------------------------------------------------------

expect_code 0 "clean change passes every gate" .claude/bin/evidence gates
expect_out "| build | n/a |" "n/a gate passes with its reason (VERIFY-AC8)"
grep -q "^build	n/a	.*library, no build step" .work/42-total/evidence/gates.tsv && ok || fail "the n/a reason is recorded"
grep -q "| coverage | pass |" .work/42-total/evidence/gates.md && ok || fail "gates.md has the table"

sed -i 's/^KIT_LINT=.*/KIT_LINT=""/' .claude/kit.conf
expect_code 1 "an empty hard-gate key fails (VERIFY-AC8)" .claude/bin/evidence gates
expect_out "| lint | fail |" "the unconfigured gate is named"
sed -i 's/^KIT_LINT=.*/KIT_LINT="true"/' .claude/kit.conf

printf 'it.only("SHOP-AC1: shows the total", () => {});\n' >src/total.test.ts
expect_code 1 "an added .only fails (VERIFY-AC4)" .claude/bin/evidence gates
expect_out "| focus | fail |" "the focus gate fails"
printf 'test.skip("x", () => {});\n' >src/total.test.ts
expect_code 1 "an added test.skip fails" .claude/bin/evidence gates
printf '@pytest.mark.xfail\ndef test_x():\n    pass\n' >src/test_x.py
expect_code 1 "an added xfail marker fails" .claude/bin/evidence gates
rm src/test_x.py
git checkout -q -- src/total.test.ts

printf '{\n  "name": "shop",\n  "dependencies": {\n    "zod": "4.0.0",\n    "left-pad": "1.3.0"\n  }\n}\n' >package.json
expect_code 1 "a new dependency the plan did not approve fails (VERIFY-AC4)" .claude/bin/evidence gates
expect_out "| dependencies | fail | 0s | not in the plan's Approved dependencies: left-pad" "the dependency is named"
printf '# Plan\n\n- Approved dependencies: left-pad\n' >.work/42-total.md
expect_code 0 "an approved dependency passes" .claude/bin/evidence gates
git checkout -q -- package.json
printf '# Plan\n\n- Approved dependencies: none\n' >.work/42-total.md

printf 'changed\n' >vendor/ee/x.ts
expect_code 1 "a change in a protected path fails" .claude/bin/evidence gates
expect_out "| protected | fail |" "the protected gate fails"
git checkout -q -- vendor/ee/x.ts

printf 'const token = "ghp_%s";\n' "abcdefghijklmnopqrstuvwxyz0123456789" >src/config.ts
expect_code 1 "a token in the diff fails the secret scan" .claude/bin/evidence gates
expect_out "| secrets | fail |" "the secret gate fails"
rm src/config.ts
printf 'const key = "AKIA%s";\n' "ABCDEFGHIJKLMNOP" >src/aws.test.ts
expect_code 1 "a key format fails in a test file too" .claude/bin/evidence gates
expect_out "| secrets | fail |" "the key format fails the secret gate"
rm src/aws.test.ts
printf 'export const login = { password: "demo-password-for-seed" };\n' >>src/total.ts
expect_code 0 "a name = value match without a key format is only a warning" .claude/bin/evidence gates
expect_out "| secrets | pass |" "the heuristic does not fail the gate"
expect_out "warning: possible secrets in src/total.ts" "the warning names the file"
expect_out "setup gap: gitleaks not installed" "the missing gitleaks is reported"
printf 'src/total.ts\tdemo-password-for-seed\n' >.claude/secrets-allow.tsv
expect_code 0 "an allowlisted value passes" .claude/bin/evidence gates
case $out in *"warning: possible secrets"*) fail "an allowlisted value still warns: $out" ;; *) ok ;; esac
printf 'src/other.ts\tdemo-password-for-seed\n' >.claude/secrets-allow.tsv
expect_code 0 "an allowlist row for another path does not apply" .claude/bin/evidence gates
expect_out "warning: possible secrets in src/total.ts" "the value still warns in a path the row does not name"
printf 'src/total.ts\tAKIA%s\n' "ABCDEFGHIJKLMNOP" >.claude/secrets-allow.tsv
printf 'const key = "AKIA%s";\n' "ABCDEFGHIJKLMNOP" >>src/total.ts
expect_code 1 "the allowlist never covers a key format" .claude/bin/evidence gates
git checkout -q -- src/total.ts
rm .claude/secrets-allow.tsv
mkdir -p reports/runs
printf 'stop\t6 verify\tkit\tsecrets flagged token = "ghp_%s"\t-\t-\n' "abcdefghijklmnopqrstuvwxyz0123456789" >reports/runs/42-total.tsv
expect_code 0 "run records are never scanned for secrets" .claude/bin/evidence gates
rm -r reports

# A fake gitleaks records its arguments and the config it was given; GITLEAKS_EXIT is its result.
mkdir -p "$work/fakebin"
cat >"$work/fakebin/gitleaks" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$work/gitleaks.args"
while [ \$# -gt 0 ]; do [ "\$1" = -c ] && cat "\$2" >>"$work/gitleaks.config"; shift; done
exit \${GITLEAKS_EXIT:-0}
EOF
chmod +x "$work/fakebin/gitleaks"
printf 'src/total.test.ts\tfake-value-for-tests\nsrc/total.test.ts\tghp_%s\n' "abcdefghijklmnopqrstuvwxyz0123456789" >.claude/secrets-allow.tsv
PATH=$work/fakebin:$PATH expect_code 0 "gitleaks without findings passes" .claude/bin/evidence gates
expect_out "| secrets | pass | 0s | gitleaks" "the gate names gitleaks"
args=$(cat "$work/gitleaks.args")
case $args in *"git "*"--log-opts"*"$(git merge-base main HEAD)..HEAD -- . :(exclude)vendor/ee :(exclude)reports/runs"*) ok ;; *) fail "gitleaks scans the branch's commits without protected paths and run records: $args" ;; esac
grep -q "useDefault = true" "$work/gitleaks.config" && ok || fail "the generated config extends the default rules"
grep -q "fake-value-for-tests" "$work/gitleaks.config" && grep -q 'src/total\\.test\\.ts' "$work/gitleaks.config" && ok || fail "the allowlist row reaches gitleaks: $(cat "$work/gitleaks.config")"
grep -q "ghp_" "$work/gitleaks.config" && fail "a key format in the allowlist reaches gitleaks" || ok
GITLEAKS_EXIT=1 PATH=$work/fakebin:$PATH expect_code 1 "gitleaks findings fail the gate" .claude/bin/evidence gates
expect_out "| secrets | fail |" "the gitleaks failure is recorded"
rm .claude/secrets-allow.tsv "$work/gitleaks.args" "$work/gitleaks.config"

mkdir -p src/lib
seq 1 30 | sed 's/^/export const x/;s/$/ = 1;/' >src/lib/many.ts
expect_code 0 "above the size limit is a warning" .claude/bin/evidence gates
expect_out "warning: 32 changed lines" "the size warning is shown"
seq 1 50 | sed 's/^/export const y/;s/$/ = 1;/' >>src/lib/many.ts
expect_code 1 "above twice the size limit fails" .claude/bin/evidence gates
rm -r src/lib

sed -i 's/^KIT_DUPLICATES=.*/KIT_DUPLICATES="echo \\"1 new clones\\"; exit 1"/' .claude/kit.conf
expect_code 1 "a clone the branch adds fails the duplicates gate" .claude/bin/evidence gates
expect_out "| duplicates | fail |" "the duplicates gate fails"
grep -q "| duplicates | fail | .*new clones" .work/42-total/evidence/gates.md && ok || fail "the clone count is in the detail"
sed -i 's/^KIT_DUPLICATES=.*/KIT_DUPLICATES=""/' .claude/kit.conf
expect_code 1 "an unconfigured duplicates gate fails" .claude/bin/evidence gates
expect_out "| duplicates | fail | 0s | not configured" "the unconfigured duplicates gate is named"
sed -i 's/^KIT_DUPLICATES=.*/KIT_DUPLICATES="true"/' .claude/kit.conf

sed -i 's/^KIT_DUPLICATES=.*/KIT_DUPLICATES="echo \\"coverage in web: 0% of the lines in the changed files are covered; at least 70% is required.\\""/' .claude/kit.conf
expect_code 1 "a check that prints a failing value but exits 0 fails its gate" .claude/bin/evidence gates
expect_out "| duplicates | fail |" "the inconsistent gate is named"
expect_out "printed a value below its threshold but exited 0" "the inconsistency is explained"
sed -i 's/^KIT_DUPLICATES=.*/KIT_DUPLICATES="true"/' .claude/kit.conf

printf 'export const helper = 1;\n' >src/helpers.ts
expect_code 1 "a new source file outside the Map fails the structure gate" .claude/bin/evidence gates
expect_out "| structure | fail |" "the structure gate fails"
rm src/helpers.ts
expect_code 0 "the structure gate passes without misplaced files" .claude/bin/evidence gates
expect_out "| structure | pass |" "the structure gate passes"

# --- later rounds: only what changed ---------------------------------------------

expect_code 0 "gates --only runs only the named gates" .claude/bin/evidence gates --only typecheck,secrets
same_gates=$(cut -f1 .work/42-total/evidence/gates.tsv | tr '\n' ' ')
[ "$same_gates" = "typecheck secrets " ] && ok || fail "only the named gates ran: $same_gates"
expect_code 1 "json refuses a pack whose gates ran with --only" .claude/bin/evidence json
expect_out "--only" "the refusal names the partial run"
expect_code 2 "an unknown gate in --only is a usage error" .claude/bin/evidence gates --only typo
expect_code 0 "a full run makes the pack whole again" .claude/bin/evidence gates
[ ! -f .work/42-total/evidence/gates.partial ] && ok || fail "the full run removes the partial mark"

start=$(git rev-parse HEAD)
seq 1 20 | sed 's/^/it("SHOP-AC1: case /;s/$/", () => {});/' >>src/total.test.ts
g commit -qam "more cases"
since=$(git rev-parse HEAD)
printf 'it("SHOP-AC1: one more", () => {});\n' >>src/total.test.ts
g commit -qam "fix"
out=$(.claude/bin/evidence scope "$since" 2>&1)
expect_out "delta $(git rev-parse --short "$since")..$(git rev-parse --short HEAD) (4% of the diff)" "a small fix is a delta round"
out=$(.claude/bin/evidence scope "$start" 2>&1)
expect_out "full: the fixes are 91% of the diff, more than 20%" "a large fix is a full round"
mkdir -p db/migrations && printf 'alter table x;\n' >db/migrations/2.sql
g add -A && g commit -qm "migration"
out=$(KIT_CONTRACT_PATTERNS="db/migrations/*" .claude/bin/evidence scope "$since" 2>&1)
expect_out "full: db/migrations/2.sql is a contract file (KIT_CONTRACT_PATTERNS)" "a contract file forces a full round"
git reset -q --hard "$start"

# --- edge-case matrix -----------------------------------------------------------

expect_code 0 "gates pass again" .claude/bin/evidence gates
cat >.work/42-total/evidence/edge-cases.md <<'EOF'
# Edge cases

| Criterion | Case | Input | Expected | Test | Result |
|-----------|------|-------|----------|------|--------|
| SHOP-AC1 | happy path | 2 items | total shown | SHOP-AC1: shows the total | |
| SHOP-AC1 | empty data | no items | 0.00 | SHOP-AC1: empty cart shows 0.00 | |
| SHOP-AC1 | concurrent edits | two tabs | | n/a: the cart lives in one tab only | |
| SHOP-AC1 | double submit | press twice | one total | | |
EOF
expect_code 1 "a case without a test fails verify (VERIFY-AC3)" .claude/bin/evidence matrix
expect_out "fail: no test" "the missing test is reported"
sed -i 's/| press twice | one total | | |/| press twice | one total | SHOP-AC1: double submit counts once | |/' .work/42-total/evidence/edge-cases.md
expect_code 1 "a named test that never ran fails" .claude/bin/evidence matrix
expect_out "no test named like this ran" "the unknown test is reported"
sed -i '/double submit/d' .work/42-total/evidence/edge-cases.md
expect_code 0 "every case has a passing test or a reason" .claude/bin/evidence matrix

# --- data runs ------------------------------------------------------------------

expect_code 0 "seed and e2e run, mocked is n/a" .claude/bin/evidence data
grep -q "seed: fixtures-v2" .work/42-total/evidence/data-runs.md && ok || fail "the seed version is recorded"
grep -q "n/a: the app calls no external service" .work/42-total/evidence/data-runs.md && ok || fail "the mocked n/a reason is recorded"
cp .claude/kit.conf kit.conf.orig
cat >>.claude/kit.conf <<'EOF'
KIT_RUN_DB="shop_e2e"
KIT_RUN_REDIS_DB="14"
KIT_RUN_PORT="3101"
KIT_SEED="echo \"seed: \$KIT_RUN_DB redis \$KIT_RUN_REDIS_DB port \$KIT_RUN_PORT\""
EOF
expect_code 0 "data runs with the run's own resources" .claude/bin/evidence data
grep -q "seed: shop_e2e redis 14 port 3101" .work/42-total/evidence/data-runs.md && ok || fail "KIT_RUN_DB, KIT_RUN_REDIS_DB and KIT_RUN_PORT reach the commands: $(cat .work/42-total/evidence/data-runs.md)"
mv kit.conf.orig .claude/kit.conf

# --- evidence.json, push, CI check, comment -------------------------------------

mkdir -p .work/42-total/evidence/screenshots
printf 'png' >.work/42-total/evidence/screenshots/SHOP-AC1-1-desktop.png
printf 'png' >.work/42-total/evidence/screenshots/SHOP-AC1-1-desktop.main.png
printf '## Criteria\n\n## Findings\n1. [medium] src/total.ts:1: x\n2. [low] y\n\n## Ready for PR\nyes\n' >.work/42-total/evidence/review.md
expect_code 0 "evidence.json is written" .claude/bin/evidence json
if python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["head"]==sys.argv[2]; c=d["criteria"][0]; assert c["id"]=="SHOP-AC1" and c["edge_cases"]==3 and c["edge_cases_passed"]==3 and c["seeded"]=="pass" and c["mocked"]=="n/a" and "SHOP-AC1-1-desktop.png" in c["screenshots"]; assert d["review"]=={"verdict":"ready","high":0,"medium":1,"low":1}' .work/42-total/evidence/evidence.json "$(git rev-parse HEAD)"; then ok; else fail "evidence.json content: $(cat .work/42-total/evidence/evidence.json)"; fi

head=$(git rev-parse HEAD)
expect_code 1 "CI rejects a PR without a pack (VERIFY-AC5)" .claude/bin/evidence ci-check --head "$head" --key pr-7 --key 42-total
expect_code 0 "the pack is pushed to kit-evidence" .claude/bin/evidence push --pr 7
git -C "$work/remote.git" cat-file -e "kit-evidence:pr-7/$head/evidence.json" && ok || fail "the pack is on the remote branch"
[ "$(git branch --show-current)" = 42-total ] && [ -z "$(git status --porcelain --untracked-files=no)" ] && ok || fail "push leaves the branch and the tree alone"
expect_code 0 "CI accepts the pack for the head" .claude/bin/evidence ci-check --head "$head" --key pr-7 --key 42-total
printf 'export const total = 2;\n' >src/total.ts
g commit -qam "another push"
expect_code 1 "CI rejects a pack from an older commit (VERIFY-AC5)" .claude/bin/evidence ci-check --head "$(git rev-parse HEAD)" --key pr-7 --key 42-total
expect_out "Stale evidence counts as no evidence" "the stale pack is explained"
expect_code 1 "push refuses a pack that is not for HEAD" .claude/bin/evidence push --pr 7

expect_code 0 "the comment renders" .claude/bin/evidence comment --dir .work/42-total/evidence --repo me/shop --key pr-7
expect_out "<!-- kit-evidence -->" "the comment has the sticky marker"
expect_out "| typecheck | pass |" "the comment has the gate table (VERIFY-AC6)"
expect_out "![SHOP-AC1-1-desktop.png](https://github.com/me/shop/blob/kit-evidence/pr-7/$head/screenshots/SHOP-AC1-1-desktop.png?raw=true)" "the comment shows the screenshot inline (VERIFY-AC6)"
expect_out "SHOP-AC1-1-desktop.main.png" "the base screenshot sits next to it"
expect_out "**Review:** ready, 0 high, 1 medium, 1 low." "the review summary"

# --- e2e selection: only the e2e tests a change affects --------------------------

# On main: two features with e2e tests, a shared fixture, and runners that record what they were given.
git checkout -q main
mkdir -p e2e
printf 'test("SHOP-AC1: shows the total", () => {});\n' >e2e/shop.spec.ts
printf 'test("CART-AC2: removes an item", () => {});\n' >e2e/cart.spec.ts
printf 'export const fixture = 1;\n' >e2e/fixtures.ts
printf 'export const other = 0;\n' >src/other.ts
printf '.work/\n' >.gitignore
tab=$(printf '\t')
cat >bin/fake-e2e <<'EOF'
#!/bin/sh
printf '%s\n' "${*:-ALL}" >>"$E2E_LOG"
[ -n "${BASE_HINT:-}" ] && printf 'env:%s\n' "$BASE_HINT" >>"$E2E_LOG"
if [ -z "${KIT_SCREENSHOT_DIR:-}" ]; then
  mkdir -p .work
  failure=""
  [ -n "${E2E_FAIL:-}" ] && failure='<failure message="x"/>'
  printf '<testsuites><testcase classname="e2e/shop.spec.ts" name="SHOP-AC1: the total updates in the browser">%s</testcase></testsuites>\n' "$failure" >.work/e2e-junit.xml
  [ -z "${E2E_FAIL:-}" ] || exit 1
fi
[ -n "${KIT_SCREENSHOT_DIR:-}" ] && : >"$KIT_SCREENSHOT_DIR/SHOP-AC1-1-desktop$KIT_SCREENSHOT_SUFFIX.png"
exit 0
EOF
chmod +x bin/fake-e2e
cat >>.claude/kit.conf <<EOF
KIT_E2E="'$project/bin/fake-e2e'"
KIT_E2E_RELATED="'$project/bin/fake-e2e'"
KIT_E2E_PATTERNS="e2e/*.spec.ts"
KIT_E2E_REPORT=".work/e2e-junit.xml"
KIT_E2E_FULL_PATTERNS="package.json e2e/fixtures.ts"
KIT_TEST_PATTERNS="*.test.ts e2e/*"
KIT_SCREENSHOTS="'$project/bin/fake-e2e' ALL-SHOTS"
KIT_SCREENSHOTS_RELATED="'$project/bin/fake-e2e' SHOTS"
EOF
g add -A
g commit -qm "e2e tests"
export E2E_LOG="$work/e2e.log"

# branch_with <branch> <change command>: a branch off main with one committed change, then `evidence e2e-select`.
branch_with() {
  git checkout -q main
  git checkout -qb "$1"
  sh -c "$2"
  g add -A
  g commit -qm "$1"
  out=$(.claude/bin/evidence e2e-select 2>&1)
}

branch_with sel-docs "printf 'docs\n' >NOTES.md; printf 'it(\"SHOP-AC9: x\", () => {});\n' >src/x.test.ts"
expect_out "none:" "a change without source or e2e changes runs no e2e"
: >"$E2E_LOG"
expect_code 0 "data passes when no e2e test is affected" .claude/bin/evidence data
grep -q "^e2e${tab}n/a${tab}0${tab}n/a: only tests and docs changed" .work/sel-docs/evidence/data-runs.tsv && ok || fail "the skipped e2e run and why: $(cat .work/sel-docs/evidence/data-runs.tsv)"
[ ! -s "$E2E_LOG" ] && ok || fail "no e2e runner ran: $(cat "$E2E_LOG")"

branch_with sel-feature "printf 'export const total = 5;\n' >src/total.ts; printf 'it(\"SHOP-AC3: rounds\", () => {});\n' >>src/total.test.ts"
expect_out "related:" "a feature change runs related e2e tests"
expect_out "e2e/shop.spec.ts" "the e2e tests of the criteria the diff names (SHOP)"
case $out in *cart.spec.ts*) fail "another feature's e2e tests are not selected: $out" ;; *) ok ;; esac
: >"$E2E_LOG"
expect_code 0 "data runs the related e2e tests" .claude/bin/evidence data
[ "$(cat "$E2E_LOG")" = "e2e/shop.spec.ts" ] && ok || fail "KIT_E2E_RELATED gets the selected files: $(cat "$E2E_LOG")"
grep -q "^e2e${tab}pass${tab}[0-9]*${tab}related:" .work/sel-feature/evidence/data-runs.tsv && ok || fail "the selection is recorded: $(cat .work/sel-feature/evidence/data-runs.tsv)"
: >"$E2E_LOG"
expect_code 0 "data --all runs the whole suite" .claude/bin/evidence data --all
[ "$(cat "$E2E_LOG")" = "ALL" ] && ok || fail "--all runs KIT_E2E: $(cat "$E2E_LOG")"
: >"$E2E_LOG"
expect_code 0 "screenshots of the related tests" .claude/bin/evidence screenshots --no-base
grep -q "^SHOTS e2e/shop.spec.ts$" "$E2E_LOG" && ok || fail "KIT_SCREENSHOTS_RELATED gets the selected files: $(cat "$E2E_LOG")"

: >"$E2E_LOG"
printf 'BASE_HINT=from-the-env-file\n' >"$work/base.env"
printf 'KIT_BASE_ENV="%s"\n' "$work/base.env" >>.claude/kit.conf
expect_code 0 "screenshots on the branch and the base" .claude/bin/evidence screenshots
[ "$(grep -c '^env:from-the-env-file$' "$E2E_LOG")" -eq 1 ] && ok || fail "only the base run gets KIT_BASE_ENV: $(cat "$E2E_LOG")"
[ -f .work/sel-feature/evidence/screenshots/SHOP-AC1-1-desktop.main.png ] && ok || fail "the base run writes .main images"
git checkout -q .claude/kit.conf

branch_with sel-newfeature "printf 'export const other = 2;\n' >src/other.ts; printf 'test(\"NEWF-AC1: shows the new page\", () => {});\n' >e2e/newf.spec.ts"
: >"$E2E_LOG"
expect_code 0 "screenshots pass when the base has no e2e test of the feature" .claude/bin/evidence screenshots
expect_out "n/a: base has no NEWF" "the skipped base run says why"
case $out in *"base run failed"*) fail "a base without the feature is not a failure: $out" ;; *) ok ;; esac
grep -q "base: n/a: base has no NEWF" .work/sel-newfeature/evidence/screenshots.txt && ok || fail "the pack records the skipped base: $(cat .work/sel-newfeature/evidence/screenshots.txt 2>&1)"
[ "$(grep -c . "$E2E_LOG")" -eq 1 ] && ok || fail "only the branch run ran: $(cat "$E2E_LOG")"

# An e2e-only case passes or fails with the e2e run instead of being n/a.
git checkout -q sel-feature
.claude/bin/evidence gates >/dev/null 2>&1
cat >.work/sel-feature/evidence/edge-cases.md <<'EOF'
| Criterion | Case | Input | Expected | Test | Result |
|-----------|------|-------|----------|------|--------|
| SHOP-AC1 | in the browser | add an item | the total updates | SHOP-AC1: the total updates in the browser | |
EOF
expect_code 1 "before the data run, an e2e-only case has no result" .claude/bin/evidence matrix
expect_code 0 "the data run passes" .claude/bin/evidence data
expect_code 0 "after the data run, the e2e case passes" .claude/bin/evidence matrix
E2E_FAIL=1 expect_code 1 "a failing e2e run fails the data run" .claude/bin/evidence data
expect_code 1 "a failing e2e case fails the matrix" .claude/bin/evidence matrix
expect_out "fail: fail" "the failing e2e case is reported"
[ "$(grep -c 'the total updates in the browser' .work/sel-feature/evidence/tests.tsv)" -eq 1 ] && ok || fail "a rerun replaces the e2e rows: $(cat .work/sel-feature/evidence/tests.tsv)"

branch_with sel-e2e "printf 'test(\"CART-AC2: removes the last item\", () => {});\n' >>e2e/cart.spec.ts"
expect_out "e2e/cart.spec.ts" "a changed e2e test file runs"

printf 'test("CART-AC3: empties the cart", () => {});\n' >e2e/empty.spec.ts
out=$(.claude/bin/evidence e2e-select 2>&1)
expect_out "e2e/empty.spec.ts" "a new e2e file that is not committed yet runs"
rm e2e/empty.spec.ts

branch_with sel-fixture "printf 'export const fixture = 2;\n' >e2e/fixtures.ts"
expect_out "all: e2e/fixtures.ts changed" "a change to shared e2e setup runs the whole suite"

branch_with sel-unmapped "printf 'export const other = 1;\n' >src/other.ts"
expect_out "all:" "a source change no e2e test maps to runs the whole suite"
: >"$E2E_LOG"
.claude/bin/evidence screenshots --no-base >/dev/null 2>&1
grep -q "^ALL-SHOTS$" "$E2E_LOG" && ok || fail "all screenshots when the whole suite runs: $(cat "$E2E_LOG")"

git checkout -q sel-feature
sed -i '/KIT_E2E_RELATED/d' .claude/kit.conf
out=$(.claude/bin/evidence e2e-select 2>&1)
expect_out "all: KIT_E2E_RELATED is not set" "without a related command the whole suite runs"
git checkout -q .claude/kit.conf

# --- red: criterion tests must fail without the change -----------------------------

git checkout -q main
git checkout -qb red-proof
# A test runner for the files it is given: a title with "needs-change" passes only when src/total.ts has the change.
cat >bin/red-tests <<'EOF'
#!/bin/sh
mkdir -p .work
{
  echo '<testsuites>'
  for f; do
    sed -n 's/^it("\([^"]*\)".*/\1/p' "$f" | while IFS= read -r t; do
      case $t in
        *needs-change*) grep -q 'total = 1' src/total.ts && echo "<testcase classname=\"$f\" name=\"total &gt; $t\"/>" || echo "<testcase classname=\"$f\" name=\"total &gt; $t\"><failure/></testcase>" ;;
        *) echo "<testcase classname=\"$f\" name=\"total &gt; $t\"/>" ;;
      esac
    done
  done
  echo '</testsuites>'
} >.work/junit.xml
EOF
chmod +x bin/red-tests
printf 'KIT_TEST="%s/bin/red-tests"\nKIT_SETUP="echo setup >>%s/setup.log"\n' "$project" "$project" >>.claude/kit.conf
printf '# Plan\n\n- Approved dependencies: none\n' >.work/red-proof.md
printf 'export const total = 1;\n' >src/total.ts
expect_code 0 "red without a new criterion test" .claude/bin/evidence gates --only red
expect_out "| red | pass | 0s | no test file adds a criterion test |" "nothing to prove without a new criterion test"
printf 'it("SHOP-AC2: the total is one needs-change", () => {});\nit("SHOP-AC3: the total exists", () => {});\n' >>src/total.test.ts
: >setup.log
expect_code 0 "red warns and never fails, for now" .claude/bin/evidence gates --only red
expect_out "warning: pass without the change: SHOP-AC3: the total exists;" "a new criterion test that passes on the base is named"
case $out in *SHOP-AC2*) fail "a test that fails on the base is not named: $out" ;; *) ok ;; esac
case $out in *SHOP-AC1*) fail "an unchanged test is not named: $out" ;; *) ok ;; esac
grep -q setup setup.log && ok || fail "KIT_SETUP runs on the base"
[ -z "$(git worktree list | sed 1d)" ] && ok || fail "the base worktree is removed: $(git worktree list)"
printf '\n## Red exceptions\n- SHOP-AC3: the total exists | checked by the e2e flow\n\n## Notes\n' >>.work/red-proof.md
expect_code 0 "red with an exception" .claude/bin/evidence gates --only red
expect_out "the criterion tests of 1 files fail on the base" "a listed exception is not named"
printf 'KIT_TEST="true"\n' >>.claude/kit.conf
expect_code 0 "red when the base run writes no report" .claude/bin/evidence gates --only red
expect_out "the base run wrote no .work/junit.xml" "a missing report is named"
git checkout -q -- .claude/kit.conf src/total.ts src/total.test.ts
rm -f bin/red-tests setup.log

# --- one base for stacked branches ----------------------------------------------

git checkout -q main
git checkout -qb m4
printf '{\n  "name": "shop",\n  "dependencies": {\n    "zod": "4.0.0",\n    "left-pad": "1.3.0"\n  }\n}\n' >package.json
g commit -qam "m4 adds left-pad"
git checkout -qb m5
printf 'export const total = 7;\n' >src/total.ts
g commit -qam "m5 changes the total"
printf '# Plan: Total (spec: specs/total.md)\n\n- Approved dependencies: none\n' >.work/m5.md
expect_code 1 "without a recorded base, the stacked branch counts the earlier milestone" .claude/bin/evidence gates
expect_out "| dependencies | fail |" "the inherited dependency fails"
printf '# Plan: Total (spec: specs/total.md)\nBase: m4\n\n- Approved dependencies: none\n' >.work/m5.md
expect_code 0 "the state file's base leaves the earlier milestone out" .claude/bin/evidence gates
expect_out "| dependencies | pass |" "the dependency from m4 is not this branch's"
expect_out "| size | pass | 0s | 2 changed lines" "the size counts only this branch"
grep -q "base m4" .work/m5/evidence/gates.md && ok || fail "gates.md names the base: $(head -n 3 .work/m5/evidence/gates.md)"
KIT_BASE=main expect_code 1 "KIT_BASE wins over the state file" .claude/bin/evidence gates

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
