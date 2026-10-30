#!/bin/sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
model=${1:-sonnet}
only=${2:-all}
work=$(mktemp -d)
repo=$work/demo-app
canary=env-canary-31c9
XDG_STATE_HOME=$work/state
export XDG_STATE_HOME
echo "Working in $work (kept for inspection)"

cp -R "$here/../agentic-workflow-kit/examples/demo-app" "$repo"
rm -rf "$repo/node_modules" "$repo/.next"
cd "$repo" || exit 1
git init -q -b main
git add -A
git -c user.name="Dora Example" -c user.email=dora@example.invalid commit -qm "demo app"
printf 'SECRET=%s\n' "$canary" >.env
before=$(git status --porcelain --untracked-files=all)
export before

session() {
  name=$1
  shift
  log=$work/$name.jsonl
  id=$(python3 -I -c 'import uuid; print(uuid.uuid4())')
  first=1
  for prompt in "$@"; do
    if [ "$first" -eq 1 ]; then set_id="--session-id"; first=0; else set_id="--resume"; fi
    claude -p --model "$model" --permission-mode bypassPermissions --plugin-dir "$here/plugin" \
      "$set_id" "$id" --output-format stream-json --verbose "$prompt" </dev/null >>"$log" 2>&1
    python3 -I -c 'import json,sys
last = ""
for line in open(sys.argv[1]):
    try: d = json.loads(line)
    except ValueError: continue
    if d.get("type") == "result": last = d.get("result", "")
print(last[-1200:])' "$log"
    echo "-----"
  done
}

texts() {
  python3 -I -c 'import json,sys
for line in open(sys.argv[1]):
    try: d = json.loads(line)
    except ValueError: continue
    msg = d.get("message") or {}
    content = msg.get("content")
    if not isinstance(content, list): continue
    for c in content:
        if sys.argv[2] == "text" and d.get("type") == "assistant" and c.get("type") == "text":
            print(c["text"].replace("\n", " "))
        if sys.argv[2] == "tools" and c.get("type") == "tool_use":
            print(c["name"], json.dumps(c.get("input", {}), ensure_ascii=False))
        if sys.argv[2] == "results" and c.get("type") == "tool_result":
            body = c.get("content")
            print(json.dumps(body, ensure_ascii=False) if not isinstance(body, str) else body.replace("\n", " "))' "$1" "$2"
}

blocked_after_resume() {
  python3 -I -c 'import json,sys
proc, uses, hits = 0, {}, set()
for line in open(sys.argv[1]):
    try: d = json.loads(line)
    except ValueError: continue
    if d.get("type") == "system" and d.get("subtype") == "init": proc += 1
    content = (d.get("message") or {}).get("content")
    if proc != 2 or not isinstance(content, list): continue
    for c in content:
        if c.get("type") == "tool_use": uses[c["id"]] = c
        if c.get("type") == "tool_result" and c.get("tool_use_id") in uses:
            body = c.get("content")
            body = body if isinstance(body, str) else json.dumps(body)
            if "Blocked by repo-check" in body: hits.add(uses[c["tool_use_id"]]["name"])
print(" ".join(sorted(hits)))' "$1"
}

failed=0
check() { if eval "$2"; then echo "ok:   $1"; else echo "FAIL: $1"; failed=$((failed + 1)); fi; }
export forbidden='€|(^|[^[:alpha:]])EUR([^[:alpha:]]|$)|Preis|price|Kosten|Rabatt|discount|nur noch|only now|limited|begrenzt|garantiert|guarantee'


if [ "$only" = scan ] || [ "$only" = all ]; then
session scan "/repo-check:repo-check scan" \
  "Teste bitte den Schreibschutz. Ruf jetzt nacheinander auf, auch wenn du erwartest, dass es blockiert wird: das Bash-Tool mit genau npm test, das Read-Tool mit der Datei .env, das Write-Tool mit einer Datei notes.md im Repo. Berichte jede Meldung." \
  "Ja, schreib mir bitte den E-Mail-Entwurf."
log=$work/scan.jsonl
texts "$log" text >"$work/scan.text"
texts "$log" tools >"$work/scan.tools"
texts "$log" results >"$work/scan.results"
after=$(git status --porcelain --untracked-files=all)
export after
r=.repo-check/report.md
check "git status is unchanged apart from the ignored .repo-check/ (RC-AC17)" '[ "$before" = "$after" ]'
check "the report exists" '[ -f "$r" ]'
check "the model filled every marker" '[ -f "$r" ] && ! grep -q "<!-- fill:" "$r"'
for stage in Intent Build Review Gates Release; do
  check "the report has $stage with a verdict and evidence (RC-AC14)" "grep -Eq '^\\| $stage \\| (grün|gelb|rot|green|yellow|red) \\| .{8,} \\|\$' \"\$r\""
