export const meta = {
  name: 'improve-kit',
  description: 'Find why recorded kit runs lost rounds and tokens, check earlier kit changes, and propose verified kit changes',
  whenToUse: 'Started by /improve-kit deep, which builds the run list it needs as args',
  phases: [
    { title: 'Read', detail: 'one read-only agent per recorded run' },
    { title: 'Earlier changes', detail: 'one agent per improvements entry with three or more runs after it' },
    { title: 'Cluster', detail: 'group the events of all runs into causes' },
    { title: 'Propose', detail: 'one proposed kit change per open cause' },
    { title: 'Verify', detail: 'an evidence check and a harm check per proposal' },
  ],
}

const MAX_CAUSES = 8
const MIN_RUNS_AFTER = 3
const KINDS = ['stop', 'review-finding', 'verify-failure', 'decision']
const CLASSES = ['spec', 'plan', 'tier', 'test', 'hotfix', 'kit', 'env', 'budget', 'none']
const AREAS = ['hook', 'guard', 'check', 'rule', 'skill', 'routing', 'test-stack', 'product', 'other']

const EVENTS = {
  type: 'object',
  properties: {
    events: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          kind: { type: 'string', enum: KINDS },
          class: { type: 'string', enum: CLASSES },
          cause: { type: 'string' },
          rounds: { type: 'number' },
          tokens: { type: 'number' },
          evidence: { type: 'string' },
          area: { type: 'string', enum: AREAS },
        },
        required: ['kind', 'class', 'cause', 'rounds', 'evidence', 'area'],
      },
    },
  },
  required: ['events'],
}

const EARLIER = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['kept', 'revert', 'too early'] },
    before: { type: 'string' },
    now: { type: 'string' },
    reason: { type: 'string' },
  },
  required: ['verdict', 'before', 'now', 'reason'],
}

const CAUSES = {
  type: 'object',
  properties: {
    causes: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          area: { type: 'string', enum: AREAS },
          summary: { type: 'string' },
          eventIds: { type: 'array', items: { type: 'string' } },
          alreadyAddressedBy: { type: 'string' },
        },
        required: ['title', 'area', 'summary', 'eventIds', 'alreadyAddressedBy'],
      },
    },
  },
  required: ['causes'],
}

const PROPOSAL = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    observation: { type: 'string' },
    change: { type: 'string' },
    files: { type: 'array', items: { type: 'string' } },
    expectedEffect: { type: 'string' },
    measure: { type: 'string' },
  },
  required: ['title', 'observation', 'change', 'files', 'expectedEffect', 'measure'],
}

const VERDICT = {
  type: 'object',
  properties: { refuted: { type: 'boolean' }, reason: { type: 'string' } },
  required: ['refuted', 'reason'],
}

const input = typeof args === 'string' ? JSON.parse(args) : args
if (!input || !Array.isArray(input.runs) || input.runs.length === 0) {
  throw new Error('improve-kit needs args.runs: one entry per reports/runs/*.tsv, built by /improve-kit deep')
}
const runs = input.runs
const improvements = input.improvements || []
const models = input.models || {}
const focus = (input.focus || '').trim()
const maxProposals = input.maxProposals || 5
let agents = 0

function readOnly(model, phase, label, schema) {
  agents++
  const opts = { agentType: 'Explore', phase, label, schema }
  if (model) opts.model = model
  return opts
}

const CLASS_GUIDE = `Stop classes (from /ship-feature): spec (the spec was wrong or unclear), plan (task too big, wrong order, missing anchor), tier (model too weak, retried a tier higher), test (flaky or wrong test or test setup), hotfix (product wrong, spec right), kit (a hook, the guard, a check command or a rule was wrong or blocked something harmless), env (dependency, network, credentials, a human-only step), budget (token budget blocked a dispatch). Use none when no class fits.`

function readPrompt(run) {
  return [
    `You analyse one recorded feature run of the agentic workflow kit. Branch: ${run.branch}, date ${run.date}.`,
    `Read these files completely (skip a path that does not exist):`,
    `- run record: ${run.record}`,
    run.state ? `- state file: ${run.state} (sections Stops, Rounds, Decisions to review, Notes, Verify log)` : '- state file: none recorded',
    ...(run.evidence || []).map(p => `- evidence: ${p}`),
    run.pr ? `- pull request #${run.pr}: you may read its review comments with \`gh pr view ${run.pr} --comments\`` : '',
    '',
    'Return every event that cost a review round, a verify round, a retry, a stop, or a workaround: each Stops line, each failed review or verify round with what failed, each high review finding, and each decision that worked around the kit.',
    'Do not return passing rounds or events that cost nothing.',
    CLASS_GUIDE,
    'area: where the cause lives. hook, guard, check (a check command or gate of .claude/bin), rule (.claude/rules or CLAUDE.md), skill (a skill or agent instruction), routing (model tiers), test-stack (seed, e2e, screenshots, test infrastructure), product (the application code itself), other.',
    'cause: one sentence naming the root cause, not the symptom. rounds: how many review or verify rounds this event cost (0 if none). tokens: only when the files state them.',
    'evidence: path:line of the line that shows it. Report only what the files show. Never guess a number.',
  ].filter(Boolean).join('\n')
}

