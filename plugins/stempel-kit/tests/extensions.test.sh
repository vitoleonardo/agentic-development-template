#!/bin/sh
# Each extension holds its own files and the core holds none of them (CORE-AC13 to CORE-AC18).
# Run: sh plugins/stempel-kit/tests/extensions.test.sh
set -u

plugins=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
core=$plugins/stempel-kit/kit/.claude
failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }

# owns <extension> <path under plugin/ or tests/>...: the extension holds each path, the core holds none.
owns() {
  ext=$plugins/stempel-kit-$1
  shift
  for f in "$@"; do
    [ -e "$ext/$f" ] && ok || fail "stempel-kit-${ext##*-} has no $f"
    case $f in plugin/hooks/hooks.json) ;; plugin/*) [ ! -e "$core/${f#plugin/}" ] && ok || fail "the core still holds ${f#plugin/}" ;; esac
  done
  [ -f "$ext/plugin/kit.conf.part" ] && ok || fail "stempel-kit-${ext##*-} has no kit.conf.part"
  [ -n "$(ls "$ext/plugin/bin" 2>/dev/null)" ] && ok || fail "stempel-kit-${ext##*-} has no script in plugin/bin"
  [ -n "$(ls "$ext"/tests/*.test.sh 2>/dev/null)" ] && ok || fail "stempel-kit-${ext##*-} has no tests/*.test.sh"
}

owns evidence plugin/bin/evidence plugin/skills/verify-feature/SKILL.md tests/evidence.test.sh
owns autopilot plugin/bin/autopilot plugin/bin/stack plugin/bin/status plugin/hooks/steer plugin/hooks/summary plugin/hooks/hooks.json tests/autopilot.test.sh tests/stack.test.sh tests/status.test.sh tests/steer.test.sh
owns routing plugin/bin/route plugin/bin/usage plugin/hooks/usage plugin/hooks/hooks.json tests/usage.test.sh
owns onboard plugin/bin/baseline plugin/bin/onboard-apply plugin/skills/onboard/SKILL.md tests/baseline.test.sh

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
