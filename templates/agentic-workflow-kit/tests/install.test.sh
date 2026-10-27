#!/bin/sh
# Tests for install.sh. Run: sh templates/agentic-workflow-kit/tests/install.test.sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
full=$(mktemp -d)
plugin=$(mktemp -d)
trap 'rm -rf "$full" "$plugin"' EXIT

passed=0
failed=0

# expect <description> <command...>: the command must succeed.
expect() {
  description=$1
  shift
  if "$@" >/dev/null 2>&1; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL: $description"
  fi
}

"$here/install.sh" "$full" --adapter typescript --preset nextjs >/dev/null || echo "FAIL: full install exited $?"
"$here/install.sh" "$plugin" --adapter typescript --plugin >/dev/null || echo "FAIL: plugin install exited $?"

expect "full: hooks, skills and agents installed" test -x "$full/.claude/hooks/guard" -a -f "$full/.claude/skills/ship-feature/SKILL.md" -a -f "$full/.claude/agents/reviewer.md"
expect "full: settings.json registers the hooks" grep -q '"PreToolUse"' "$full/.claude/settings.json"
expect "full: skills use plain agent names" grep -qx 'agent: reviewer' "$full/.claude/skills/review-diff/SKILL.md"
expect "full: no plugin-scoped agent names left" sh -c "! grep -rq 'agent: agentic-workflow-kit:' '$full/.claude/skills'"
expect "full: plugin files not installed" test ! -e "$full/.claude/.claude-plugin" -a ! -e "$full/.claude/hooks/hooks.json"
expect "full: adapter and preset installed" test -f "$full/.claude/rules/typescript.md" -a -f "$full/.claude/rules/nextjs.md"
expect "full: verify skill, evidence script and evidence workflow installed" test -f "$full/.claude/skills/verify-feature/SKILL.md" -a -x "$full/.claude/bin/evidence" -a -f "$full/.github/workflows/evidence.yml"
expect "full: leadtime, route and usage installed" test -x "$full/.claude/bin/leadtime" -a -x "$full/.claude/bin/route" -a -x "$full/.claude/bin/usage" -a -x "$full/.claude/hooks/usage"
expect "full: adapter helpers and the onboarding tools installed" test -f "$full/.claude/bin/coverage-files.mjs" -a -x "$full/.claude/bin/baseline" -a -x "$full/.claude/bin/onboard-apply" -a -f "$full/.claude/skills/onboard/SKILL.md"
python=$(mktemp -d)
"$here/install.sh" "$python" --adapter python >/dev/null || echo "FAIL: python install exited $?"
expect "python: adapter config, helpers and rule installed" test -x "$python/.claude/bin/pytest-related" -a -f "$python/.claude/bin/coverage-files.py" -a -f "$python/.claude/rules/python.md"
expect "python: the Python config replaced the core one" grep -q 'uv run pytest' "$python/.claude/kit.conf"
rm -rf "$python"

expect "plugin: no hooks, skills or agents" test ! -e "$plugin/.claude/hooks" -a ! -e "$plugin/.claude/skills" -a ! -e "$plugin/.claude/agents"
expect "plugin: project files installed" test -x "$plugin/.claude/bin/check" -a -f "$plugin/CLAUDE.md" -a -f "$plugin/specs/README.md" -a -f "$plugin/.claude/kit.conf"
expect "plugin: settings.json has no hooks" sh -c "! grep -q '\"hooks\"' '$plugin/.claude/settings.json'"
expect "plugin: settings.json keeps the deny rules" grep -q '"deny"' "$plugin/.claude/settings.json"
if command -v node >/dev/null 2>&1; then
  expect "plugin: settings.json is valid JSON" node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))" "$plugin/.claude/settings.json"
fi

# A second run keeps existing files.
echo "custom" >"$full/CLAUDE.md"
out=$("$here/install.sh" "$full" 2>&1)
expect "rerun: existing files are kept" grep -qx custom "$full/CLAUDE.md"
listed() { printf '%s\n' "$out" | grep -qx '  CLAUDE.md'; }
expect "rerun: kept files are listed" listed

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