function earlierPrompt(entry, after, before) {
  return [
    `An earlier change to the agentic workflow kit, logged on ${entry.date}: "${entry.change}".`,
    `The metric to judge it by: "${entry.metric}". Its value before the change: "${entry.before}".`,
    `Runs after the change (${after.length}):`,
    ...after.map(r => `- ${r.branch} (${r.date}): ${r.record}${r.state ? `, ${r.state}` : ''}`),
    `Runs before it, for comparison (${before.length}):`,
    ...before.map(r => `- ${r.branch} (${r.date}): ${r.record}${r.state ? `, ${r.state}` : ''}`),
    '',
    'Measure the metric over the runs after the change from these files. now: the value with the runs it comes from.',
    'verdict: kept when the metric moved the expected way, revert when it did not or got worse, too early when the files cannot show the metric.',
    'Quote path:line for every number in reason.',
  ].join('\n')
}

function clusterPrompt(events) {
  return [
    'Group these events from recorded kit runs into root causes. One cause can span many runs. An event belongs to at most one cause.',
    focus ? `The user asked to focus on "${focus}". Return only causes related to it.` : '',
    'Events (id | run | kind | class | area | rounds | cause | evidence):',
    ...events.map(e => `${e.id} | ${e.run} | ${e.kind} | ${e.class} | ${e.area} | ${e.rounds} | ${e.cause} | ${e.evidence}`),
    '',
    'Earlier kit changes (date | change | metric):',
    ...(improvements.length ? improvements.map(i => `${i.date} | ${i.change} | ${i.metric}`) : ['none']),
    '',
    'alreadyAddressedBy: the date and change of the earlier kit change that already targets this cause, or an empty string. Read the kit files under .claude/ when you need to confirm that the current kit handles it.',
    'Leave out causes whose events are all of area product and class hotfix: those are product defects the review found, which is the kit working.',
  ].filter(Boolean).join('\n')
}

function proposePrompt(cause) {
  return [
    'Propose one change to the agentic workflow kit (files under .claude/: skills, agents, rules, hooks, .claude/bin scripts, kit.conf) that removes this cause.',
    `Cause: ${cause.title}. ${cause.summary}`,
    `Area: ${cause.area}. Cost: ${cause.rounds} rounds in ${cause.runs.length} runs (${cause.runs.join(', ')}).`,
    'Events:',
    ...cause.events.map(e => `- ${e.id}: ${e.cause} (${e.evidence})`),
    '',
    'Read the kit files involved before you propose. Prefer turning a recurring finding into a check (lint rule, hook, CI step) over a longer rule.',
    'Never propose to relax a threshold, a key format, a hook, the guard or a strict path, never touch application code, never change an approved spec.',
    'observation: the numbers and the runs. change: the file and the exact change. expectedEffect: which metric moves and which way. measure: the metric to watch and its value now.',
  ].join('\n')
}

function evidencePrompt(cause, proposal) {
  return [
    'Try to refute this proposed kit change on its evidence.',
    `Cause: ${cause.title}. Observation: ${proposal.observation}`,
    'Cited events:',
    ...cause.events.map(e => `- ${e.id}: ${e.cause} (${e.evidence})`),
    '',
    'Open every cited path. refuted=true when the events, taken together, do not show this cause: most cited lines are missing or say something else, or the events show a different cause. If you cannot confirm the cause at all, refuted=true.',
    'A miscounted number or one event that belongs elsewhere does not refute the cause. Then refuted=false, and reason gives the corrected numbers and the event to drop.',
  ].join('\n')
}

function harmPrompt(proposal) {
  return [
    'Try to refute this proposed change to the agentic workflow kit on its harm.',
    `Change: ${proposal.change}`,
    `Files: ${proposal.files.join(', ')}`,
    '',
    'Read the current versions of those files. The kit forbids changes that relax a threshold, a key format, a hook, the guard, a protected or strict path, weaken a test, change an approved spec, or touch application code.',
    'refuted=true when the change does any of that, or would let a defect pass that the kit catches today. Otherwise refuted=false.',
  ].join('\n')
}

const due = improvements.map(entry => ({
  entry,
  after: runs.filter(r => r.date > entry.date),
  before: runs.filter(r => r.date <= entry.date),
}))
const tooEarly = due.filter(d => d.after.length < MIN_RUNS_AFTER)
const toCheck = due.filter(d => d.after.length >= MIN_RUNS_AFTER)
if (tooEarly.length) log(`${tooEarly.length} earlier changes have fewer than ${MIN_RUNS_AFTER} runs after them: too early, not checked`)

const [perRun, checked] = await parallel([
  () => pipeline(runs, run => agent(readPrompt(run), readOnly(models.read, 'Read', `read: ${run.branch}`, EVENTS))),
  () => parallel(toCheck.map(d => () =>
    agent(earlierPrompt(d.entry, d.after, d.before), readOnly(models.judge, 'Earlier changes', `earlier: ${d.entry.date}`, EARLIER))
      .then(v => ({ ...d.entry, runsAfter: d.after.length, ...(v || { verdict: 'too early', before: d.entry.before, now: '', reason: 'the check agent returned nothing' }) })))),
])

