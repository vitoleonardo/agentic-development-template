#!/bin/sh
# Tests for install.sh. Run: sh plugins/stempel-kit/tests/install.test.sh
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

# CORE-AC1: one kit. The plugin lives at plugins/stempel-kit and no path or name keeps the old suffix.
retired="stempel-kit-""next"
expect "CORE-AC1: the kit lives at plugins/stempel-kit" test "$(basename "$here")" = stempel-kit
expect "CORE-AC1: no file in the kit names $retired" sh -c "! grep -rq -- '$retired' '$here' --exclude-dir=node_modules --exclude-dir=.next"
expect "CORE-AC1: no sibling plugin folder $retired" test ! -e "$here/../$retired"

"$here/install.sh" "$full" --adapter typescript --preset nextjs >/dev/null || echo "FAIL: full install exited $?"
"$here/install.sh" "$plugin" --adapter typescript --plugin >/dev/null || echo "FAIL: plugin install exited $?"

expect "full: hooks, skills and agents installed" test -x "$full/.claude/hooks/guard" -a -f "$full/.claude/skills/ship-feature/SKILL.md" -a -f "$full/.claude/skills/fix-bug/SKILL.md" -a -f "$full/.claude/agents/reviewer.md"
expect "full: settings.json registers the hooks" grep -q '"PreToolUse"' "$full/.claude/settings.json"
expect "full: skills use plain agent names" grep -qx 'agent: reviewer' "$full/.claude/skills/review-diff/SKILL.md"
expect "full: no plugin-scoped agent names left" sh -c "! grep -rq 'agent: stempel-kit:' '$full/.claude/skills'"
expect "full: plugin files not installed" test ! -e "$full/.claude/.claude-plugin" -a ! -e "$full/.claude/hooks/hooks.json"
expect "full: core rules installed" test -f "$full/.claude/rules/output.md" -a -f "$full/.claude/rules/git.md"
expect "full: structure map installed" grep -q '`src/features/<domain>/`' "$full/.claude/rules/structure.md"
expect "full: structure gate installed" test -x "$full/.claude/bin/structure"
expect "full: adapter and preset installed" test -f "$full/.claude/rules/typescript.md" -a -f "$full/.claude/rules/nextjs.md"
expect "full: the evidence workflow installed" test -f "$full/.github/workflows/evidence.yml"
expect "full: the evidence pack is not in the core" test ! -e "$full/.claude/bin/evidence" -a ! -e "$full/.claude/skills/verify-feature"
expect "full: leadtime is not in the core" test ! -e "$full/.claude/bin/leadtime"
expect "full: autopilot is not in the core" test ! -e "$full/.claude/bin/autopilot" -a ! -e "$full/.claude/bin/stack" -a ! -e "$full/.claude/bin/status" -a ! -e "$full/.claude/hooks/steer" -a ! -e "$full/.claude/hooks/summary"
expect "full: routing is not in the core" test ! -e "$full/.claude/bin/route" -a ! -e "$full/.claude/bin/usage" -a ! -e "$full/.claude/hooks/usage"
expect "full: settings.json registers no usage hook" sh -c "! grep -q 'hooks/usage' '$full/.claude/settings.json'"
expect "full: run records and /improve-kit are not in the core" test ! -e "$full/.claude/bin/runs" -a ! -e "$full/.claude/skills/improve-kit"
expect "full: adapter helpers installed" test -f "$full/.claude/bin/coverage-files.mjs"
expect "full: the onboarding tools are not in the core" test ! -e "$full/.claude/bin/baseline" -a ! -e "$full/.claude/bin/onboard-apply" -a ! -e "$full/.claude/skills/onboard"
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

# CORE-AC2, CORE-AC31: the marketplace lists one kit, and a project on the retired plugin is told so and left alone.
marketplace=$here/../../.claude-plugin/marketplace.json
expect "CORE-AC2: the marketplace lists stempel-kit and repo-check" sh -c "grep -q '\"name\": \"stempel-kit\"' '$marketplace' && grep -q '\"name\": \"repo-check\"' '$marketplace'"
expect "CORE-AC2: the marketplace lists no $retired" sh -c "! grep -q -- '$retired' '$marketplace'"
expect "CORE-AC2: no description says never both" sh -c "! grep -qi 'never both' '$marketplace'"
for ext in "$here"/../stempel-kit-*/; do
  ext=$(basename "$ext")
  expect "CORE-AC2: the marketplace lists $ext with its plugin folder" sh -c "grep -q '\"name\": \"$ext\"' '$marketplace' && grep -q '\"source\": \"./plugins/$ext/plugin\"' '$marketplace'"
done
expect "CORE-AC3: the core's plugin.json has version 1.0.0" grep -q '"version": "1.0.0"' "$here/kit/.claude/.claude-plugin/plugin.json"
for ext in "$here"/../stempel-kit-*/; do
  expect "every extension's plugin.json has version 0.1.0 ($(basename "$ext"))" grep -q '"version": "0.1.0"' "$ext/plugin/.claude-plugin/plugin.json"
