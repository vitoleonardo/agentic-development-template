#!/bin/sh
# Tests for model routing (.claude/bin/route) and the usage record (hooks/usage, .claude/bin/usage).
# Run: sh templates/agentic-workflow-kit/tests/usage.test.sh
# The transcripts are fixtures in the format Claude Code 2.1.311 writes: one JSON object per line, an
# assistant message repeated while it streams, its usage on every copy.
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT
cp -R "$here/kit/." "$project/"
cd "$project" || exit 1
export CLAUDE_PROJECT_DIR="$project"
git init -q -b 7-routing
unset CLAUDE_CODE_SUBAGENT_MODEL_FORCE

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
same() { if [ "$1" = "$2" ]; then ok; else fail "$3: got '$1', wanted '$2'"; fi; }

# --- routing --------------------------------------------------------------------

same "$(.claude/bin/route implement)" sonnet "implement runs on the standard tier"
same "$(.claude/bin/route review)" opus "review runs on the deep tier"
same "$(.claude/bin/route explore)" haiku "explore runs on the fast tier"
same "$(.claude/bin/route up fast)" standard "escalation goes one tier up"
same "$(.claude/bin/route up deep)" deep "a deep task's retry stays on deep"
sed -i 's/^KIT_MODEL_STANDARD=.*/KIT_MODEL_STANDARD="opus"/' .claude/kit.conf
same "$(.claude/bin/route implement)" opus "changing KIT_MODEL_STANDARD changes every standard dispatch (ROUTE-AC4)"
same "$(.claude/bin/route tests)" opus "the test-writer follows the standard tier too (ROUTE-AC4)"
sed -i 's/^KIT_MODEL_STANDARD=.*/KIT_MODEL_STANDARD="claude-sonnet-5-5"/' .claude/kit.conf
out=$(.claude/bin/route implement 2>&1)
code=$?
[ "$code" -eq 2 ] && case $out in *"not an alias the Agent tool accepts"*) true ;; *) false ;; esac && ok || fail "a full model ID is refused: $out"
sed -i 's/^KIT_MODEL_STANDARD=.*/KIT_MODEL_STANDARD="sonnet"/' .claude/kit.conf
.claude/bin/route check >/dev/null && ok || fail "route check passes without the force variable"
out=$(CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1 CLAUDE_CODE_SUBAGENT_MODEL=haiku .claude/bin/route check)
code=$?
[ "$code" -eq 1 ] && case $out in *"tiers in .claude/kit.conf are ignored"*) true ;; *) false ;; esac && ok || fail "the force variable is reported (ROUTE-AC5): $out"

# --- usage hook -----------------------------------------------------------------

mkdir -p t/subagents
# A message streams in three lines with the same ID; only the last counts.
cat >t/main.jsonl <<'EOF'
{"type":"user","message":{"role":"user","content":"hi"}}
{"type":"assistant","requestedModel":"opus","message":{"id":"msg_A","model":"claude-opus-5-5","content":[{"type":"text","text":"the \"model\":\"haiku\" in text is not a key"}],"usage":{"input_tokens":10,"cache_creation_input_tokens":1000,"cache_read_input_tokens":0,"output_tokens":1,"cache_creation":{"ephemeral_1h_input_tokens":1000}}}}
{"type":"assistant","message":{"id":"msg_A","model":"claude-opus-5-5","content":[],"usage":{"input_tokens":10,"cache_creation_input_tokens":1000,"cache_read_input_tokens":0,"output_tokens":50,"cache_creation":{"ephemeral_1h_input_tokens":1000}}}}
{"type":"assistant","message":{"id":"msg_B","model":"claude-opus-5-5","content":[],"usage":{"input_tokens":5,"cache_creation_input_tokens":200,"cache_read_input_tokens":1000,"output_tokens":20}}}
{"type":"assistant","message":{"id":"msg_C","model":"<synthetic>","content":[],"usage":{"input_tokens":0,"output_tokens":0}}}
EOF
cat >t/subagents/agent-a1.jsonl <<'EOF'
{"type":"assistant","message":{"id":"msg_S1","model":"claude-sonnet-5-5","content":[],"usage":{"input_tokens":3,"cache_creation_input_tokens":300,"cache_read_input_tokens":0,"output_tokens":40}}}
{"type":"assistant","message":{"id":"msg_S2","model":"claude-sonnet-5-5","content":[],"usage":{"input_tokens":2,"cache_creation_input_tokens":100,"cache_read_input_tokens":300,"output_tokens":60}}}
EOF
cat >t/subagents/agent-a2.jsonl <<'EOF'
{"type":"assistant","message":{"id":"msg_R1","model":"claude-opus-5-5","content":[],"usage":{"input_tokens":4,"cache_creation_input_tokens":400,"cache_read_input_tokens":0,"output_tokens":100}}}
EOF
hook() { printf '%s' "$1" | .claude/hooks/usage; }
hook '{"session_id":"s","hook_event_name":"PostToolUse","tool_name":"Agent","tool_input":{"description":"task 1: total line","prompt":"Implement {the} task","subagent_type":"implementer","model":"sonnet"},"tool_response":{"agentId":"a1","resolvedModel":"claude-sonnet-5-5","totalTokens":5,"content":[{"type":"text","text":"done"}]}}'
hook '{"session_id":"s","hook_event_name":"SubagentStop","agent_id":"a1","agent_type":"implementer","agent_transcript_path":"'"$project"'/t/subagents/agent-a1.jsonl"}'
hook '{"session_id":"s","hook_event_name":"PostToolUse","tool_name":"Agent","tool_input":{"description":"task 1 retry deep: total line","subagent_type":"implementer","model":"opus"},"tool_response":{"agentId":"a2","resolvedModel":"claude-opus-5-5"}}'
hook '{"session_id":"s","hook_event_name":"SubagentStop","agent_id":"a2","agent_type":"implementer","agent_transcript_path":"'"$project"'/t/subagents/agent-a2.jsonl"}'
hook '{"session_id":"s","hook_event_name":"Stop","transcript_path":"'"$project"'/t/main.jsonl","stop_hook_active":false}'
hook '{"session_id":"s","hook_event_name":"Stop","transcript_path":"'"$project"'/t/main.jsonl","stop_hook_active":false}'
# A second session on the branch (for example a standalone /review-diff) adds its own line.
printf '%s\n' '{"type":"assistant","message":{"id":"msg_Z","model":"claude-haiku-5-5","content":[],"usage":{"input_tokens":1,"cache_creation_input_tokens":9,"cache_read_input_tokens":0,"output_tokens":2}}}' >t/other.jsonl
hook '{"session_id":"s2","hook_event_name":"Stop","transcript_path":"'"$project"'/t/other.jsonl","stop_hook_active":false}'

