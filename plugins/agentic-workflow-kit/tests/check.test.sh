#!/bin/sh
# Tests for .claude/bin/check and .claude/bin/baseline. Run: sh plugins/agentic-workflow-kit/tests/check.test.sh
# A two-package fixture (root + packages/py) with fake tools, so no real test runner or network is needed.
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT
cp -R "$here/kit/." "$project/"
cd "$project" || exit 1

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }

# expect_code <code> <description> <command...>
expect_code() {
  want=$1 description=$2
  shift 2
  out=$("$@" 2>&1)
  code=$?
  if [ "$code" -eq "$want" ]; then ok; else fail "$description (exit $code, wanted $want): $out"; fi
}

# expect_out <pattern> <description>: the last output must contain the pattern.
expect_out() {
  case $out in *"$1"*) ok ;; *) fail "$2: no '$1' in: $out" ;; esac
}

# --- parsers --------------------------------------------------------------------

cat >junit.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<testsuites name="vitest tests" tests="5" failures="1">
  <testsuite name="src/a.test.ts" tests="4">
    <testcase classname="src/a.test.ts" name="parse &gt; A-AC1: splits &quot;a&quot;" time="0.01">
    </testcase>
    <testcase classname="src/a.test.ts" name="parse > A-AC2: fails" time="0.01">
      <failure message="expected 1 &lt; 2" type="AssertionError">
AssertionError: expected <1> to be 2
      </failure>
    </testcase>
    <testcase classname="src/a.test.ts" name="parse > skipped one" time="0"><skipped/></testcase>
    <testcase classname="src/a.test.ts" name="self closing" time="0"/>
  </testsuite>
  <testsuite name="pytest"><testcase classname="tests.test_x" name="test_err[1]" time="0.1"><error message="boom"/></testcase></testsuite>
</testsuites>
EOF
got=$(.claude/bin/baseline junit junit.xml)
want='src/a.test.ts::parse > A-AC1: splits "a"	pass
src/a.test.ts::parse > A-AC2: fails	fail
src/a.test.ts::parse > skipped one	skip
src/a.test.ts::self closing	pass
tests.test_x::test_err[1]	fail'
[ "$got" = "$want" ] && ok || fail "junit parse: got
$got"

got=$(printf '%s\n' \
  "src/a.ts(3,5): error TS2322: Type 'string' is not assignable" \
  "src/a.ts(9,1): error TS1005: ';' expected." \
  "$project/src/b.ts:4:2 lint/style/useConst  FIXABLE  ━━━━━" \
  "app/x.py:12: error: Incompatible types" \
  "app/x.py:13: note: see above" \
  "app/y.py:1:8: F401 [*] 'os' imported but unused" \
  "$project/src/c.js" \
  "  1:10  error  'x' is defined but never used  no-unused-vars" \
  "  2:1   warning  Unexpected console statement  no-console" \
  "Found 3 errors in 2 files." \
  "$project/app/z.py" \
  "  $project/app/z.py:3:5 - error: Cannot access attribute" \
  "  $project/app/z.py:4:1 - warning: Import could not be resolved" \
  "12:30:01 compiled" | .claude/bin/baseline errors)
want='app/x.py	1
app/y.py	1
app/z.py	1
src/a.ts	2
src/b.ts	1
src/c.js	1'
[ "$got" = "$want" ] && ok || fail "error parse: got
$got"

# --- fixture --------------------------------------------------------------------