done
old=$(mktemp -d)
mkdir -p "$old/.claude"
printf '{ "enabledPlugins": { "%s@stempel-kit": true } }\n' "$retired" >"$old/.claude/settings.json"
before=$(cd "$old" && find . -type f -exec cksum {} + | sort)
out=$("$here/install.sh" "$old" --plugin 2>&1)
code=$?
after=$(cd "$old" && find . -type f -exec cksum {} + | sort)
expect "CORE-AC31: a project on $retired is refused with exit 2" test "$code" -eq 2
expect "CORE-AC31: the message says $retired is retired" sh -c "echo \"\$1\" | grep -q -- '$retired is retired'" sh "$out"
expect "CORE-AC31: the message names the extensions" sh -c "echo \"\$1\" | grep -q 'stempel-kit-evidence' && echo \"\$1\" | grep -q 'stempel-kit-autopilot'" sh "$out"
expect "CORE-AC31: no file changed" test "$before" = "$after"
rm -rf "$old"

# CORE-AC19, CORE-AC20, CORE-AC33: install.sh --extension copies the extension's scripts and appends its
# kit.conf.part as one section; a second install keeps one section; two parts with one variable stop the install.
ext=$(mktemp -d)
mkdir -p "$ext/evidence/plugin/bin" "$ext/other/plugin/bin"
printf '#!/bin/sh\necho evidence\n' >"$ext/evidence/plugin/bin/evidence"
chmod +x "$ext/evidence/plugin/bin/evidence"
printf '# Seeds the database.\nKIT_SEED=""\nKIT_E2E=""\n' >"$ext/evidence/plugin/kit.conf.part"
printf '#!/bin/sh\necho other\n' >"$ext/other/plugin/bin/other"
printf 'KIT_OTHER=""\nKIT_E2E="dup"\n' >"$ext/other/plugin/kit.conf.part"
proj=$(mktemp -d)
"$here/install.sh" "$proj" --adapter typescript --plugin >/dev/null || echo "FAIL: core install for extensions exited $?"
core_before=$(sed '/^# extension: /,$d' "$proj/.claude/kit.conf")
"$here/install.sh" "$proj" --extension "$ext/evidence/plugin" >/dev/null || echo "FAIL: extension install exited $?"
expect "CORE-AC19: the extension's script is in .claude/bin" test -x "$proj/.claude/bin/evidence"
expect "CORE-AC19: kit.conf gains the section header" grep -q '^# extension: evidence bin/evidence$' "$proj/.claude/kit.conf"
section=$(sed -n '/^# extension: evidence /,/^# extension: /p' "$proj/.claude/kit.conf" | grep '^KIT_' | cut -d= -f1 | tr '\n' ' ')
expect "CORE-AC19: the section holds exactly the part's variables" test "$section" = "KIT_SEED KIT_E2E "
expect "CORE-AC19: the core variables are unchanged" test "$(sed '/^# extension: /,$d' "$proj/.claude/kit.conf")" = "$core_before"
"$here/install.sh" "$proj" --extension "$ext/evidence/plugin" >/dev/null || echo "FAIL: second extension install exited $?"
expect "CORE-AC20: a second install keeps one section" test "$(grep -c '^# extension: evidence ' "$proj/.claude/kit.conf")" -eq 1
out=$("$here/install.sh" "$proj" --extension "$ext/other/plugin" 2>&1)
code=$?
expect "CORE-AC33: a part that redefines a variable stops the install" test "$code" -eq 2
expect "CORE-AC33: the message names both extensions and the variable" sh -c "echo \"\$1\" | grep -q 'KIT_E2E' && echo \"\$1\" | grep -q 'evidence' && echo \"\$1\" | grep -q 'other'" sh "$out"
expect "CORE-AC33: nothing of the refused extension was installed" test ! -e "$proj/.claude/bin/other" -a "$(grep -c '^# extension: ' "$proj/.claude/kit.conf")" -eq 1
mkdir -p "$ext/indented/plugin/bin" && printf '#!/bin/sh\n' >"$ext/indented/plugin/bin/indented"
printf 'if true; then\n  KIT_TYPECHECK="x"\nfi\ntrue && KIT_SEED="y"\n' >"$ext/indented/plugin/kit.conf.part"
out=$("$here/install.sh" "$proj" --extension "$ext/indented/plugin" 2>&1)
expect "CORE-AC33: an indented assignment of a core variable stops the install" sh -c "echo \"\$1\" | grep -q 'KIT_TYPECHECK is already defined by the core'" sh "$out"
expect "CORE-AC33: an assignment after && is seen too" sh -c "echo \"\$1\" | grep -q 'KIT_SEED is already defined by extension evidence'" sh "$out"
expect "extension: an unknown name is refused" sh -c "! '$here/install.sh' '$proj' --extension no-such-extension >/dev/null 2>&1"
expect "extension: a project without the core is refused" sh -c "d=\$(mktemp -d); ! '$here/install.sh' \"\$d\" --extension '$ext/evidence/plugin' >/dev/null 2>&1"
rm -rf "$ext" "$proj"

