#!/bin/sh
# CI runs the core's tests always and an extension's tests when its folder changed, never a test that spends
# tokens (CORE-AC23); agent-tests.yml runs those weekly and on request, within KIT_TEST_BUDGET_USD (CORE-AC24).
# Run: sh plugins/stempel-kit/tests/ci.test.sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
root=$(CDPATH='' cd -- "$here/../.." && pwd)
run=$here/tests/run.sh
failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
same() { if [ "$1" = "$2" ]; then ok; else fail "$3: got '$1', wanted '$2'"; fi; }

workflow=$root/.github/workflows/stempel-kit.yml
! grep -Eq '(sh|dash|\./)[^#]*tests/[^/* ]+/run\.sh' "$workflow" && ok || fail "CORE-AC23: stempel-kit.yml runs a tests/*/run.sh, which spends tokens"
grep -q 'sh tests/run.sh --core' "$workflow" && ok || fail "CORE-AC23: stempel-kit.yml runs the core suites with tests/run.sh --core"
grep -q 'sh tests/run.sh --select' "$workflow" && grep -q 'sh tests/run.sh --extension ${{ matrix.name }}' "$workflow" && ok ||
  fail "CORE-AC23: stempel-kit.yml selects the changed extensions with tests/run.sh --select and runs each with --extension"
grep -q '^  pull_request:' "$workflow" && ok || fail "stempel-kit.yml runs on pull requests"

# --select: the extension whose folder changed; all of them when the core or the workflow changed; none otherwise.
all=$(for d in "$root"/plugins/stempel-kit-*/; do d=${d%/}; printf '%s\n' "${d##*/stempel-kit-}"; done)
same "$(printf 'plugins/stempel-kit-risk/plugin/bin/risk\nREADME.md\n' | sh "$run" --select)" "risk" "CORE-AC23: a changed risk path selects risk"
same "$(printf 'plugins/stempel-kit-risk/tests/risk.test.sh\nplugins/stempel-kit-onboard/plugin/kit.conf.part\n' | sh "$run" --select | tr '\n' ' ')" "onboard risk " "CORE-AC23: two changed extensions, in folder order"
same "$(printf 'plugins/stempel-kit/kit/.claude/bin/gate\n' | sh "$run" --select)" "$all" "CORE-AC23: a core change selects every extension"
same "$(printf '.github/workflows/stempel-kit.yml\n' | sh "$run" --select)" "$all" "CORE-AC23: a workflow change selects every extension"
same "$(printf 'README.md\nplugins/repo-check/build\n' | sh "$run" --select)" "" "CORE-AC23: an unrelated change selects no extension"
sh "$run" --extension nope >/dev/null 2>&1; same "$?" 2 "run.sh --extension with an unknown name is a usage error"
sh "$run" --what >/dev/null 2>&1; same "$?" 2 "run.sh with an unknown option is a usage error"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
