#!/bin/sh
# Tests for .claude/bin/check. Run: sh plugins/stempel-kit/tests/check.test.sh
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

# Without stempel-kit-onboard there is no .claude/bin/baseline: --against-baseline runs the plain check.
expect_code 1 "--against-baseline without the onboard extension runs the plain check" .claude/bin/check --against-baseline lint
expect_out "== lint in packages/py ==" "the plain check ran in every package"

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

# --- duplicates-new.mjs: a new clone inside a clone the base already has is legacy -----------------------

# The fake jscpd writes the clones of $FAKE_HEAD (a run with --baseline-from-ref) or $FAKE_BASE (the base scan)
# as a jscpd 5 JSON report into --output, and logs where it ran.
cat >bin/jscpd-json <<'EOF'
#!/bin/sh
all="$*"
out="" mode=base
while [ $# -gt 0 ]; do
  case $1 in --output) out=$2; shift ;; --baseline-from-ref) mode=head; shift ;; esac
  shift
done
echo "$mode $PWD $all" >>"$JSCPD_LOG"
mkdir -p "$out"
if [ "$mode" = head ]; then cp "$FAKE_HEAD" "$out/jscpd-report.json"; else cp "$FAKE_BASE" "$out/jscpd-report.json"; fi
EOF
chmod +x bin/jscpd-json
# clone <first> <second> <fragment> <isNew>: one jscpd 5 duplicate.
clone() {
  printf '{"firstFile": {"name": "%s", "start": 1, "end": 9}, "secondFile": {"name": "%s", "start": 3, "end": 11}, "fragment": "%s", "isNew": %s, "tokens": 60}' "$1" "$2" "$3" "$4"
}
report() { printf '{"duplicates": [%s], "statistics": {}}\n' "$1"; }
dupnew() { KIT_BASE=main JSCPD_LOG=$project/jscpd.log FAKE_HEAD=$project/head.json FAKE_BASE=$project/base.json expect_code "$1" "$2" node "$here/adapters/typescript/.claude/bin/duplicates-new.mjs" "$project/bin/jscpd-json" . --format typescript; }
: >jscpd.log
report "$(clone src/x.ts src/y.ts 'let a = 1;\n  let b = 2;' false)" >head.json
report "" >base.json
dupnew 0 "only legacy clones pass without a base scan"
[ "$(grep -c '^base' jscpd.log)" -eq 0 ] && ok || fail "no base scan without new clones: $(cat jscpd.log)"
report "$(clone src/x.ts src/y.ts 'let a = 1;\n  let b = 2;' true)" >head.json
report "$(clone src/y.ts src/x.ts 'const z = 0;\n  let a = 1;   let b = 2;\n  let c = 3;' false)" >base.json
dupnew 0 "a new clone inside a clone the same file pair has on the base is legacy"
expect_out "inside a clone the base already has: src/x.ts:1-9 ~ src/y.ts:3-11" "the legacy clone is named"
grep -q "^base .*/" jscpd.log && ok || fail "the base is scanned in a worktree: $(cat jscpd.log)"
[ -z "$(git worktree list | sed 1d)" ] && ok || fail "the base worktree is removed: $(git worktree list)"
report "$(clone src/x.ts src/w.ts 'let a = 1;\n  let b = 2;' true)" >head.json
dupnew 1 "a clone in a file pair the base does not have is new"
expect_out "1 new clones" "the new clone is counted"
expect_out "src/x.ts:1-9 ~ src/w.ts:3-11" "the new clone is named"
report "$(clone src/x.ts src/y.ts 'const z = 0;\n  let a = 1;   let b = 2;\n  let c = 3;\n  let d = 4;' true)" >head.json
dupnew 1 "a clone that grew past the base's clone is new"

# A clone inside the constructor parameter lists of both files is dependency injection; one reaching past them is new.
printf 'export class A {\n  constructor(\n    private readonly users: UsersRepo,\n    @Inject(MAIL) private readonly mail: Mail,\n  ) {}\n  run() { return 1; }\n}\n' >src/a.ts
cp src/a.ts src/b.ts
part() { printf '{"name": "%s", "start": %s, "end": %s}' "$1" "$2" "$3"; }
diclone() { printf '{"firstFile": %s, "secondFile": %s, "fragment": "x", "isNew": true, "tokens": 60}' "$(part src/a.ts "$1" "$2")" "$(part src/b.ts "$1" "$2")"; }
: >jscpd.log
report "$(diclone 2 5)" >head.json
report "" >base.json
dupnew 0 "a clone inside constructor parameter lists in both files is dependency injection"
expect_out "dependency injection, inside constructor parameter lists: src/a.ts:2-5 ~ src/b.ts:2-5" "the injection clone is named"
expect_out "0 new clones (0 more inside clones the base already has, 1 inside constructor parameter lists)" "the injection clone is counted apart"
[ "$(grep -c '^base' jscpd.log)" -eq 0 ] && ok || fail "no base scan when only injection clones are new: $(cat jscpd.log)"
report "$(diclone 2 6)" >head.json
dupnew 1 "a clone that reaches past the constructor is new"

# The edit hook's run: --changed and the edited files go to the branch scan, the base is scanned whole.
: >jscpd.log
report "$(clone src/x.ts src/w.ts 'let a = 1;' true)" >head.json
KIT_BASE=main JSCPD_LOG=$project/jscpd.log FAKE_HEAD=$project/head.json FAKE_BASE=$project/base.json expect_code 1 "the related run fails on a new clone" node "$here/adapters/typescript/.claude/bin/duplicates-new.mjs" "$project/bin/jscpd-json" . --format typescript --changed src/a.ts
grep -q '^head .* --changed src/a.ts' jscpd.log && ok || fail "the branch scan gets --changed and the edited file: $(cat jscpd.log)"
grep '^base' jscpd.log | grep -q -e '--changed' -e 'src/a.ts' && fail "the base scan is whole: $(cat jscpd.log)" || ok

# CORE-AC30, CORE-AC32: a kit.conf section of an extension whose script is missing gets a warning, not a failure.
printf '\n# extension: foo bin/foo\nKIT_FOO=""\n' >>.claude/kit.conf
expect_code 0 "CORE-AC30: check extensions warns and exits 0" .claude/bin/check extensions
expect_out "extension foo" "CORE-AC30: the warning names the extension"
expect_out "bin/foo" "CORE-AC30: the warning names the missing script"
mkdir -p .claude/bin && printf '#!/bin/sh\n' >.claude/bin/foo && chmod +x .claude/bin/foo
expect_code 0 "check extensions is quiet when the script is there" .claude/bin/check extensions
case $out in *"extension foo"*) fail "check extensions still warns with the script present: $out" ;; *) ok ;; esac
rm .claude/bin/foo
expect_code 0 "CORE-AC32: after an uninstall the warning names the extension again" .claude/bin/check extensions
expect_out "extension foo" "CORE-AC32: the warning names the extension"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
