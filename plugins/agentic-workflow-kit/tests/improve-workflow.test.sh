#!/bin/sh
# Tests for the /improve-kit deep workflow (.claude/workflows/improve-kit.js).
# Run: sh plugins/agentic-workflow-kit/tests/improve-workflow.test.sh
#
# The script runs under node with stub agents, so only its plain code is tested: event ids, the minimum sample,
# causes another change already addresses, the two checks per proposal, the proposal limit and the agent options.
# Expected values, by hand from the fixture in harness.mjs:
#   runs b1..b5, b5 returns nothing. Events: b1#1 kit 2 rounds, b1#2 hotfix 1, b2#1 kit 1, b2#2 env 0,
#   b3#1 kit 1, b3#2 test 1, b4#1 test 2 (500 tokens), b4#2 kit 1.
#   causes: flaky e2e (b3#2, b4#1) 3 rounds 500 tokens; secret scan (b1#1, b2#1) 3 rounds; wrong base (b3#1, b4#2)
#   addressed by an earlier change; credentials (b2#2) env, one event is enough; odd hotfix (b1#2) below the minimum;
#   a cause with an unknown id and an already claimed one has no events and disappears.
#   The evidence check refutes credentials. maxProposals 1: flaky e2e is proposed, secret scan is over the limit.
#   Improvements: 30.09 has 5 runs after it (checked), 03.10 has 2 (too early).
#   Agents: 5 read + 1 earlier + 1 cluster + 3 propose + 6 verify = 16.
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
script=$here/kit/.claude/workflows/improve-kit.js
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }

command -v node >/dev/null 2>&1 || { echo "FAIL: node is needed for this suite"; exit 1; }

sed -n '/^export const meta = {/,/^}/p' "$script" >"$work/meta.mjs"
{
  echo 'export default async function (args, agent, parallel, pipeline, log, phase, budget) {'
  sed 's/^export const meta = /const meta = /' "$script"
  echo '}'
} >"$work/workflow.mjs"

if node --check "$work/workflow.mjs" 2>"$work/check.err"; then ok; else fail "the script does not parse: $(cat "$work/check.err")"; fi
if grep -Eq '\$\{|`|\.\.\.|\(' "$work/meta.mjs"; then fail "meta is not a pure literal"; else ok; fi
if grep -Eq 'Date\.now|Math\.random|new Date\(\)' "$script"; then fail "the script uses the clock or randomness, which breaks resume"; else ok; fi

cat >"$work/harness.mjs" <<'EOF'
import { meta } from './meta.mjs'
import run from './workflow.mjs'

const out = []
const check = (cond, what) => out.push(cond ? 'ok' : `FAIL: ${what}`)
const same = (got, want, what) => check(JSON.stringify(got) === JSON.stringify(want), `${what}: got ${JSON.stringify(got)}, wanted ${JSON.stringify(want)}`)

const ev = (kind, cls, area, rounds, cause, tokens) => ({ kind, class: cls, area, rounds, cause, evidence: `.work/x.md:${rounds}`, ...(tokens ? { tokens } : {}) })
const EVENTS = {
  b1: [ev('verify-failure', 'kit', 'check', 2, 'secret scan flags fake value'), ev('review-finding', 'hotfix', 'product', 1, 'odd product bug')],
  b2: [ev('verify-failure', 'kit', 'check', 1, 'secret scan flags fixture'), ev('stop', 'env', 'other', 0, 'missing credentials')],
  b3: [ev('verify-failure', 'kit', 'check', 1, 'wrong base'), ev('verify-failure', 'test', 'test-stack', 1, 'flaky e2e')],
  b4: [ev('verify-failure', 'test', 'test-stack', 2, 'flaky e2e', 500), ev('verify-failure', 'kit', 'check', 1, 'wrong base')],
}
const CAUSES = [
  { title: 'Secret scan', area: 'check', summary: 's', eventIds: ['b1#1', 'b2#1'], alreadyAddressedBy: '' },
  { title: 'Wrong base', area: 'check', summary: 's', eventIds: ['b3#1', 'b4#2'], alreadyAddressedBy: '2026-09-30 one base' },
  { title: 'Flaky e2e', area: 'test-stack', summary: 's', eventIds: ['b3#2', 'b4#1'], alreadyAddressedBy: '' },
  { title: 'Credentials', area: 'other', summary: 's', eventIds: ['b2#2'], alreadyAddressedBy: '' },
  { title: 'Odd hotfix', area: 'product', summary: 's', eventIds: ['b1#2'], alreadyAddressedBy: '' },
  { title: 'Ghost', area: 'other', summary: 's', eventIds: ['zz#9', 'b1#1'], alreadyAddressedBy: '' },
]