# CORE-AC5: an adapter install writes the core part; an extension installed by name gets the adapter's settings.
proj=$(mktemp -d)
"$here/install.sh" "$proj" --adapter typescript --plugin >/dev/null || echo "FAIL: adapter install exited $?"
expect "CORE-AC5: the adapter's kit.conf has the core variables" grep -q '^KIT_TYPECHECK="$pm run typecheck"$' "$proj/.claude/kit.conf"
expect "CORE-AC5: the adapter's kit.conf has no extension variable" sh -c "! grep -q '^KIT_MODEL_FAST=\|^KIT_SEED\|^KIT_COVERAGE_THRESHOLD=\|^KIT_RISK_HUMAN=' '$proj/.claude/kit.conf'"
expect "CORE-AC5: no extensions folder in the project" test ! -e "$proj/extensions"
for e in onboard evidence routing autopilot improve risk; do
  "$here/install.sh" "$proj" --extension "$e" >/dev/null 2>"$proj/err" || echo "FAIL: --extension $e on the typescript adapter exited $?: $(cat "$proj/err")"
done
expect "CORE-AC5: the evidence section holds the adapter's settings" sh -c "sed -n '/^# extension: evidence /,/^# extension: /p' '$proj/.claude/kit.conf' | grep -q 'KIT_E2E_PATTERNS=\"e2e/'"
expect "CORE-AC5: the onboard section holds the adapter's coverage helper" sh -c "sed -n '/^# extension: onboard /,/^# extension: /p' '$proj/.claude/kit.conf' | grep -q 'coverage-files.mjs'"
expect "CORE-AC5: every typescript check still resolves" sh -c "cd '$proj' && . ./.claude/kit.conf && [ -n \"\$KIT_TEST\" ] && [ -n \"\$KIT_COVERAGE_FILES\" ] && [ \"\$KIT_MODEL_DEEP\" = opus ]"
rm -rf "$proj"

# CORE-AC18: the onboard extension installs by name into a core-only project.
proj=$(mktemp -d)
"$here/install.sh" "$proj" --plugin >/dev/null || echo "FAIL: core install for onboard exited $?"
"$here/install.sh" "$proj" --extension onboard >/dev/null || echo "FAIL: onboard install exited $?"
expect "CORE-AC18: onboard's scripts are in .claude/bin" test -x "$proj/.claude/bin/baseline" -a -x "$proj/.claude/bin/onboard-apply"
expect "CORE-AC18: the onboard section names its first script" grep -q '^# extension: onboard bin/baseline$' "$proj/.claude/kit.conf"
expect "CORE-AC18: check finds the onboard script" sh -c "cd '$proj' && ! .claude/bin/check extensions 2>&1 | grep -q onboard"
"$here/install.sh" "$proj" --extension evidence >/dev/null || echo "FAIL: evidence install exited $?"
"$here/install.sh" "$proj" --extension routing >/dev/null || echo "FAIL: routing install exited $?"
"$here/install.sh" "$proj" --extension autopilot >/dev/null || echo "FAIL: autopilot install exited $?"
"$here/install.sh" "$proj" --extension improve >/dev/null || echo "FAIL: improve install exited $?"
"$here/install.sh" "$proj" --extension risk >/dev/null || echo "FAIL: risk install exited $?"
expect "CORE-AC17: risk's script is in .claude/bin" test -x "$proj/.claude/bin/risk"
expect "CORE-AC17: the Risk workflow is in .github/workflows" test -f "$proj/.github/workflows/risk.yml"
expect "CORE-AC17: the risk section holds its variables" sh -c "sed -n '/^# extension: risk bin\/risk\$/,\$p' '$proj/.claude/kit.conf' | grep -q '^KIT_RISK_HUMAN='"
expect "CORE-AC16: improve's scripts are in .claude/bin" test -x "$proj/.claude/bin/runs" -a -x "$proj/.claude/bin/leadtime"
expect "CORE-AC16: the improve section names its first script" grep -q '^# extension: improve bin/leadtime$' "$proj/.claude/kit.conf"
expect "CORE-AC14: autopilot's scripts are in .claude/bin" test -x "$proj/.claude/bin/autopilot" -a -x "$proj/.claude/bin/stack" -a -x "$proj/.claude/bin/status"
expect "CORE-AC14: the autopilot section names its first script" grep -q '^# extension: autopilot bin/autopilot$' "$proj/.claude/kit.conf"
expect "CORE-AC15: routing's scripts are in .claude/bin" test -x "$proj/.claude/bin/route" -a -x "$proj/.claude/bin/usage"
expect "CORE-AC15: the routing section names its first script" grep -q '^# extension: routing bin/route$' "$proj/.claude/kit.conf"
expect "CORE-AC13: evidence's script is in .claude/bin" test -x "$proj/.claude/bin/evidence"
expect "CORE-AC13: the evidence section names its script" grep -q '^# extension: evidence bin/evidence$' "$proj/.claude/kit.conf"
rm -rf "$proj"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
