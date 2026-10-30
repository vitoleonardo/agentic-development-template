#!/bin/sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
hook=$here/plugin/hooks/read-only
scan=$here/plugin/skills/repo-check/scan
project=$(mktemp -d)
data=$(mktemp -d)
trap 'rm -rf "$project" "$data"' EXIT
printf 'SECRET=env-canary-31c9\n' >"$project/.env"
export CLAUDE_PROJECT_DIR="$project" XDG_STATE_HOME="$data" CLAUDE_PLUGIN_DATA="$project/wrong-plugin-data"

failed=0
passed=0

json_quote() {
  printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
}

run_hook() {
  session=$1 mode=$2 tool=$3 field=$4 value=$5 extra=${6:-}
  input="{\"session_id\":\"$session\",\"cwd\":\"$project\",\"tool_name\":\"$tool\",\"tool_input\":{\"$field\":$(json_quote "$value")$extra}}"
  if [ "$mode" = start ]; then
    printf '%s' "$input" | "$hook" --start 2>"$project/err"
  else
    printf '%s' "$input" | "$hook" 2>"$project/err"
  fi
}

expect() {
  want=$1 tool=$2 field=$3 value=$4 extra=${5:-}
  out=$(run_hook s1 start "$tool" "$field" "$value" "$extra")
  code=$?
  got=allow
  [ "$code" -eq 2 ] && got=block
  case $out in *'"permissionDecision":"ask"'*) got=ask ;; esac
  if [ "$got" = "$want" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL: expected $want, got $got (exit $code) for $tool $value $extra"
  fi
}

expect block Write file_path "$project/src/x.ts"
expect block Write file_path "$project/.repo-check/../src/x.ts"
expect block Write file_path "src/x.ts"
expect block Edit file_path "$project/package.json"
expect block Write file_path "$project/.repo-checkx/report.md"
expect allow Write file_path "$project/.repo-check/report.md"
expect allow Edit file_path ".repo-check/report.md"
expect block NotebookEdit notebook_path "$project/a.ipynb"

for c in "npm test" "npm run build" "npm ci" "pnpm install" "yarn lint" "bunx vitest" "npx tsc" "pytest" "uv run pytest" \
  "make" "make test" "prisma migrate dev" "npm run seed" "python manage.py migrate" "cargo build" "go test ./..." \
  "curl https://example.invalid" "cat .env" "rm -rf src" "git commit -m x" "git checkout main" "git reset --hard" \
  "git stash" "git clean -fd" "git fetch" "git pull" "git push" "git config user.name x" "git gc" "git worktree add x" \
  "git log -p" "git log --patch" "git log -L1,5:src/a.ts" "git show HEAD" "git show HEAD:src/a.ts" "git diff" \
  "git diff HEAD~1 -- src/a.ts" "git -c core.pager=x log" "git -C /tmp log" "git branch new" "git branch -D main" \
  "git tag v9" "git tag -d v1" "git status && npm test" "git status; npm test" "git log > f" "git log | head" \
  "git log \$(npm test)" "git log \`npm test\`" "GIT_PAGER=cat git log" "git log --output=f" "git show HEAD:.env" \
  "git log -- .env" "gh pr create" "gh pr merge 1" "gh pr comment 1 -b x" "gh issue list" "gh api -X POST repos/a/b/issues" \
  "gh api repos/a/b/issues -f title=x" "gh api graphql -f query=mutation{x}" "$scan --lang fr" "$scan --write" \
  "$here/plugin/skills/repo-check/leadtime"; do
  expect block Bash command "$c"
done

for c in "git status" "git log --oneline" "git log --first-parent --merges --format=%H" "git --no-pager log -5" \
  "git ls-files" "git rev-parse --show-toplevel" "git rev-list --count HEAD" "git show --stat HEAD" \
  "git diff --numstat HEAD~1 HEAD" "git branch -a" "git branch" "git tag --list" "git tag" "git remote -v" \
  "git for-each-ref refs/tags" "git describe --tags" "git merge-base HEAD main" "$scan" "$scan --lang de" \
  "\"$scan\" --lang en"; do
  expect allow Bash command "$c"
done

for c in "gh pr list --state merged" "gh pr view 12 --json reviews" "gh repo view --json nameWithOwner" \
  "gh api repos/a/b/pulls" "gh api -X GET repos/a/b/pulls -f state=closed" "gh api graphql -f query=query{viewer{login}}" \
  "$scan --gh" "$scan --lang de --gh"; do
  expect ask Bash command "$c"
done

ln -s "$here/plugin/skills/repo-check" "$project/linked"
expect allow Bash command "$project/linked/scan --lang en"
printf '#!/bin/sh\n' >"$project/scan"
expect block Bash command "$project/scan --lang en"

expect block Read file_path "$project/.env"
expect block Read file_path "$project/config/.env.local"
expect block Read file_path "$project/deploy/server.pem"
expect block Read file_path "$project/.npmrc"
expect block Read file_path "$HOME/.ssh/id_rsa"
expect allow Read file_path "$project/.env.example"
expect allow Read file_path "$project/package.json"
expect block Glob pattern "**/.env*"
expect block Glob pattern ".env"
expect allow Glob pattern ".github/workflows/*.yml"
expect block Grep pattern "SECRET" ",\"path\":\"$project/.env\""
expect block Grep pattern "SECRET" ",\"glob\":\"*.env\""
expect block Grep pattern "strict" ",\"output_mode\":\"content\""
expect allow Grep pattern "strict" ",\"output_mode\":\"files_with_matches\""
expect allow Grep pattern "strict"
for t in WebFetch WebSearch Agent Skill mcp__claude_ai_Gmail__send_message; do
  expect block "$t" url "https://example.invalid"
done
expect allow AskUserQuestion question "Interview or scan?"

run_hook s1 start Read file_path "$project/.env" >/dev/null
grep -q "Start a new session" "$project/err" && passed=$((passed + 1)) || { failed=$((failed + 1)); echo "FAIL: the block message says how to get out of the read-only session"; }
grep -q "env-canary-31c9" "$project/err" && { failed=$((failed + 1)); echo "FAIL: the block message leaks the secret"; } || passed=$((passed + 1))

run_hook other plugin Bash command "npm test" >/dev/null
[ $? -eq 0 ] && passed=$((passed + 1)) || { failed=$((failed + 1)); echo "FAIL: the plugin-wide hook leaves sessions without /repo-check alone"; }
run_hook s1 plugin Bash command "npm test" >/dev/null
[ $? -eq 2 ] && passed=$((passed + 1)) || { failed=$((failed + 1)); echo "FAIL: the plugin-wide hook keeps a /repo-check session read-only after a resume"; }

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
