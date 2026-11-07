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

agents=$root/.github/workflows/agent-tests.yml
grep -q '^  schedule:' "$agents" && grep -Eq '^ +- cron: ' "$agents" && ok || fail "CORE-AC24: agent-tests.yml has a weekly schedule"
grep -q '^  workflow_dispatch:' "$agents" && ok || fail "CORE-AC24: agent-tests.yml runs on workflow_dispatch"
! grep -Eq '^  (push|pull_request):' "$agents" && ok || fail "CORE-AC24: agent-tests.yml never runs on a push or a pull request"
grep -q 'sh plugins/stempel-kit/tests/agent-tests.sh' "$agents" && grep -q 'KIT_TEST_BUDGET_USD' "$agents" && ok ||
  fail "CORE-AC24: agent-tests.yml runs tests/agent-tests.sh with KIT_TEST_BUDGET_USD"
for runner in "$root"/plugins/stempel-kit/tests/*/run.sh "$root"/plugins/stempel-kit-*/tests/*/run.sh; do
  grep -q 'KIT_TEST_TRANSCRIPT' "$runner" && ok || fail "CORE-AC24: ${runner#"$root"/} writes its transcript to KIT_TEST_TRANSCRIPT, where agent-tests.sh reads the cost"
done

# agent-tests.sh stops after the run whose summed cost passes the budget and names the runs it skipped.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
for cost in 4 7 1; do
  mkdir -p "$work/t$cost"
  printf '#!/bin/sh\nprintf '"'"'{"type":"result","total_cost_usd":%s}\\n'"'"' >"$KIT_TEST_TRANSCRIPT"\n' "$cost" >"$work/t$cost/run.sh"
done
out=$(KIT_TEST_BUDGET_USD=10 sh "$here/tests/agent-tests.sh" "$work/t4/run.sh" "$work/t7/run.sh" "$work/t1/run.sh" 2>&1)
code=$?
same "$code" 1 "CORE-AC24: a spent budget leaves the run red"
case $out in *"t4/run.sh: pass, 4.0000 USD (4.0000 of 10 USD spent)"*"t7/run.sh: pass, 7.0000 USD (11.0000 of 10 USD spent)"*) ok ;; *) fail "CORE-AC24: the runs before the budget run and report their cost: $out" ;; esac
case $out in *"skipped: $work/t1/run.sh"*) ok ;; *) fail "CORE-AC24: the run after the budget is skipped and named: $out" ;; esac
case $out in *"t1/run.sh: pass"*) fail "CORE-AC24: the run after the budget must not run: $out" ;; *) ok ;; esac
out=$(KIT_TEST_BUDGET_USD=20 sh "$here/tests/agent-tests.sh" "$work/t4/run.sh" "$work/t7/run.sh" "$work/t1/run.sh" 2>&1)
code=$?
same "$code" 0 "CORE-AC24: within the budget every run runs and the exit is 0"
case $out in *"t1/run.sh: pass, 1.0000 USD (12.0000 of 20 USD spent)"*) ok ;; *) fail "CORE-AC24: the last run within the budget runs: $out" ;; esac
printf '#!/bin/sh\nexit 1\n' >"$work/t1/run.sh"
out=$(KIT_TEST_BUDGET_USD=20 sh "$here/tests/agent-tests.sh" "$work/t1/run.sh" 2>&1)
code=$?
case $code:$out in 1:*"t1/run.sh: fail, 0.0000 USD"*) ok ;; *) fail "CORE-AC24: a failed run leaves the exit 1 and reports fail: $code $out" ;; esac
out=$(sh "$here/tests/agent-tests.sh" "$work/t4/run.sh" "$work/t7/run.sh" "$work/t1/run.sh" 2>&1)
case $out in *"of 10 USD spent"*) ok ;; *) fail "CORE-AC24: the budget is 10 USD when KIT_TEST_BUDGET_USD is unset: $out" ;; esac

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