mkdir -p src packages/py/.claude packages/py/app bin
# fake-tests <results file> <report>: writes a JUnit report from "id status" lines; "flaky" fails on the first run only.
cat >bin/fake-tests <<'EOF'
#!/bin/sh
results=$1 report=$2
mkdir -p "$(dirname "$report")"
code=0
{
  echo '<testsuites>'
  while read -r cls name status; do
    if [ "$status" = flaky ]; then
      if [ -f "$results.ran" ]; then status=pass; else status=fail; fi
    fi
    if [ "$status" = fail ]; then
      code=1
      printf '<testcase classname="%s" name="%s"><failure message="x"/></testcase>\n' "$cls" "$name"
    else
      printf '<testcase classname="%s" name="%s"/>\n' "$cls" "$name"
    fi
  done <"$results"
  echo '</testsuites>'
} >"$report"
touch "$results.ran"
exit $code
EOF
chmod +x bin/fake-tests
cat >.claude/kit.conf <<EOF
KIT_TYPECHECK="cat '$project/root.types'; test ! -s '$project/root.types'"
KIT_LINT="echo root-lint"
KIT_TEST="'$project/bin/fake-tests' '$project/root.tests' .work/junit.xml"
KIT_TEST_REPORT=".work/junit.xml"
KIT_TEST_RELATED="printf 'related in %s:' \"\$PWD\"; printf ' [%s]'"
KIT_BUILD="n/a: no build step"
KIT_COVERAGE="true"
KIT_COVERAGE_FILES="cat '$project/root.cov'"
KIT_COVERAGE_PCT="cat '$project/root.pct'"
KIT_SOURCE_PATTERNS="*.ts"
EOF
cat >packages/py/.claude/kit.conf <<EOF
KIT_LINT="cat '$project/py.lint'; test ! -s '$project/py.lint'"
KIT_TEST_RELATED="printf 'py related in %s:' \"\$PWD\"; printf ' [%s]'"
KIT_SOURCE_PATTERNS="*.py"
EOF
printf 'src/a.test.ts ok1 pass\nsrc/a.test.ts legacy fail\nsrc/b.test.ts gone pass\n' >root.tests
: >root.types
printf 'app/old.py:1:1: F401 unused\napp/old.py:2:1: F401 unused\n' >py.lint
printf 'src/a.ts\t8\t10\n' >root.cov
printf '80\n' >root.pct
printf 'export const a = 1\n' >src/a.ts
printf 'it("gone", () => {})\n' >src/b.test.ts
printf 'x = 1\n' >packages/py/app/old.py
printf 'x = 1\n' >packages/py/app/new.py
git init -q -b main
git add -A
git -c user.name=t -c user.email=t@example.invalid commit -qm base

# --- nested kit.conf ------------------------------------------------------------

expect_code 0 "files are grouped by package" .claude/bin/check test-related src/a.ts "packages/py/app/my file.py"
expect_out "related in $project: [src/a.ts]" "root files run from the root"
expect_out "py related in $project/packages/py: [app/my file.py]" "package files run from the package, relative to it"
expect_code 0 "absolute paths are made relative" .claude/bin/check test-related "$project/packages/py/app/new.py"
expect_out "[app/new.py]" "absolute path in a package"
expect_code 3 "a check no package configures is not configured" .claude/bin/check format
expect_code 4 "n/a: <reason> exits 4" .claude/bin/check build
expect_out "n/a: no build step" "the n/a reason is shown"
expect_code 1 "without files, every package runs and the first failure decides" .claude/bin/check lint
expect_out "== lint in packages/py ==" "each package is named"

# --- baseline record ------------------------------------------------------------

.claude/bin/baseline record --out .claude/baseline.tsv >/dev/null 2>&1 || fail "record failed"
grep -q "^test	.	src/a.test.ts::legacy	fail$" .claude/baseline.tsv && ok || fail "legacy failure recorded"
grep -q "^count	.	tests	3$" .claude/baseline.tsv && ok || fail "test count recorded"
grep -q "^lint	packages/py	app/old.py	2$" .claude/baseline.tsv && ok || fail "lint errors per file recorded"
grep -q "^coverage	.	80$" .claude/baseline.tsv && ok || fail "overall coverage recorded"
git add -A && git -c user.name=t -c user.email=t@example.invalid commit -qm baseline
git checkout -qb change

# --- tests against the baseline -------------------------------------------------