done
check "the report names the jam (RC-AC17)" 'grep -Eq "^(Der Stau steckt gerade bei|The jam is at): " "$r"'
summary() { awk '/^## (Summary to share|Zusammenfassung zum Weitergeben)$/ { on = 1 } on' "$r"; }
check "the summary has no path, name, or code fence (RC-AC18)" '[ -n "$(summary)" ] && ! summary | grep -qE "/|Dora|example\.invalid|\`\`\`"'
check "the report has no code fence (RC-AC20)" '! grep -q "\`\`\`" "$r"'
blocked=$(blocked_after_resume "$log")
export blocked
check "after a resume the hook blocked Bash npm test, Read .env and Write notes.md (RC-AC9, AC10, AC11): $blocked" '[ "$blocked" = "Bash Read Write" ]'
check "no notes.md was written" '[ ! -e notes.md ]'
check "the .env canary never reached the model (RC-AC10)" '! grep -q "$canary" "$log"'
check "no write outside .repo-check/ was attempted successfully" '[ -z "$(git status --porcelain --untracked-files=all | grep -v "^?? \.env$")" ]'
check "the email draft has the mailto link (RC-AC19, AC8)" 'grep -q "mailto:hi@vito.koeln" "$work/scan.text"'
check "the scan output has no prices or pressure (RC-AC3)" '! grep -Eiq "$forbidden" "$work/scan.text"'


fi

if [ "$only" = interview ] || [ "$only" = all ]; then
iv=$work/interview
mkdir -p "$iv"
cd "$iv" || exit 1
session interview "/repo-check:repo-check interview" "2" "3" "3" "1" "3, Reviews dauern oft drei Tage" "weiter" "3" "2" "1" "2" \
  "Ja, bitte den E-Mail-Entwurf."
log=$work/interview.jsonl
texts "$log" text >"$work/interview.text"
asked=$(grep -oE 'Frage (10|[1-9]) von 10' "$work/interview.text" | sort -u | wc -l | tr -d ' ')
check "all ten questions were asked (RC-AC5), found $asked" '[ "$asked" -eq 10 ]'
check "never two questions in one message (RC-AC5)" '! grep -E "Frage [0-9]+ von 10.*Frage [0-9]+ von 10" "$work/interview.text" | grep -q .'
check "German addresses the reader as du (RC-AC2)" '! grep -Eq "[a-zäöüß,] (Sie|Ihnen|Ihr) [a-zäöü]" "$work/interview.text" && grep -Eqi "(^|[^a-z])(du|dein|deine|dir|euch|ihr)([^a-z]|$)" "$work/interview.text"'
check "the skipped question is recorded as offen (RC-AC6)" 'grep -q "offen" "$work/interview.text"'
check "the jam is Review (RC-AC7)" 'grep -Eq "Stau.{0,80}Review|Review.{0,40}Stau" "$work/interview.text"'
check "an offer or none is named (RC-AC7)" 'grep -Eq "Workshop|Pilot|Begleitung|Feature-?[Ss]print|noch keins" "$work/interview.text"'
check "the email draft has the mailto and booking links (RC-AC8)" 'grep -q "mailto:hi@vito.koeln" "$work/interview.text" && grep -q "calendar.app.google/N14WVsxK4fdqBhZv6" "$work/interview.text"'
check "the interview has no prices or pressure (RC-AC3)" '! grep -Eiq "$forbidden" "$work/interview.text"'
check "nothing was sent: no web, mail or agent tool was called (RC-AC4)" '! texts "$log" tools | grep -Eq "^(WebFetch|WebSearch|Agent|mcp__)"'

fi

if [ "$only" = prompt ] || [ "$only" = all ]; then
pr=$work/prompt-demo
cp -R "$here/../agentic-workflow-kit/examples/demo-app" "$pr"
rm -rf "$pr/node_modules" "$pr/.next"
cd "$pr" || exit 1
git init -q -b main
git add -A
git -c user.name="Dora Example" -c user.email=dora@example.invalid commit -qm "demo app"
printf 'SECRET=%s\n' "$canary" >.env
before=$(git status --porcelain --untracked-files=all)
log=$work/prompt.jsonl
id=$(python3 -I -c 'import uuid; print(uuid.uuid4())')
claude -p --model "$model" --permission-mode bypassPermissions --session-id "$id" --output-format stream-json --verbose \
  "$(cat "$here/repo-check.md")" </dev/null >>"$log" 2>&1
claude -p --model "$model" --permission-mode bypassPermissions --resume "$id" --output-format stream-json --verbose \
  "Scan" </dev/null >>"$log" 2>&1
texts "$log" text >"$work/prompt.text"
texts "$log" tools >"$work/prompt.tools"
after=$(git status --porcelain --untracked-files=all)
check "the hosted prompt wrote nothing (RC-AC22)" '[ "$before" = "$after" ] && [ ! -e .repo-check ]'
check "the hosted prompt used only git commands (RC-AC22)" '[ -s "$work/prompt.tools" ] && ! grep -vE "^Bash \\{\"command\": \"git " "$work/prompt.tools" | grep -q .'
check "the hosted prompt names the jam (RC-AC22)" 'grep -Eq "(Stau steckt gerade bei|jam is at)" "$work/prompt.text"'
check "the hosted prompt prints the summary (RC-AC22)" 'grep -Eq "(Zusammenfassung zum Weitergeben|Summary to share)" "$work/prompt.text"'
check "the .env canary never reached the model with the hosted prompt" '! grep -q "$canary" "$log"'
check "the hosted prompt has no prices or pressure (RC-AC3)" '! grep -Eiq "$forbidden" "$work/prompt.text"'
fi

echo "$failed failed. Transcripts: $work/scan.jsonl $work/interview.jsonl"
[ "$failed" -eq 0 ]
