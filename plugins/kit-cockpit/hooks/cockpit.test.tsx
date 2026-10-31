import { expect, test } from 'claude-code/testing'
import type { Plugin } from 'claude-code/testing'

import {
  COCKPIT_COMMAND,
  PANE,
  START,
  SURFACES,
  activeRun,
  exitedWith,
  fakeKit,
  kitStatus,
} from './fake-kit'

const SECTIONS = ['Criteria', 'Tasks', 'Stops', 'Rounds', 'Decisions to review', 'Evidence', 'Autopilot']
const MISSING_KIT =
  "kit-cockpit needs the Agentic Workflow Kit 0.3.0 or newer. Run ./install.sh <project> --update from the kit's repository."
const CLOSER = {
  name: 'pane-closer',
  tier: 'append',
  register(on) {
    on('command.run', { command: 'close-cockpit' }, async $ => {
      await $.ui.close({ id: 'cockpit' })
      return { text: 'closed' }
    })
  },
} as const satisfies Plugin
const CLOSE_COMMAND = { ...COCKPIT_COMMAND, command: 'close-cockpit' } as const

const SEVEN_TASKS = {
  done: 3,
  total: 7,
  items: [1, 2, 3, 4, 5, 6, 7].map(n => ({ text: `${n} task ${n}`, done: n <= 3 })),
}

test('COCKPIT-AC24: /cockpit opens one Cockpit pane with the seven sections in order', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)

  await $.command.run(COCKPIT_COMMAND)

  expect(kit.opened).toEqual([{ id: 'cockpit', title: 'Cockpit' }])
  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    const texts = (await ui.findAll({ type: 'Text' })).map(found => found.text)
    expect(texts.filter(text => SECTIONS.includes(text))).toEqual(SECTIONS)
    await ui.unmount()
  }
})

test('COCKPIT-AC25: a red criterion shows red next to its test name', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(
    exitedWith(
      kitStatus({
        criteria: [
          { id: 'INVITE-AC1', state: 'green', tests: ['AC1: sends an invite'] },
          { id: 'INVITE-AC2', state: 'red', tests: ['AC2: rejects a duplicate email'] },
          { id: 'INVITE-AC3', state: 'open', tests: [] },
        ],
      }),
    ),
  )
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    const row = await ui.find({ type: 'Text', text: /INVITE-AC2/ })
    expect(row?.text).toMatch(/INVITE-AC2 red\b.*AC2: rejects a duplicate email/)
    expect((await ui.find({ type: 'Text', text: /INVITE-AC3/ }))?.text).toBe('INVITE-AC3 open')
    await ui.unmount()
  }
})

test('COCKPIT-AC26: the Tasks section shows every task with its mark', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ tasks: SEVEN_TASKS })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    const ticked = await ui.findAll({ type: 'Text', text: /^\[x\] \d task/ })
    const open = await ui.findAll({ type: 'Text', text: /^\[ \] \d task/ })
    expect(ticked.map(found => found.text)).toEqual(['[x] 1 task 1', '[x] 2 task 2', '[x] 3 task 3'])
    expect(open).toHaveLength(4)
    await ui.unmount()
  }
})

test('COCKPIT-AC27: an empty Stops section shows none', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ stops: [], rounds: ['review 1 | 2 findings'] })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    const texts = (await ui.findAll({ type: 'Text' })).map(found => found.text)
    expect(texts[texts.indexOf('Stops') + 1]).toBe('none')
    expect(texts[texts.indexOf('Rounds') + 1]).toBe('review 1 | 2 findings')
    await ui.unmount()
  }
})

test('COCKPIT-AC27: a branch without a feature says so and keeps the Autopilot section', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ line: '', feature: null, stage: null, autopilot: activeRun('a') })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ type: 'Text', text: 'No feature on this branch.' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^current: a · build$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Criteria' })).toBeUndefined()
    await ui.unmount()
  }
})

test('COCKPIT-AC28: the open pane follows the autopilot to its next feature on its own', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('b') })))

  await kit.clock.advance(10_000)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ type: 'Text', text: /^current: b · build$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^done-one PR opened$/ })).toBeDefined()
    await ui.unmount()
  }
})

test('COCKPIT-AC28: the poll stops once the run is no longer active', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  kit.answer(exitedWith(kitStatus({ autopilot: { ...activeRun('a'), active: false } })))
  await kit.clock.advance(5000)
  const runsWhenIdle = kit.runs.length

  await kit.clock.advance(20_000)

  expect(kit.runs).toHaveLength(runsWhenIdle)
})

test('COCKPIT-AC45: without the kit status command the pane says how to update the kit', async ($, on) => {
  fakeKit(on, { isInstalled: false })
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /kit-cockpit needs/ }))?.text).toBe(MISSING_KIT)
    await ui.unmount()
  }
})

test('COCKPIT-AC47: the pane shows the first line of the error output', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  kit.answer({ exited: 3, stderr: '\ncannot read specs/README.md\nsecond line\n' })

  await $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' })

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ type: 'Text', text: 'cannot read specs/README.md' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /second line/ })).toBeUndefined()
    await ui.unmount()
  }
})

test('COCKPIT-AC48: an empty error output names the exit code', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer({ exited: 3, stderr: '' })
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ type: 'Text', text: 'status exited with code 3' })).toBeDefined()
    await ui.unmount()
  }
})

test('COCKPIT-AC50: a status command that outlasts 5 s shows the timeout in the pane', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  kit.answer({ deniedAfterMs: 5000, reason: 'process timed out' })

  const opening = $.command.run(COCKPIT_COMMAND)
  await kit.clock.advance(5000)
  await opening

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ type: 'Text', text: 'status timed out after 5 s' })).toBeDefined()
    await ui.unmount()
  }
})

test('COCKPIT-AC50: a status command that cannot start shows its reason', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  kit.answer({ deniedAfterMs: 0, reason: 'permission denied' })

  await $.command.run(COCKPIT_COMMAND)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ type: 'Text', text: /permission denied/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /timed out/ })).toBeUndefined()
    await ui.unmount()
  }
})

test('COCKPIT-AC51: with the pane closed an active run is not polled', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)

  await kit.clock.advance(5000)

  expect(kit.runs).toHaveLength(1)
})

test('COCKPIT-AC51: closing the pane stops the poll', { plugins: [CLOSER] }, async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  await $.command.run(CLOSE_COMMAND)
  const runsAtClose = kit.runs.length

  await kit.clock.advance(15_000)

  expect(kit.runs).toHaveLength(runsAtClose)
})

test('COCKPIT-AC52: an open pane without an active run is not polled', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ autopilot: { ...activeRun('a'), active: false } })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await kit.clock.advance(5000)

  expect(kit.runs).toHaveLength(2)
})

test('COCKPIT-AC52: an open pane with no autopilot log is not polled', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await kit.clock.advance(5000)

  expect(kit.runs).toHaveLength(2)
})

test('COCKPIT-AC53: running /cockpit again keeps one pane and one poll', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  await $.command.run(COCKPIT_COMMAND)
  const runsAfterOpens = kit.runs.length

  await kit.clock.advance(5000)

  expect(new Set(kit.opened.map(pane => pane.id))).toEqual(new Set(['cockpit']))
  expect(kit.runs).toHaveLength(runsAfterOpens + 1)
})

test('COCKPIT-AC53: a reload with the pane still open polls the active run again', async ($, on) => {
  const kit = fakeKit(on, { openPanes: ['cockpit'] })
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)

  await kit.clock.advance(5000)

  expect(kit.runs).toHaveLength(2)
})