rm -f root.tests.ran
expect_code 0 "a legacy failure does not block" .claude/bin/check --against-baseline test
expect_out "legacy, not blocking: src/a.test.ts::legacy" "legacy failure is reported"
printf 'src/a.test.ts ok1 fail\nsrc/a.test.ts legacy fail\nsrc/b.test.ts gone pass\n' >root.tests
expect_code 1 "a test that passed in the baseline and fails now blocks" .claude/bin/check --against-baseline test
expect_out "new failure: src/a.test.ts::ok1" "the new failure is named"
printf 'src/a.test.ts ok1 pass\nsrc/a.test.ts legacy fail\nsrc/b.test.ts gone pass\nsrc/c.test.ts fresh fail\n' >root.tests
expect_code 1 "a new test that fails blocks" .claude/bin/check --against-baseline test
rm -f root.tests.ran
printf 'src/a.test.ts ok1 flaky\nsrc/a.test.ts legacy fail\nsrc/b.test.ts gone pass\n' >root.tests
expect_code 0 "a test that passes on the rerun is flaky, not blocking" .claude/bin/check --against-baseline test
expect_out "flaky (passed on the rerun): src/a.test.ts::ok1" "flaky test is reported"
printf 'src/a.test.ts ok1 pass\nsrc/a.test.ts legacy fail\n' >root.tests
expect_code 1 "a test that disappears without the diff removing it blocks" .claude/bin/check --against-baseline test
expect_out "disappeared, but the diff does not remove it: src/b.test.ts::gone" "vanished test is named"
git rm -q src/b.test.ts
expect_code 0 "a test the diff deletes may disappear" .claude/bin/check --against-baseline test
expect_out "removed by the diff: src/b.test.ts::gone" "removed test is reported"
: >root.tests
expect_code 1 "zero tests is a failure" .claude/bin/check --against-baseline test
printf 'src/a.test.ts ok1 pass\nsrc/a.test.ts legacy fail\n' >root.tests

# --- lint and typecheck against the baseline ------------------------------------

expect_code 0 "legacy lint errors in unchanged files do not block" .claude/bin/check --against-baseline lint
printf 'x = 2\n' >packages/py/app/old.py
expect_code 1 "an error in a changed file blocks" .claude/bin/check --against-baseline lint
expect_out "error in a changed file: app/old.py" "the changed file is named"
git checkout -q -- packages/py/app/old.py
printf 'app/old.py:1:1: F401 unused\napp/old.py:2:1: F401 unused\napp/other.py:3:1: E501 long\n' >py.lint
expect_code 1 "more errors outside the changed files blocks" .claude/bin/check --against-baseline lint
printf 'app/old.py:1:1: F401 unused\napp/old.py:2:1: F401 unused\n' >py.lint
printf 'something broke\n' >root.types
expect_code 1 "an exit code without readable errors blocks" .claude/bin/check --against-baseline typecheck
expect_out "no file:line errors could be read" "unreadable output is explained"
: >root.types

# --- coverage against the baseline ----------------------------------------------

printf 'export const a = 2\n' >src/a.ts
expect_code 0 "changed files above the threshold pass" .claude/bin/check --against-baseline coverage
expect_out "80%" "changed-files coverage is printed"
printf 'src/a.ts\t5\t10\n' >root.cov
expect_code 1 "changed files below the threshold fail" .claude/bin/check --against-baseline coverage
printf 'src/a.ts\t9\t10\n' >root.cov
printf '79.6\n' >root.pct
expect_code 0 "overall coverage within the tolerance passes" .claude/bin/check --against-baseline coverage
printf '79.4\n' >root.pct
expect_code 1 "overall coverage below the tolerance fails" .claude/bin/check --against-baseline coverage
printf '80\n' >root.pct
seq 1 5 | sed 's/^/export const b/;s/$/ = 1/' >src/b.ts
expect_code 1 "a changed file missing from the coverage report counts as 0%" .claude/bin/check --against-baseline coverage
expect_out "| src/b.ts | 0/5 (not in the coverage report) |" "the missing file is listed with its line count"
rm src/b.ts
mkdir -p tests && printf 'export const helper = 1\n' >tests/helper.ts
out=$(.claude/bin/check --against-baseline coverage 2>&1)
case $out in *tests/helper.ts*) fail "a file in a top-level tests/ folder is not a source file: $out" ;; *) ok ;; esac
rm -r tests

