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
expect "full: core rules installed" test -f "$full/.claude/rules/output.md" -a -f "$full/.claude/rules/git.md"
expect "full: structure map installed" grep -q '`src/features/<domain>/`' "$full/.claude/rules/structure.md"
expect "full: structure gate installed" test -x "$full/.claude/bin/structure"
expect "full: adapter and preset installed" test -f "$full/.claude/rules/typescript.md" -a -f "$full/.claude/rules/nextjs.md"
expect "full: verify skill, evidence script and evidence workflow installed" test -f "$full/.claude/skills/verify-feature/SKILL.md" -a -x "$full/.claude/bin/evidence" -a -f "$full/.github/workflows/evidence.yml"
expect "full: leadtime, route and usage installed" test -x "$full/.claude/bin/leadtime" -a -x "$full/.claude/bin/route" -a -x "$full/.claude/bin/usage" -a -x "$full/.claude/hooks/usage"
expect "full: run records and /improve-kit installed" test -x "$full/.claude/bin/runs" -a -f "$full/.claude/skills/improve-kit/SKILL.md"
expect "full: adapter helpers and the onboarding tools installed" test -f "$full/.claude/bin/coverage-files.mjs" -a -x "$full/.claude/bin/baseline" -a -x "$full/.claude/bin/onboard-apply" -a -f "$full/.claude/skills/onboard/SKILL.md"
python=$(mktemp -d)
"$here/install.sh" "$python" --adapter python >/dev/null || echo "FAIL: python install exited $?"
expect "python: adapter config, helpers and rule installed" test -x "$python/.claude/bin/pytest-related" -a -f "$python/.claude/bin/coverage-files.py" -a -f "$python/.claude/rules/python.md"
expect "python: the Python config replaced the core one" grep -q 'uv run pytest' "$python/.claude/kit.conf"
expect "python: the Python structure map replaced the core one" grep -q '`src/<package>/<domain>/`' "$python/.claude/rules/structure.md"
rm -rf "$python"

expect "plugin: no hooks, skills or agents" test ! -e "$plugin/.claude/hooks" -a ! -e "$plugin/.claude/skills" -a ! -e "$plugin/.claude/agents"
expect "plugin: project files installed" test -x "$plugin/.claude/bin/check" -a -f "$plugin/CLAUDE.md" -a -f "$plugin/specs/README.md" -a -f "$plugin/.claude/kit.conf"
expect "plugin: settings.json has no hooks" sh -c "! grep -q '\"hooks\"' '$plugin/.claude/settings.json'"
expect "plugin: settings.json keeps the deny rules" grep -q '"deny"' "$plugin/.claude/settings.json"
read_denies=$(sed -n 's/^ *"Read(\(.*\))",*$/\1/p' "$full/.claude/settings.json")
env_example_readable() {
  name=.env.example
  printf '%s\n' "$read_denies" | while IFS= read -r pattern; do
    # shellcheck disable=SC2254 # the deny rule is a glob
    case $name in $pattern) exit 1 ;; esac
  done
}
expect "settings.json: no ! exception in Read denies, because the sandbox ignores them" sh -c "! printf '%s\n' \"\$1\" | grep -q '^!'" _ "$read_denies"
expect "settings.json: no Read deny matches .env.example, so git works inside the sandbox" env_example_readable
expect "settings.json: .env and .env.local are denied" sh -c "printf '%s\n' \"\$1\" | grep -qx .env && printf '%s\n' \"\$1\" | grep -qx .env.local" _ "$read_denies"
if command -v node >/dev/null 2>&1; then
  expect "plugin: settings.json is valid JSON" node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))" "$plugin/.claude/settings.json"
fi

# A second run keeps existing files.
echo "custom" >"$full/CLAUDE.md"
out=$("$here/install.sh" "$full" 2>&1)
expect "rerun: existing files are kept" grep -qx custom "$full/CLAUDE.md"
listed() { printf '%s\n' "$out" | grep -qx '  CLAUDE.md'; }
expect "rerun: kept files are listed" listed

expect "manifest: saves the install options" grep -qx "options$(printf '\t')--adapter typescript --preset nextjs" "$full/.claude/kit.manifest"
expect "manifest: lists the installed files" grep -q "$(printf '\t').claude/hooks/guard\$" "$full/.claude/kit.manifest"

