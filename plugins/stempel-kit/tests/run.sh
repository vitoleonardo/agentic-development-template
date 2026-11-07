#!/bin/sh
# Every test of the core and the extensions (CORE-AC25), without the ones that spend tokens (tests/*/run.sh,
# which agent-tests.sh runs).
# Usage: sh plugins/stempel-kit/tests/run.sh                    the core and every extension
#        sh plugins/stempel-kit/tests/run.sh --core             the core's suites
#        sh plugins/stempel-kit/tests/run.sh --extension <name> one extension's suites
#        sh plugins/stempel-kit/tests/run.sh --select           changed paths on stdin; prints the extensions whose
#                                                               tests CI runs, one per line: those whose folder
#                                                               changed, those whose tests or plugin.json name one of
#                                                               them, and all when the core or the workflow changed
# KIT_TEST_SHELL (default sh) runs every suite, for example dash.
set -u

plugins=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
shell=${KIT_TEST_SHELL:-sh}
extensions() { for d in "$plugins"/stempel-kit-*/; do d=${d%/}; printf '%s\n' "${d##*/stempel-kit-}"; done; }
usage() { sed -n '4,9p' "$0" | sed 's/^# //' >&2; exit 2; }

if [ "${1:-}" = --select ]; then
  changed=$(cat)
  if printf '%s\n' "$changed" | grep -Eq '^(plugins/stempel-kit/|\.github/workflows/stempel-kit\.yml$)'; then extensions; exit 0; fi
  selected=$(for e in $(extensions); do printf '%s\n' "$changed" | grep -q "^plugins/stempel-kit-$e/" && echo "$e"; done)
  for e in $(extensions); do
    for c in $selected; do
      [ "$e" != "$c" ] && grep -rqs "stempel-kit-$c" "$plugins/stempel-kit-$e/tests" "$plugins/stempel-kit-$e/plugin/.claude-plugin/plugin.json" &&
        selected="$selected $e" && break
    done
  done
  printf '%s\n' $selected | sort -u | grep .
  exit 0
fi

# shellcheck disable=SC2046 # extension names hold no spaces
case ${1:-} in
  '') set -- core $(extensions) ;;
  --core) set -- core ;;
  --extension) [ -d "$plugins/stempel-kit-${2:-}" ] || { echo "run.sh: no extension stempel-kit-${2:-}" >&2; exit 2; }; set -- "$2" ;;
  *) usage ;;
esac

failed=""
for part in "$@"; do
  if [ "$part" = core ]; then dir=$plugins/stempel-kit; else dir=$plugins/stempel-kit-$part; fi
  for t in "$dir"/tests/*.test.sh; do
    echo "== ${t#"$plugins"/}"
    "$shell" "$t" || failed="$failed ${t#"$plugins"/}"
  done
done
[ -z "$failed" ] || { echo "run.sh: failed:$failed"; exit 1; }
echo "run.sh: every suite passed."