# --- a later package that passes keeps an earlier failure -----------------------

cp packages/py/.claude/kit.conf py.conf.orig
cat >>packages/py/.claude/kit.conf <<EOF
KIT_TYPECHECK="true"
KIT_COVERAGE="true"
KIT_COVERAGE_FILES="printf 'app/new.py\t1\t1\n'"
EOF
printf 'x = 2\n' >packages/py/app/new.py
printf 'src/a.ts\t5\t10\n' >root.cov
expect_code 1 "coverage fails when an earlier package fails and a later one passes" .claude/bin/check --against-baseline coverage
expect_out "at least 70% is required" "the failing package is reported"
printf 'src/a.ts\t9\t10\n' >root.cov
git checkout -q -- packages/py/app/new.py
mv py.conf.orig packages/py/.claude/kit.conf
cp .claude/kit.conf root.conf.orig
printf 'src/a.ts:1:1: lint/style wrong\n' >root.lint
printf 'KIT_LINT="cat %s; test ! -s %s"\n' "'$project/root.lint'" "'$project/root.lint'" >>.claude/kit.conf
expect_code 1 "lint fails when an earlier package fails and a later one has only legacy errors" .claude/bin/check --against-baseline lint
expect_out "error in a changed file: src/a.ts" "the failing package is reported"
mv root.conf.orig .claude/kit.conf

# --- loosened baselines ---------------------------------------------------------

sed -e 's/ok1	pass/ok1	fail/' -e 's/^coverage	.	80$/coverage	.	70/' .claude/baseline.tsv >looser.tsv
expect_code 1 "a looser baseline is detected" .claude/bin/baseline loosened .claude/baseline.tsv looser.tsv
expect_out "test now fail (was pass): . src/a.test.ts::ok1" "the loosened test is listed"
expect_out "coverage in .: 70% (was 80%)" "the lower coverage is listed"
grep -v 'legacy' .claude/baseline.tsv >stricter.tsv
expect_code 0 "a stricter baseline is not loosened" .claude/bin/baseline loosened .claude/baseline.tsv stricter.tsv

# --- duplicates ------------------------------------------------------------------

# A fake jscpd records its arguments and the base it was given, and fails when asked to.
cat >bin/jscpd <<'EOF'
#!/bin/sh
echo "jscpd base=$KIT_BASE args=$*"
[ ! -f "${JSCPD_FAIL:-/nonexistent}" ] || { echo "ERROR: jscpd found 1 new clones not in the baseline (allowed: 0)"; exit 1; }
EOF
chmod +x bin/jscpd
cp .claude/kit.conf kit.conf.orig
cat >>.claude/kit.conf <<EOF
jscpd="'$project/bin/jscpd' . --baseline-from-ref \"\\\$KIT_BASE\""
KIT_DUPLICATES="\$jscpd --fail-on-new-clones 0"
KIT_DUPLICATES_RELATED="\$jscpd --changed --fail-on-new-clones 0"
KIT_SIMILAR="\$jscpd --similarity"
EOF
expect_code 0 "duplicates runs its command" .claude/bin/check duplicates
expect_out "jscpd base=main args=. --baseline-from-ref main --fail-on-new-clones 0" "KIT_BASE defaults to main and reaches the command"
KIT_BASE=origin/dev expect_code 0 "KIT_BASE is passed through" .claude/bin/check duplicates
expect_out "base=origin/dev" "the given base is used"
expect_code 0 "duplicates-related gets the files" .claude/bin/check duplicates-related src/a.ts
expect_out "--changed --fail-on-new-clones 0 src/a.ts" "the edited file is appended"
expect_code 0 "similar runs its command" .claude/bin/check similar
expect_out "--similarity" "the similarity flag is passed"
touch jscpd.fail
JSCPD_FAIL=$project/jscpd.fail expect_code 1 "a new clone fails duplicates" .claude/bin/check duplicates
expect_out "new clones" "the clone count is shown"
rm jscpd.fail
mv kit.conf.orig .claude/kit.conf
expect_code 3 "duplicates without a command is not configured" .claude/bin/check duplicates

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