u=.work/7-routing/usage.tsv
same "$(grep -c . "$u")" 4 "one line per agent and session; a second Stop of the same session replaces instead of appending"
same "$(grep '^main:s	' "$u")" "main:s	claude-opus-5-5	15	70	1000	1200" "the main session counts the last copy of each message, without synthetic ones"
same "$(grep -c '^main:s2	' "$u")" 1 "another session does not overwrite the first"
same "$(grep '^a1' "$u")" "a1	claude-sonnet-5-5	5	100	300	400" "a subagent's tokens come from its own transcript"
same "$(cut -f1-3,5 .work/7-routing/agents.tsv | head -n 1)" "a1	task 1: total line	implementer	claude-sonnet-5-5" "the agent is mapped to its task and model (ROUTE-AC1)"
same "$(.claude/bin/usage total)" $((15 + 70 + 1200 + 5 + 100 + 400 + 4 + 100 + 400 + 12)) "the total counts input, output and cache writes"
line=$(.claude/bin/usage line)
case $line in
  *"standard 505"*"deep 504"*"main session 1297"*"Escalations: 1."*) ok ;;
  *) fail "the PR line shows tokens per tier and the escalation (ROUTE-AC2): $line" ;;
esac

# Spec and plan run on main before the branch exists; adopt moves their record over.
mkdir -p .work/main
printf 'main:s0\tclaude-opus-5-5\t1\t1\t0\t8\n' >.work/main/usage.tsv
printf 'r0\tspec review: total\treviewer\topus\tclaude-opus-5-5\n' >.work/main/agents.tsv
.claude/bin/usage adopt main >/dev/null
same "$(grep -c '^main:s0' "$u")" 1 "adopt moves the spec phase's tokens to the branch"
same "$(grep -c '^r0' .work/7-routing/agents.tsv)" 1 "adopt moves the agent map too"
[ ! -f .work/main/usage.tsv ] && ok || fail "adopt leaves nothing behind"

# --- budget ---------------------------------------------------------------------

pre='{"session_id":"s","hook_event_name":"PreToolUse","tool_name":"Agent","transcript_path":"'"$project"'/t/main.jsonl","tool_input":{"description":"task 2"}}'
out=$(hook "$pre")
same "$?:$out" "0:" "no budget, no message"
printf 'KIT_BUDGET_TOKENS="2800"\n' >>.claude/kit.conf
out=$(hook "$pre")
case $out in *'"additionalContext":"Token budget: 2316 of 2800'*) ok ;; *) fail "80 percent of the budget warns: $out" ;; esac
sed -i 's/^KIT_BUDGET_TOKENS="2800"$/KIT_BUDGET_TOKENS="2000"/' .claude/kit.conf
out=$(hook "$pre" 2>&1)
code=$?
[ "$code" -eq 2 ] && case $out in *"Stop before the next dispatch and ask the user"*) true ;; *) false ;; esac && ok || fail "a used-up budget blocks the next dispatch (ROUTE-AC3): $code $out"
out=$(KIT_BUDGET_TOKENS=100000 hook "$pre" 2>&1)
same "$?:$out" "0:" "the budget from the environment wins over kit.conf (autopilot sets it per run)"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
