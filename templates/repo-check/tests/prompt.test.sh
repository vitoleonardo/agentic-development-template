#!/bin/sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
skill=$here/plugin/skills/repo-check/SKILL.md
prompt=$here/repo-check.md
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }

"$here/build" --check 2>"$work/err" && ok || fail "build --check: $(cat "$work/err")"

mkdir -p "$work/templates/agentic-workflow-kit/kit/.claude/bin"
cp -R "$here" "$work/templates/repo-check"
cp "$here/../agentic-workflow-kit/kit/.claude/bin/leadtime" "$work/templates/agentic-workflow-kit/kit/.claude/bin/"
copy=$work/templates/repo-check
drifts() {
  "$copy/build" --check >/dev/null 2>&1 && fail "build --check misses $1" || ok
  "$copy/build" >/dev/null 2>&1
}
sed 's/Frage <n> von 10/Frage <n> von 11/' "$copy/repo-check.md" >"$work/x" && cp "$work/x" "$copy/repo-check.md"
drifts "a hand edit of repo-check.md"
sed 's/Never promise dates/Promise dates/' "$copy/plugin/skills/repo-check/SKILL.md" >"$work/x" && cp "$work/x" "$copy/plugin/skills/repo-check/SKILL.md"
drifts "a rule changed in SKILL.md without a rebuild"
echo "# edited" >>"$copy/plugin/skills/repo-check/leadtime"
drifts "an edited leadtime copy"
echo "# edited" >>"$work/templates/agentic-workflow-kit/kit/.claude/bin/leadtime"
drifts "a kit leadtime change without a rebuild"

blocks() { sed -n 's/^<!-- shared:\([a-z-]*\) -->$/\1/p' "$1"; }
block() { awk -v name="$2" '$0 == "<!-- shared:" name " -->" { on = 1 } on { print } $0 == "<!-- /shared:" name " -->" { on = 0 }' "$1"; }
[ "$(blocks "$skill")" = "$(blocks "$prompt")" ] && ok || fail "the prompt carries every shared block of SKILL.md, in order"
for name in rules questions interview-result steps offers email verdicts; do
  block "$skill" "$name" >"$work/skill.$name"
  block "$prompt" "$name" >"$work/prompt.$name"
  [ -s "$work/skill.$name" ] && cmp -s "$work/skill.$name" "$work/prompt.$name" && ok || fail "the $name block differs between SKILL.md and repo-check.md"
done

count=$(grep -cE '^ ?[0-9]+\. [A-Z]' "$work/skill.questions")
[ "$count" -eq 10 ] && ok || fail "exactly ten questions, found $count"
for n in 1 2 3 4 5 6 7 8 9 10; do
  [ "$(grep -A2 -E "^ ?$n\. " "$work/skill.questions" | grep -cE '^ +- (de|en): ')" -eq 2 ] && ok || fail "question $n has a German and an English version"
done
grep -q 'Sie ' "$work/skill.questions" && fail "the German questions use du, not Sie" || ok

for f in "$skill" "$prompt"; do
  awk '/^<!-- shared:rules -->$/ { skip = 1 } !skip { print } /^<!-- \/shared:rules -->$/ { skip = 0 }' "$f" >"$work/text"
  hits=$(grep -inE '€|(^|[^[:alpha:]])eur([^[:alpha:]]|$)|preis|price|kosten|rabatt|discount|nur noch|only now|limited|begrenzt|garantiert|guarantee' "$work/text")
  [ -z "$hits" ] && ok || fail "${f#"$here"/} mentions prices or pressure outside the rule that forbids it: $hits"
done
grep -qF 'mailto:hi@vito.koeln' "$prompt" && ok || fail "the prompt has the mailto address"
grep -qF 'https://calendar.app.google/N14WVsxK4fdqBhZv6' "$prompt" && ok || fail "the prompt has the booking link"
grep -qF 'no hook' "$prompt" && ok || fail "the prompt says that no hook enforces it"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