const calls = []
const logs = []
async function agent(prompt, opts) {
  calls.push(opts)
  const label = opts.label
  if (label.startsWith('read: ')) { const b = label.slice(6); return EVENTS[b] ? { events: EVENTS[b] } : null }
  if (label.startsWith('earlier: ')) return { verdict: 'kept', before: '2', now: '0', reason: 'r' }
  if (label === 'cluster') return { causes: CAUSES }
  if (label.startsWith('propose: ')) { const t = label.slice(9); return { title: `Fix ${t}`, observation: 'o', change: 'c', files: ['.claude/bin/evidence'], expectedEffect: 'e', measure: 'm' } }
  if (label.startsWith('verify evidence: ')) return { refuted: label.endsWith('Credentials'), reason: 'no such line' }
  if (label.startsWith('verify harm: ')) return { refuted: false, reason: 'fine' }
  throw new Error(`unexpected agent ${label}`)
}
const parallel = thunks => Promise.all(thunks.map(t => Promise.resolve().then(t).catch(() => null)))
const pipeline = (items, ...stages) => Promise.all(items.map(async (item, i) => {
  let r = item
  for (const stage of stages) { try { r = await stage(r, item, i) } catch { return null } }
  return r
}))

const args = {
  today: '2026-10-31',
  focus: '',
  models: { read: 'sonnet', judge: 'opus' },
  maxProposals: 1,
  runs: ['b1', 'b2', 'b3', 'b4', 'b5'].map((b, i) => ({ branch: b, date: `2026-10-0${i + 1}`, record: `reports/runs/${b}.tsv`, state: `.work/${b}.md`, evidence: [] })),
  improvements: [
    { date: '2026-09-30', change: 'one base', metric: 'wrong base rounds', before: '2' },
    { date: '2026-10-03', change: 'later change', metric: 'm', before: '1' },
  ],
}

const res = await run(args, agent, parallel, pipeline, m => logs.push(m), () => {}, { total: null })

same(res.agents, 16, 'agents counted')
same(calls.length, 16, 'agents started')
check(calls.every(o => o.agentType === 'Explore'), 'every agent is read-only (Explore)')
same([...new Set(calls.filter(o => o.phase === 'Read').map(o => o.model))], ['sonnet'], 'readers use the read model')
same([...new Set(calls.filter(o => o.phase !== 'Read').map(o => o.model))], ['opus'], 'everything else uses the judge model')
const titles = meta.phases.map(p => p.title)
check(calls.every(o => titles.includes(o.phase)), `every agent phase is in meta.phases (${titles.join(', ')})`)
same(res.unread, ['b5'], 'a run without an answer is reported')
same(res.events, 8, 'events from the four answering runs')
same(res.causes.map(c => c.title), ['Flaky e2e', 'Secret scan', 'Wrong base', 'Credentials'], 'causes ranked by rounds, then tokens; ghost cause gone')
same(res.causes.find(c => c.title === 'Flaky e2e').runs, ['b3', 'b4'], 'runs of a cause')
same(res.causes.find(c => c.title === 'Secret scan').rounds, 3, 'rounds of a cause summed by code')
same(res.notEnoughData.map(c => c.title), ['Odd hotfix'], 'one non-env event is below the minimum')
same(res.proposals.map(p => p.title), ['Fix Flaky e2e'], 'only maxProposals verified proposals')
same(res.overLimit, ['Fix Secret scan'], 'verified proposals over the limit are listed')
same(res.proposals[0].evidenceNote, 'no such line', 'a proposal carries the evidence check note, which may correct its numbers')
same(res.dropped.map(d => [d.cause, d.reasons]), [['Credentials', ['evidence: no such line']]], 'a refuted proposal is dropped with its reason')
check(!calls.some(o => o.label === 'propose: Wrong base'), 'an addressed cause gets no proposal')
same(res.earlier.map(e => [e.date, e.verdict]), [['2026-09-30', 'kept'], ['2026-10-03', 'too early']], 'earlier changes: checked and too early')
check(logs.some(l => l.includes('too early')), 'too early is logged')

let threw = false
try { await run({ runs: [] }, agent, parallel, pipeline, () => {}, () => {}, {}) } catch { threw = true }
check(threw, 'no runs is an error')

console.log(out.join('\n'))
EOF

node "$work/harness.mjs" >"$work/result.txt" 2>"$work/harness.err" || fail "the harness crashed: $(cat "$work/harness.err")"
while IFS= read -r line; do
  case $line in
    ok) ok ;;
    FAIL:*) fail "${line#FAIL: }" ;;
  esac
done <"$work/result.txt"

echo "improve-workflow: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
