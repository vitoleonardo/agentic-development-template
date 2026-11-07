#!/bin/sh
# The core stays small (specs/kit-core-split.md): CORE-AC5 the core kit.conf holds at most 10 variables.
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

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
