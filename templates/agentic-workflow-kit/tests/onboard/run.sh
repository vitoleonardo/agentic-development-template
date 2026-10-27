#!/bin/sh
# Headless /onboard run on a fixture repo (ONBOARD-AC1, AC2, AC3, AC5). Needs Claude Code, network, pnpm and uv,
# and spends tokens, so it is not part of CI. Run: sh templates/agentic-workflow-kit/tests/onboard/run.sh [fixture] [model]
#   fixture  pnpm-monorepo (default), python-pkg, or demo-app (ONBOARD-AC4: same resolved kit.conf as install.sh)
#   model    default sonnet
# The answers a user would give are scripted. bypassPermissions stands in for the user approving each command
# (the folder is untrusted, so allow rules do not apply); the guard hook still runs. The run checks afterwards
# that the session itself wrote nothing outside .work/ before onboard-apply.
# shellcheck disable=SC2034 # $code is read inside the conditions that check() evaluates
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
fixture=${1:-pnpm-monorepo}
model=${2:-sonnet}
work=$(mktemp -d)
repo=$work/$fixture
log=$work/transcript.jsonl
echo "Working in $work (kept for inspection)"

src=$here/tests/onboard/$fixture
[ "$fixture" = demo-app ] && src=$here/examples/demo-app
cp -R "$src" "$repo"
rm -rf "$repo/.venv" "$repo/ai-service/.venv" "$repo/node_modules"
"$here/install.sh" "$repo" >/dev/null
cd "$repo" || exit 1
[ -f pnpm-lock.yaml ] && pnpm install --frozen-lockfile >/dev/null 2>&1
[ -f package-lock.json ] && npm ci >/dev/null 2>&1
git init -q -b main
git add -A
git -c user.name=t -c user.email=t@example.invalid commit -qm "fixture with kit project files"

session=$(python3 -I -c 'import uuid; print(uuid.uuid4())')
turn() {
  if [ -z "${started:-}" ]; then
    set -- --session-id "$session" "$@"
    started=1
  else
    set -- --resume "$session" "$@"
  fi
  claude -p --model "$model" --permission-mode bypassPermissions --settings .claude/settings.json \
    --output-format stream-json --verbose "$@" >>"$log" 2>&1
  python3 -I -c 'import json,sys
for line in open(sys.argv[1]):
    try: d = json.loads(line)
    except ValueError: continue
    if d.get("type") == "result": last = d.get("result", "")
print((last or "")[-1500:])' "$log"
  echo "-----"
}

protect=packages/ee
[ "$fixture" = pnpm-monorepo ] || protect=none
turn "/onboard"
turn "The kit's clone is at $here. Protected paths: $protect. Continue with the baseline."
turn "Approved. Continue with the proposal. Do not stage CI files."

failed=0
# check <description> <shell condition>; conditions read $code, $changed and $outside set below.
check() { if eval "$2"; then echo "ok:   $1"; else echo "FAIL: $1"; failed=$((failed + 1)); fi; }

# Before apply: the session wrote only under .work/ (ONBOARD-AC1).
changed=$(git status --porcelain --untracked-files=all | awk '{ print $2 }' | grep -v '^\.work/')
check "the session wrote nothing outside .work/ before onboard-apply" '[ -z "$changed" ]'
[ -n "$changed" ] && printf '  %s\n' $changed
check "scan, baseline and proposal are written" '[ -f .work/onboard/scan.md ] && [ -f .work/onboard/baseline.tsv ] && [ -f .work/onboard/proposal.md ]'

.claude/bin/onboard-apply >"$work/apply.log" 2>&1
code=$?
check "onboard-apply succeeds" '[ "$code" -eq 0 ]'
turn "I ran .claude/bin/onboard-apply; its output is in $work/apply.log. Prove the configuration and summarize."

allowed='^(\.claude/|[^/]+/\.claude/kit\.conf$|CLAUDE\.md$|specs/README\.md$|\.work/)'
outside=$(git status --porcelain --untracked-files=all | awk '{ print $2 }' | grep -Ev "$allowed")
check "no file outside the allowed list changed (ONBOARD-AC1)" '[ -z "$outside" ]'
[ -n "$outside" ] && printf '  %s\n' $outside
check "a baseline is committed-ready" '[ -s .claude/baseline.tsv ]'
KIT_BASE=main .claude/bin/check --against-baseline test >"$work/gate.log" 2>&1
code=$?
check "the gate passes on main with its legacy failure (ONBOARD-AC2)" '[ "$code" -eq 0 ]'
if [ "$fixture" = pnpm-monorepo ]; then
  check "the legacy failure is recorded" 'grep -q "groups thousands	fail" .claude/baseline.tsv'
  check "ai-service has its own config" '[ -f ai-service/.claude/kit.conf ]'
  check "AGENTS.md is unchanged (ONBOARD-AC5)" 'git diff --quiet -- AGENTS.md'
  check "CLAUDE.md imports AGENTS.md (ONBOARD-AC5)" 'grep -q "^@AGENTS.md" CLAUDE.md'
  check "packages/ee is protected in kit.conf" 'grep -q "KIT_PROTECTED_PATHS=.*packages/ee" .claude/kit.conf'
  check "the sandbox denies reading packages/ee (ONBOARD-AC3)" 'grep -q "denyRead" .claude/settings.json && grep -q "packages/ee" .claude/settings.json'
  check "gh runs outside the sandbox so it can verify TLS on macOS" 'jq -e ".sandbox.excludedCommands | index(\"gh *\")" .claude/settings.json >/dev/null'
  check "the protected file never reached the model (ONBOARD-AC3)" '! grep -q "ee-canary-7f3a" "$log"'
fi

if [ "$fixture" = demo-app ]; then
  # Resolved values, not text: the adapter's file holds shell conditionals.
  resolved() { (cd "$1" && env -i PATH="$PATH" sh -c '. ./.claude/kit.conf; set' | grep '^KIT_' | grep -v '^KIT_PROTECTED_PATHS=' | sort); }
  reference=$work/reference
  cp -R "$src" "$reference" && "$here/install.sh" "$reference" --adapter typescript >/dev/null
  resolved "$repo" >"$work/onboard.vars"
  resolved "$reference" >"$work/install.vars"
  check "kit.conf resolves to the same values as install.sh --adapter typescript (ONBOARD-AC4)" 'diff "$work/install.vars" "$work/onboard.vars" >"$work/vars.diff"'
  sed 's/^/  /' "$work/vars.diff"
fi

echo "$failed failed. Transcript: $log"
[ "$failed" -eq 0 ]
