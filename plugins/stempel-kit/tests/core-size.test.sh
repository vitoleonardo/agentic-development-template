#!/bin/sh
# The core stays small (specs/kit-core-split.md): CORE-AC4 at most 1200 lines of shell in bin/ and hooks/,
# CORE-AC5 at most 10 variables in kit.conf, CORE-AC6 to CORE-AC8 exactly these files in bin/, hooks/ and skills/.
# Run: sh plugins/stempel-kit/tests/core-size.test.sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
core=$here/kit/.claude
failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }

n=$(grep -c '^KIT_' "$core/kit.conf")
[ "$n" -le 10 ] && ok || fail "CORE-AC5: the core kit.conf has $n variables, at most 10: $(grep '^KIT_' "$core/kit.conf" | cut -d= -f1 | tr '\n' ' ')"

# listing <dir>: the names in a folder, sorted, on one line.
listing() { (cd "$1" && ls -A | sort | tr '\n' ' '); }
got=$(listing "$core/bin")
[ "$got" = "check conf.sh criteria.sh features.sh gate json.sh plan-lint spec-lint structure " ] && ok || fail "CORE-AC6: bin/ holds $got"
got=$(listing "$core/hooks")
[ "$got" = "check-edits guard hooks.json lib.sh record-edit " ] && ok || fail "CORE-AC7: hooks/ holds $got"
got=$(listing "$core/skills")
[ "$got" = "fix-bug plan-feature pr-description review-diff ship-feature spec-feature write-tests " ] && ok || fail "CORE-AC8: skills/ holds $got"

# The core shell: every file in bin/ and hooks/ that is not JSON.
set --
for f in "$core"/bin/* "$core"/hooks/*; do
  case $f in *.json) ;; *) set -- "$@" "$f" ;; esac
done
lines=$(cat "$@" | wc -l | tr -d ' ')
largest=$(wc -l "$@" | sort -rn | sed -n '2,6p' | awk '{ n = split($2, p, "/"); printf "%s/%s %s, ", p[n - 1], p[n], $1 }')
[ "$lines" -le 1200 ] && ok || fail "CORE-AC4: the core shell has $lines lines, at most 1200; largest: $largest"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
