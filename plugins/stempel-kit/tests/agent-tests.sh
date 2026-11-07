#!/bin/sh
# The tests that spend tokens (tests/*/run.sh of the core and the extensions), one after another, until the run
# whose summed cost passes KIT_TEST_BUDGET_USD (default 10); the runs after it are skipped and named (CORE-AC24,
# .github/workflows/agent-tests.yml). Each runner writes its Claude transcript to KIT_TEST_TRANSCRIPT; the cost is
# the sum of its result lines' total_cost_usd. Exit 1 when a run failed or runs were skipped.
# Usage: sh plugins/stempel-kit/tests/agent-tests.sh [runner...]
set -u

plugins=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
budget=${KIT_TEST_BUDGET_USD:-10}
[ $# -gt 0 ] || set -- "$plugins"/stempel-kit/tests/*/run.sh "$plugins"/stempel-kit-*/tests/*/run.sh
transcripts=$(mktemp -d)
trap 'rm -rf "$transcripts"' EXIT

spent=0 failed=0 n=0
while [ $# -gt 0 ]; do
  runner=$1
  shift
  n=$((n + 1))
  transcript=$transcripts/$n.jsonl
  if KIT_TEST_TRANSCRIPT=$transcript sh "$runner"; then result=pass; else result=fail; failed=1; fi
  cost=$(grep '"type":"result"' "$transcript" 2>/dev/null |
    awk '{ if (match($0, /"total_cost_usd":[0-9.eE+-]+/)) total += substr($0, RSTART + 17, RLENGTH - 17) } END { printf "%.4f", total }')
  spent=$(awk -v a="$spent" -v b="$cost" 'BEGIN { printf "%.4f", a + b }')
  printf '%s: %s, %s USD (%s of %s USD spent)\n' "${runner#"$plugins"/}" "$result" "$cost" "$spent" "$budget"
  if [ $# -gt 0 ] && awk -v s="$spent" -v b="$budget" 'BEGIN { exit !(s >= b) }'; then
    echo "agent-tests: the budget of $budget USD is spent; skipped: $(printf '%s ' "$@" | sed "s#$plugins/##g")"
    exit 1
  fi
done
exit "$failed"
