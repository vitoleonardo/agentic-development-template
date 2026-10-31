#!/bin/sh
# Tests for .claude/bin/structure. Run: sh plugins/agentic-workflow-kit/tests/structure.test.sh
# Uses the kit's default Map in .claude/rules/structure.md on a scratch git repository.
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
expect_code() {
  want=$1 description=$2
  shift 2
  out=$("$@" 2>&1)
  code=$?
  if [ "$code" -eq "$want" ]; then ok; else fail "$description (exit $code, wanted $want): $out"; fi
}
expect_out() { case $out in *"$1"*) ok ;; *) fail "$2: no '$1' in: $out" ;; esac; }
g() { git -c user.name=t -c user.email=t@example.invalid "$@"; }

printf 'KIT_SOURCE_PATTERNS="*.ts *.tsx"\n' >.claude/kit.conf
mkdir -p src/legacy
printf 'export const old = 1;\n' >src/legacy/old.ts
git init -q -b main
g add -A
g commit -qm base
git checkout -qb feature
s=.claude/bin/structure

# --- homes of the default Map ---------------------------------------------------

for f in src/features/split/round.ts src/lib/money.ts src/app/invoices/page.tsx src/data/user.ts src/components/Button.tsx \
  src/config.ts e2e/login.spec.ts src/features/split/round.test.ts vitest.config.ts scripts/seed-db.ts bin/cli.ts; do
  expect_code 0 "$f is in a home" $s "$f"
done
expect_code 1 "a feature file needs its domain folder" $s src/features/round.ts
expect_code 1 "a file outside every home fails" $s src/helpers.ts
expect_out "src/helpers.ts: no home in the Map" "the message names the file and the Map"
expect_code 1 "a grab-bag file name fails inside a home" $s src/lib/utils.ts
expect_out "'utils' says nothing" "the grab-bag name is named"
expect_code 1 "a grab-bag folder fails inside a home" $s src/features/common/date.ts
expect_code 0 "a file that is not source is not checked" $s README.md docs/notes.md
expect_out "0 new source files" "nothing was checked"
expect_code 1 "an absolute path is checked relative to the root" $s "$project/src/round.ts"
expect_code 0 "the kit's own files are not checked" $s .claude/bin/helper.ts

# --- new files since the merge base ---------------------------------------------

expect_code 0 "existing files outside the Map never block" $s
printf 'export const y = 1;\n' >src/legacy/new.ts
expect_code 1 "an untracked file outside the Map fails" $s
expect_out "src/legacy/new.ts" "the untracked file is named"
g add -A
g commit -qm "add new"
expect_code 1 "a file committed on the branch is still new" $s
mkdir -p src/lib
g mv src/legacy/new.ts src/lib/renamed.ts
g commit -qm "move"
expect_code 0 "moving a file into its home passes" $s
g mv src/legacy/old.ts src/moved.ts
g commit -qm "move old"
expect_code 1 "a file moved out of its home counts as new" $s

# --- Legacy, explicit paths, presets, packages ----------------------------------

sed -i 's/^None\.$/- `src\/legacy\/`/' .claude/rules/structure.md
expect_code 1 "a legacy home takes no new files" $s src/legacy/more.ts
expect_out "legacy home" "the legacy home is named"
sed -i 's#^| Config and environment |#| Shared class names | `src/lib/utils.ts` | shadcn |\n| Config and environment |#' .claude/rules/structure.md
expect_code 0 "a file the Map lists by path may have a grab-bag name" $s src/lib/utils.ts
printf '# Preset\n\n## Map\n\n| Kind | Home | Naming |\n|---|---|---|\n| Proxy | `proxy.ts` | `ignored.ts` |\n' >.claude/rules/preset.md
expect_code 0 "a preset's Map adds homes" $s proxy.ts
expect_code 1 "the Naming column is not a home" $s src/ignored.ts

mkdir -p packages/py/.claude
printf 'KIT_SOURCE_PATTERNS="*.py"\n' >packages/py/.claude/kit.conf
sed -i 's#^| Scripts |#| Package tests | `tests/` | - |\n| Scripts |#' .claude/rules/structure.md
expect_code 0 "a home may be relative to a package" $s packages/py/tests/test_a.py
expect_code 1 "a package file outside the Map fails" $s packages/py/app.py
expect_code 0 "a package's own source patterns decide what is checked" $s packages/py/web.ts
expect_code 0 "the root's source patterns do not cover .py files" $s tool.py

printf '# Structure\n\nNo map yet.\n' >.claude/rules/structure.md
rm .claude/rules/preset.md
expect_code 3 "no Map means not configured" $s src/x.ts

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