const unread = runs.filter((r, i) => !perRun || !perRun[i])
if (unread.length) log(`no events from ${unread.length} runs: ${unread.map(r => r.branch).join(', ')}`)
const events = runs.flatMap((run, i) =>
  ((perRun && perRun[i] && perRun[i].events) || []).map((e, j) => ({ ...e, tokens: e.tokens || 0, id: `${run.branch}#${j + 1}`, run: run.branch })))
const byId = new Map(events.map(e => [e.id, e]))
log(`${events.length} events from ${runs.length - unread.length} runs`)

const earlier = [
  ...(checked || []).filter(Boolean),
  ...tooEarly.map(d => ({ ...d.entry, runsAfter: d.after.length, verdict: 'too early', before: d.entry.before, now: '', reason: `${d.after.length} runs after it, ${MIN_RUNS_AFTER} needed` })),
]

let causes = []
if (events.length) {
  const grouped = await agent(clusterPrompt(events), readOnly(models.judge, 'Cluster', 'cluster', CAUSES))
  const claimed = new Set()
  causes = ((grouped && grouped.causes) || []).map(c => {
    const own = c.eventIds.filter(id => byId.has(id) && !claimed.has(id))
    own.forEach(id => claimed.add(id))
    const evs = own.map(id => byId.get(id))
    return {
      title: c.title, area: c.area, summary: c.summary, alreadyAddressedBy: c.alreadyAddressedBy,
      events: evs,
      runs: [...new Set(evs.map(e => e.run))],
      rounds: evs.reduce((s, e) => s + (e.rounds || 0), 0),
      tokens: evs.reduce((s, e) => s + (e.tokens || 0), 0),
    }
  }).filter(c => c.events.length)
}

const minimum = c => (c.events.some(e => e.class === 'env') ? 1 : 2)
const byCost = (a, b) => b.rounds - a.rounds || b.tokens - a.tokens || b.events.length - a.events.length
const notEnoughData = causes.filter(c => c.events.length < minimum(c))
const addressed = causes.filter(c => c.events.length >= minimum(c) && c.alreadyAddressedBy)
const open = causes.filter(c => c.events.length >= minimum(c) && !c.alreadyAddressedBy).sort(byCost)
const toPropose = open.slice(0, MAX_CAUSES)
const notProposed = open.slice(MAX_CAUSES)
if (notProposed.length) log(`${notProposed.length} open causes beyond the top ${MAX_CAUSES} get no proposal: ${notProposed.map(c => c.title).join('; ')}`)

const reviewed = await pipeline(
  toPropose,
  cause => agent(proposePrompt(cause), readOnly(models.judge, 'Propose', `propose: ${cause.title}`, PROPOSAL)),
  (proposal, cause) => proposal && parallel([
    () => agent(evidencePrompt(cause, proposal), readOnly(models.judge, 'Verify', `verify evidence: ${cause.title}`, VERDICT)),
    () => agent(harmPrompt(proposal), readOnly(models.judge, 'Verify', `verify harm: ${cause.title}`, VERDICT)),
  ]).then(([evidence, harm]) => ({ cause, proposal, evidence, harm })),
)

const results = reviewed.filter(Boolean)
const survives = r => r.evidence && r.harm && !r.evidence.refuted && !r.harm.refuted
const kept = results.filter(survives).sort((a, b) => byCost(a.cause, b.cause))
const dropped = results.filter(r => !survives(r)).map(r => ({
  title: r.proposal.title,
  cause: r.cause.title,
  reasons: [
    !r.evidence ? 'evidence check returned nothing' : r.evidence.refuted ? `evidence: ${r.evidence.reason}` : '',
    !r.harm ? 'harm check returned nothing' : r.harm.refuted ? `harm: ${r.harm.reason}` : '',
  ].filter(Boolean),
}))
const overLimit = kept.slice(maxProposals)
if (overLimit.length) log(`${overLimit.length} verified proposals beyond the limit of ${maxProposals}: ${overLimit.map(r => r.proposal.title).join('; ')}`)

const summary = c => ({ title: c.title, area: c.area, summary: c.summary, rounds: c.rounds, tokens: c.tokens, runs: c.runs, alreadyAddressedBy: c.alreadyAddressedBy, evidence: c.events.map(e => `${e.id}: ${e.evidence}`) })

return {
  today: input.today,
  focus,
  agents,
  runsRead: runs.length - unread.length,
  unread: unread.map(r => r.branch),
  events: events.length,
  earlier,
  causes: [...open, ...addressed].sort(byCost).map(summary),
  proposals: kept.slice(0, maxProposals).map(r => ({ ...r.proposal, cause: r.cause.title, rounds: r.cause.rounds, runs: r.cause.runs, evidenceNote: r.evidence.reason })),
  overLimit: overLimit.map(r => r.proposal.title),
  notProposed: notProposed.map(summary),
  dropped,
  notEnoughData: notEnoughData.map(summary),
}
