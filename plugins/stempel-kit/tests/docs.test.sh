#!/bin/sh
# The README fits on two screens and says how to start (CORE-AC26, CORE-AC27); SPEC-v1.1.md says it is historical
# (CORE-AC28); the eight features in review on 07.11.2026 show done in specs/README.md once a person set them
# (CORE-AC29, checked with --release; a note otherwise, because only a person sets done).
# Run: sh plugins/stempel-kit/tests/docs.test.sh [--release]
set -u

root=$(CDPATH='' cd -- "$(dirname -- "$0")/../../.." && pwd)
failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }

readme=$root/README.md
n=$(wc -l <"$readme" | tr -d ' ')
[ "$n" -le 100 ] && ok || fail "CORE-AC26: README.md has $n lines, at most 100"
grep -q 'install.sh [^ ]* --adapter' "$readme" && grep -q '/plugin install stempel-kit@stempel-kit' "$readme" && ok ||
  fail "CORE-AC27: the README holds the install command (install.sh <project> --adapter <adapter>, /plugin install stempel-kit)"
for cmd in /spec-feature /plan-feature /ship-feature; do
  grep -q "^$cmd " "$readme" && ok || fail "CORE-AC27: the README shows $cmd as a command of the first feature"
done
for d in "$root"/plugins/stempel-kit-*/; do
  name=$(basename "$d")
  grep -Eq "^\| \`$name\` \|" "$readme" && ok || fail "CORE-AC27: the README's extension table has no row for $name"
done
rows=$(grep -Ec '^\| `stempel-kit-[a-z]+` \|' "$readme")
exts=$(ls -d "$root"/plugins/stempel-kit-*/ | wc -l | tr -d ' ')
[ "$rows" -eq "$exts" ] && ok || fail "CORE-AC27: the extension table has $rows rows for $exts extensions"
for doc in docs/workflow.md docs/hooks.md; do
  [ -f "$root/$doc" ] && grep -q "$doc" "$readme" && ok || fail "the README links $doc and it exists"
done
! grep -q '](\./plugins/' "$root/docs/workflow.md" "$root/docs/hooks.md" && ok || fail "docs/ links point one folder up (../plugins/), not ./plugins/"

first=$(head -n 1 "$root/plugins/stempel-kit/docs/SPEC-v1.1.md")
case $first in *[Hh]istorical*kit-core-split*) ok ;; *) fail "CORE-AC28: SPEC-v1.1.md line 1 says historical and names specs/kit-core-split.md: $first" ;; esac

# CORE-AC29: the eight rows named in specs/kit-core-split.md ("in review on 07.11.2026").
open=""
for spec in group-sessions plan-lint fix-bug kit-steering e2e-map stacked-groups stack-stage risk-gates cost-visibility; do
  status=$(grep -F "\`$spec.md\`" "$root/specs/README.md" | awk -F '|' '{ gsub(/[[:space:]`]/, "", $4); print $4 }' | head -n 1)
  [ "$status" = "done" ] || open="$open $spec($status)"
done
if [ "${1:-}" = --release ]; then
  [ -z "$open" ] && ok || fail "CORE-AC29: rows not done in specs/README.md:$open"
elif [ -n "$open" ]; then
  echo "note: CORE-AC29 waits for a person to set done in specs/README.md:$open (checked with --release)"
fi

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
