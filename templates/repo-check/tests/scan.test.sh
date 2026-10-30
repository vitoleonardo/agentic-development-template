#!/bin/sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
kit=$here/../agentic-workflow-kit
scan=$here/plugin/skills/repo-check/scan
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export REPO_CHECK_NOW=1790726400 LEADTIME_TODAY=2026-09-30
canary=env-canary-31c9

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
has() { if grep -qF -- "$2" "$1"; then ok; else fail "$3: no '$2' in $1:
$(cat "$1")"; fi; }
hasnt() { if grep -qF -- "$2" "$1"; then fail "$3: '$2' found in $1"; else ok; fi; }
hasnt_word() { if grep -qwF -- "$2" "$1"; then fail "$3: the word '$2' found in $1"; else ok; fi; }

commit_at() {
  GIT_AUTHOR_DATE=$1 GIT_COMMITTER_DATE=$1 git -c user.name="$2" -c user.email="$3" commit -q "$@" >/dev/null 2>&1
}
at() { GIT_AUTHOR_DATE=$1 GIT_COMMITTER_DATE=$1; export GIT_AUTHOR_DATE GIT_COMMITTER_DATE; }
as_dora() { git -c user.name="Dora Example" -c user.email=dora@example.invalid "$@" >/dev/null 2>&1; }
as_emil() { git -c user.name="Emil Sample" -c user.email=emil@example.invalid "$@" >/dev/null 2>&1; }

feature() {
  at "$1"
  git checkout -q -b "$2"
  mkdir -p "$(dirname "$3")"
  i=0
  while [ "$i" -lt "$4" ]; do echo "value_$i = $i" >>"$3"; i=$((i + 1)); done
  git add -A
  "$6" commit -qm "$5"
  git checkout -q main
  "$6" merge -q --no-ff "$2" -m "Merge $2: $5"
}


b=$work/python-pkg
cp -R "$kit/tests/onboard/python-pkg" "$b"
cd "$b" || exit 1
printf 'TOKEN=%s\n' "$canary" >.env.production
git init -q -b main
at 2026-07-01T00:00:00Z
git add -A
as_dora commit -qm "Initial"
feature 2026-09-01T00:00:00Z one src/calc/a.py 10 "add a" as_dora
as_dora tag -a v0.1 -m v0.1
feature 2026-09-08T00:00:00Z two src/calc/b.py 20 "add b" as_emil
at 2026-09-10T00:00:00Z
git checkout -q -b three
sed 's/value_0 = 0/value_0 = 100/' src/calc/a.py >src/calc/a.tmp && mv src/calc/a.tmp src/calc/a.py
echo "value_x = 1" >>src/calc/a.py
git add -A
as_dora commit -qm "fix a"
git checkout -q main
as_dora merge -q --no-ff three -m "fix a"
feature 2026-09-20T00:00:00Z four src/calc/c.py 40 "add c" as_emil
as_emil tag -a v0.2 -m v0.2
printf 'SECRET=%s\n' "$canary" >.env
before=$(git status --porcelain --untracked-files=all)

"$scan" --lang en >"$work/out" 2>&1 || fail "the git-only scan failed: $(cat "$work/out")"
r=.repo-check/report.md
after=$(git status --porcelain --untracked-files=all)
[ "$before" = "$after" ] && ok || fail "git status changed: before '$before', after '$after'"
has .repo-check/.gitignore "*" "the report folder ignores itself"
has "$r" "The jam is at: Intent (Writing)" "the jam is the earliest worst stage"
has "$r" "| Intent | red | spec folders: none; issue or PR templates: none; acceptance criteria: none |" "Intent with evidence"
has "$r" "| Build | red | agent guide: none; agent permissions: none; structure docs: none |" "Build with evidence"
has "$r" "| Review | yellow | PR size (median changed lines) 15.0, 4 merges (git log --first-parent -m --numstat HEAD); Time to first review (median h) n/a: needs GitHub data" "Review from git, capped"
has "$r" "| Gates | red | CI files: none; checks in CI: none; test files: 1 (git ls-files)" "Gates with evidence"
has "$r" "| Release | yellow | Merges per week 0.3; Tags in 90 days 2 (git for-each-ref refs/tags); Follow-up fix rate (%) 25.0; days since the last merge: 10" "Release with evidence"
has "$r" "**Too few PRs for a reliable comparison** (4)." "leadtime's warning below 10"
grep -qF "Too few PRs for a reliable comparison" "$kit/kit/.claude/bin/leadtime" && ok || fail "the warning is leadtime's own text"
has "$r" "| PR size (median changed lines) | 15.0 | git log --first-parent -m --numstat HEAD, 90 days | 4 merges |" "a number with source and count"
has "$r" "| Tags in 90 days | 2 | git for-each-ref refs/tags | 2 |" "tags"
for marker in "<!-- fill:reason -->" "<!-- fill:next-steps -->" "<!-- fill:offer -->"; do has "$r" "$marker" "the model's parts are marked"; done
has "$r" "- Team: 2 (contributors in 90 days)" "contributors are counted"
cp "$r" "$work/python.en.md"

"$scan" --lang de >/dev/null 2>&1 || fail "the German scan failed"
has "$r" "Der Stau steckt gerade bei: Intent (Schreiben)" "German jam line"
has "$r" "**Zu wenige PRs für einen verlässlichen Vergleich** (4)." "German warning"
has "$r" "## Zusammenfassung zum Weitergeben" "German summary heading"
cp "$r" "$work/python.de.md"
[ "$before" = "$(git status --porcelain --untracked-files=all)" ] && ok || fail "git status changed after the second scan"
git ls-files -z >"$work/python.files"


a=$work/pnpm-monorepo
cp -R "$kit/tests/onboard/pnpm-monorepo" "$a"
cd "$a" || exit 1
mkdir -p specs .claude .github/workflows
printf '# Export\n\n## Acceptance criteria\n\n- EXPORT-AC1: Given a list, when I export, then I get a file.\n' >specs/export.md
printf '{ "permissions": { "allow": ["Bash(pnpm test)"] } }\n' >.claude/settings.json
printf 'on: pull_request\njobs:\n  gates:\n    runs-on: ubuntu-latest\n    steps:\n      - run: pnpm lint\n      - run: pnpm typecheck\n      - run: pnpm test\n' >.github/workflows/ci.yml
git init -q -b main
at 2026-09-29T00:00:00Z
git add -A
as_dora commit -qm "Initial"
git remote add origin https://github.com/acme/shop.git
printf 'SECRET=%s\n' "$canary" >.env
before=$(git status --porcelain --untracked-files=all)

GH="$kit/tests/leadtime/fake-gh" "$scan" --lang en --gh >"$work/out" 2>&1 || fail "the gh scan failed: $(cat "$work/out")"
after=$(git status --porcelain --untracked-files=all)
[ "$before" = "$after" ] && ok || fail "git status changed with gh: before '$before', after '$after'"
has "$r" "The jam is at: Review (Review)" "the jam moves to Review"
has "$r" "| Intent | green | spec folders: specs/; issue or PR templates: none; acceptance criteria: specs/export.md |" "Intent green"
has "$r" "| Build | green | agent guide: AGENTS.md; agent permissions: .claude/settings.json; structure docs: none |" "Build green"
has "$r" "| Review | yellow | PR size (median changed lines) 40.0, Time to first review (median h) 3.5, Review rounds (median) 0.0, 7 PRs (gh via leadtime, 90 days); yellow below 10, too few to judge |" "Review from leadtime, capped below 10 PRs"
has "$r" "| Gates | green | CI files: .github/workflows/ci.yml; checks in CI: test, lint, typecheck; test files: " "Gates green"
has "$r" "strict typing: packages/web/tsconfig.json, ai-service/pyproject.toml |" "strict typing evidence"
has "$r" "| Release | yellow | Merges per week 0.5; Tags in 90 days 0 (git for-each-ref refs/tags); Rework rate (%) 28.6;" "Release from leadtime"
has "$r" "| Time to first review (median h) | 3.5 | gh via leadtime, 90 days | 4 PRs |" "first review with source and PR count"
has "$r" "| Rework rate (%) | 28.6 | gh via leadtime, 90 days | 7 PRs |" "rework with source and PR count"
has "$r" "**Too few PRs for a reliable comparison** (7)." "warning with gh"
has "$r" "- Numbers from: gh via leadtime, 90 days" "the summary names the source"
cp "$r" "$work/pnpm.en.md"
git ls-files -z >"$work/pnpm.files"

GH=false "$scan" --lang en --gh >/dev/null 2>&1 || fail "a failing gh must not fail the scan"
has "$r" "gh failed, so the numbers come from git" "a gh failure falls back to git and says so"


c=$work/import
mkdir -p "$c"
cd "$c" || exit 1
git init -q -b main
i=0
while [ "$i" -lt 1500 ]; do echo "line $i"; i=$((i + 1)); done >big.txt
at 2026-09-29T00:00:00Z
git add -A
as_dora commit -qm "Import"
"$scan" >/dev/null 2>&1 || fail "the scan of a one-commit repository failed"
has "$r" "| Review | yellow | PR size (median changed lines) 1500.0, 1 commits" "one large import commit is too few to judge, not red"
has "$r" "yellow below 10, too few to judge" "the report says why"

summary() { awk '/^## (Summary to share|Zusammenfassung zum Weitergeben)$/ { on = 1 } on' "$1"; }
for report in python.en python.de pnpm.en; do
  f=$work/$report.md
  summary "$f" >"$work/$report.summary"
  [ "$(wc -l <"$work/$report.summary")" -gt 5 ] && ok || fail "$report has a summary block"
  hasnt "$work/$report.summary" "/" "$report: no path below the top level in the summary"
  for word in Dora Emil example.invalid ana ben cara acme shop github.com '```' "$canary"; do
    hasnt_word "$work/$report.summary" "$word" "$report: the summary has no names, repo name or code fence"
  done
  for word in Dora Emil example.invalid '```' "$canary"; do
    hasnt "$f" "$word" "$report: the report has no author, code fence or secret"
  done
done

leaked() {
  (cd "$1" && xargs -0 cat <"$2" 2>/dev/null) | awk -v report="$3" '
    BEGIN { while ((getline l < report) > 0) r[++n] = l }
    { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); if (length($0) <= 20) next
      for (i = 1; i <= n; i++) if (index(r[i], $0)) { print; exit } }'
}
for pair in "$b:python.files:python.en" "$b:python.files:python.de" "$a:pnpm.files:pnpm.en"; do
  repo=${pair%%:*} rest=${pair#*:}
  line=$(leaked "$repo" "$work/${rest%%:*}" "$work/${rest#*:}.md")
  [ -z "$line" ] && ok || fail "${rest#*:}: a line of a tracked file is in the report: $line"
done

cp "$work/pnpm.en.md" "$work/planted.md"
printf '| x | %s |\n' 'export const ENTERPRISE_CANARY = "ee-canary-7f3a";' >>"$work/planted.md"
[ -n "$(leaked "$a" "$work/pnpm.files" "$work/planted.md")" ] && ok || fail "the leak check finds a planted line of a tracked file"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
