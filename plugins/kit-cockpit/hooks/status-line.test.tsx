import { expect, test } from 'claude-code/testing'

import {
  COCKPIT_COMMAND,
  START,
  STATUS_ARGV,
  exitedWith,
  fakeKit,
  kitStatus,
  mainTurnEnd,
} from './fake-kit'

test('COCKPIT-AC21: a session start shows the status command line', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ line: 'invite-users · build · tasks 3/7 · 1 red · budget 42%' })))

  await $.session.start(START)

  expect(kit.runs.map(run => run.argv)).toEqual([STATUS_ARGV])
  expect(kit.shownStatus()).toBe('invite-users · build · tasks 3/7 · 1 red · budget 42%')
})

test('COCKPIT-AC21: a branch without a feature leaves the status line empty', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ line: '', feature: null, stage: null })))

  await $.session.start(START)

  expect(kit.runs).toHaveLength(1)
  expect(kit.shownStatus()).toBeUndefined()
})

const STATE_FILE = '/project/.work/invite-users.md'
const FINISHING_CALLS = [
  { tool: 'Edit', file_path: STATE_FILE, old_string: '- [ ] 4', new_string: '- [x] 4' },
  { tool: 'Write', file_path: STATE_FILE, content: '- [x] 4 task 4' },
  { tool: 'Agent', description: 'Implement task 4', prompt: 'Build task 4' },
] as const

for (const call of FINISHING_CALLS) {
  test(`COCKPIT-AC22: a finished ${call.tool} call refreshes the status line`, async ($, on) => {
    const kit = fakeKit(on)
    kit.answer(exitedWith(kitStatus({ line: 'invite-users · build · tasks 3/7' })))
    await $.session.start(START)
    kit.whileToolRuns(() => kit.answer(exitedWith(kitStatus({ line: 'invite-users · build · tasks 4/7' }))))

    await $.tool.call(call)

    expect(kit.shownStatus()).toBe('invite-users · build · tasks 4/7')
  })
}

test('COCKPIT-AC22: a Read call does not run the status command', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)

  await $.tool.call({ tool: 'Read', file_path: '/project/specs/README.md' })

  expect(kit.runs).toHaveLength(1)
})

test('COCKPIT-AC23: the end of a main turn shows the state after the turn', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ line: 'invite-users · build · tasks 3/7' })))
  await $.session.start(START)
  kit.answer(exitedWith(kitStatus({ line: 'invite-users · review · tasks 7/7' })))

  await $.turn.complete(mainTurnEnd('turn-1'))

  expect(kit.shownStatus()).toBe('invite-users · review · tasks 7/7')
})

test('COCKPIT-AC23: a slower earlier refresh does not overwrite a newer one', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  kit.answerInOrder(
    exitedWith(kitStatus({ line: 'invite-users · build · tasks 3/7' }), 3000),
    exitedWith(kitStatus({ line: 'invite-users · build · tasks 4/7' })),
  )

  const slower = $.turn.complete(mainTurnEnd('turn-1'))
  await $.turn.complete(mainTurnEnd('turn-2'))
  await kit.clock.advance(3000)
  await slower

  expect(kit.runs).toHaveLength(3)
  expect(kit.shownStatus()).toBe('invite-users · build · tasks 4/7')
})

test('COCKPIT-AC23: the end of a subagent turn does not run the status command', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)

  await $.turn.complete({ ...mainTurnEnd('turn-2'), agentId: 'agent-1' })

  expect(kit.runs).toHaveLength(1)
})

test('COCKPIT-AC44: without the kit status command the status line stays empty', async ($, on) => {
  const kit = fakeKit(on, { isInstalled: false })

  await $.session.start(START)

  expect(kit.runs).toHaveLength(0)
  expect(kit.statusLines).toEqual([undefined])
})

test('COCKPIT-AC46: a non-zero exit shows cockpit: error', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer({ exited: 3, stderr: 'cannot read specs/README.md\n' })

  await $.session.start(START)

  expect(kit.shownStatus()).toBe('cockpit: error')
})

test('COCKPIT-AC46: output that is not JSON shows cockpit: error', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer({ exited: 0, stdout: 'usage: status [--line]' })

  await $.session.start(START)

  expect(kit.shownStatus()).toBe('cockpit: error')
})

const UNEXPECTED_SHAPES = [
  { name: 'without line, criteria and autopilot', json: { stage: 'build', tasks: null } },
  { name: 'with a line that is no string', json: { ...kitStatus(), line: 3 } },
  { name: 'with criteria that are no list', json: { ...kitStatus(), criteria: {} } },
  { name: 'with an autopilot without features', json: { ...kitStatus(), autopilot: { active: true } } },
  { name: 'that is a list', json: [] },
] as const

for (const shape of UNEXPECTED_SHAPES) {
  test(`COCKPIT-AC58: JSON ${shape.name} shows cockpit: error`, async ($, on) => {
    const kit = fakeKit(on)
    kit.answer({ exited: 0, stdout: JSON.stringify(shape.json) })

    await $.session.start(START)

    expect(kit.shownStatus()).toBe('cockpit: error')
  })
}

test('COCKPIT-AC49: a status command that outlasts 5 s shows cockpit: error', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer({ deniedAfterMs: 5000, reason: 'process timed out' })

  const started = $.session.start(START)
  await kit.clock.advance(5000)
  await started

  expect(kit.runs[0]?.timeoutMs).toBe(5000)
  expect(kit.shownStatus()).toBe('cockpit: error')
})

test('COCKPIT-AC54: ten refreshes and the pane run only the status command and write nothing', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  for (let turn = 0; turn < 9; turn += 1) {
    await $.turn.complete(mainTurnEnd(`turn-${turn}`))
  }

  await $.command.run(COCKPIT_COMMAND)

  expect(kit.runs).toHaveLength(11)
  expect(kit.runs.every(run => run.argv.join(' ') === STATUS_ARGV.join(' '))).toBe(true)
  expect(kit.writes).toEqual([])
})