# Updating against a newer kit: a copy of the kit with one unchanged and one locally changed file edited.
newer=$(mktemp -d)
cp -R "$here/." "$newer"
echo "# newer kit" >>"$newer/kit/.claude/rules/git.md"
echo "# newer kit" >>"$newer/kit/CLAUDE.md"
echo "# newer kit" >>"$newer/adapters/typescript/.claude/rules/typescript.md"
echo "custom" >"$full/.claude/rules/security.md"
before_security=$(cat "$full/.claude/rules/security.md")
out=$("$newer/install.sh" "$full" --update 2>&1)
expect "update: an unchanged kit file is replaced" grep -qx '# newer kit' "$full/.claude/rules/git.md"
expect "update: the saved adapter is used" grep -qx '# newer kit' "$full/.claude/rules/typescript.md"
expect "update: a locally changed file is kept" grep -qx custom "$full/CLAUDE.md"
expect "update: the kit's version of a changed file is staged" grep -qx '# newer kit' "$full/.work/kit-update/CLAUDE.md"
expect "update: the staged file is listed with a diff command" sh -c "printf '%s\n' \"\$1\" | grep -qxF '  diff .work/kit-update/CLAUDE.md CLAUDE.md'" _ "$out"
expect "update: a changed file the kit did not change is kept and not staged" test "$(cat "$full/.claude/rules/security.md")" = "$before_security" -a ! -e "$full/.work/kit-update/.claude/rules/security.md"
expect "update: executables stay executable" test -x "$full/.claude/hooks/guard"
"$newer/install.sh" "$full" --update >/dev/null 2>&1
expect "update: a second update stages nothing" test ! -e "$full/.work/kit-update"
expect "update: --force and --update together are refused" sh -c "! '$here/install.sh' '$full' --force --update"
rm -rf "$newer"

older=$(mktemp -d)
cp -R "$here/." "$older"
awk '
  { print }
  /^    "ask": \[$/ { print "      \"Bash(npm install *)\","; print "      \"Bash(git push *)\"," }
' "$here/kit/.claude/settings.json" | awk '
  $0 == "      \"Edit(.claude/rules/**)\"" { print $0 ","; print "      \"Edit(terraform/**)\""; next }
  { print }
' >"$older/kit/.claude/settings.json"
retire=$(mktemp -d)
"$older/install.sh" "$retire" >/dev/null
awk '{ print } $0 == "      \"Bash(gh pr merge *)\"," { print "      \"Bash(make deploy *)\"," }' "$retire/.claude/settings.json" >"$retire/settings.tmp"
mv "$retire/settings.tmp" "$retire/.claude/settings.json"
out=$("$here/install.sh" "$retire" --update 2>&1)
expect "update: the retired ask rules are removed from a changed settings.json" sh -c "! grep -qF -e '\"Bash(npm install *)\"' -e '\"Bash(git push *)\"' -e '\"Edit(terraform/**)\"' '$retire/.claude/settings.json'"
expect "update: local rules in settings.json stay" grep -qF '"Bash(make deploy *)",' "$retire/.claude/settings.json"
expect "update: the removed rules are listed" sh -c "printf '%s\n' \"\$1\" | grep -qF '\"Bash(git push *)\"'" _ "$out"
if command -v node >/dev/null 2>&1; then
  expect "update: settings.json stays valid JSON after removing the last ask entry" node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))" "$retire/.claude/settings.json"
fi
rm -rf "$older" "$retire"

# A project installed before the manifest existed: nothing is overwritten, differing files are staged.
legacy=$(mktemp -d)
"$here/install.sh" "$legacy" >/dev/null
rm "$legacy/.claude/kit.manifest"
echo "custom" >>"$legacy/.claude/settings.json"
"$here/install.sh" "$legacy" --update >/dev/null 2>&1
expect "legacy update: a changed file is kept" sh -c "tail -n 1 '$legacy/.claude/settings.json' | grep -qx custom"
expect "legacy update: the kit's version is staged" test -f "$legacy/.work/kit-update/.claude/settings.json"
expect "legacy update: a manifest is written" test -f "$legacy/.claude/kit.manifest"
rm -rf "$legacy"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
