import { expect, test } from 'claude-code/testing'
import type { Plugin } from 'claude-code/testing'

import {
  COCKPIT_COMMAND,
  START,
  activeRun,
  exitedWith,
  fakeKit,
  forEachSurface,
  kitStatus,
  shownTexts,
} from './fake-kit'

const SECTIONS = ['Criteria', 'Tasks', 'Stops', 'Rounds', 'Decisions to review', 'Evidence', 'Autopilot']
const MISSING_KIT =
  "kit-cockpit needs the Agentic Workflow Kit 0.3.0 or newer. Run ./install.sh <project> --update from the kit's repository."
const RUN_LOG = 'run-20261031-230000.md'
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
  await forEachSurface($, async ui => {
    const texts = await shownTexts(ui)
    expect(texts.filter(text => SECTIONS.includes(text))).toEqual(SECTIONS)
  })
})

test('COCKPIT-AC24: the header shows the stage badge, the stage rail and the meters', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(
    exitedWith(
      kitStatus({
        tasks: SEVEN_TASKS,
        criteria: [
          { id: 'INVITE-AC1', state: 'green', tests: ['AC1: sends an invite'] },
          { id: 'INVITE-AC2', state: 'red', tests: ['AC2: rejects a duplicate email'] },
          { id: 'INVITE-AC3', state: 'open', tests: [] },
        ],
        budget: { used: 84300, limit: 200000, percent: 42 },
        red: 1,
      }),
    ),
  )
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface($, async ui => {
    expect(await ui.find({ type: 'Text', text: ' BUILD ' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^● ─+ ● ─+ ◉ ─+ ○ ─+ ○ ─+ ○ ─+ ○$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^spec +plan +build +review +verify +pr +done$/ })).toBeDefined()
    const meters = (await shownTexts(ui)).filter(text => /^(tasks|criteria|budget|checks) +(█|░|\d+ red)/.test(text))
    expect(meters).toHaveLength(4)
    const bars = meters.slice(0, 3).map(meter => meter.indexOf(' ', 9) - 9)
    expect(new Set(bars).size).toBe(1)
    expect(meters[1]).toHaveLength(76)
    expect(meters[1]).toMatch(/1✓ 1✗ 1○$/)
    expect(meters[2]).toMatch(/ 42%$/)
    expect(meters[3]).toMatch(/1 red this turn$/)
  })
})

test('COCKPIT-AC24: a narrow pane keeps the rail on one row and drops its labels', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ tasks: SEVEN_TASKS })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface(
    $,
    async ui => {
      const rail = await ui.find({ type: 'Text', text: /◉/ })
      expect(rail?.text).toHaveLength(36)
      expect(await ui.find({ type: 'Text', text: /review +verify/ })).toBeUndefined()
      const meter = await ui.find({ type: 'Text', text: /^tasks +█/ })
      expect(meter?.text).toHaveLength(36)
    },
    40,
  )
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
          { id: 'INVITE-AC4', state: 'open', tests: [] },
        ],
      }),
    ),
  )
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface($, async ui => {
    const row = await ui.find({ type: 'Text', text: /INVITE-AC2/ })
    expect(row?.text).toMatch(/INVITE-AC2 red\b.*AC2: rejects a duplicate email/)
    expect(await ui.find({ type: 'Text', text: '1 red' })).toBeDefined()
    expect((await ui.find({ type: 'Text', text: /INVITE-AC3/ }))?.text).toBe(
      '○ 2 open without a test: INVITE-AC3, INVITE-AC4',
    )
  })
})

test('COCKPIT-AC26: the Tasks section shows every task with its mark', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ tasks: SEVEN_TASKS })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface($, async ui => {
    const ticked = await ui.findAll({ type: 'Text', text: /^ {2}☑ \d task \d$/ })
    const open = await ui.findAll({ type: 'Text', text: /^(▸| ) ☐ \d task \d$/ })
    expect(ticked.map(found => found.text)).toEqual(['  ☑ 1 task 1', '  ☑ 2 task 2', '  ☑ 3 task 3'])
    expect(open.map(found => found.text)).toEqual(['▸ ☐ 4 task 4', '  ☐ 5 task 5', '  ☐ 6 task 6', '  ☐ 7 task 7'])
  })
})

test('COCKPIT-AC27: an empty Stops section shows none', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ stops: [], rounds: ['review 1 | 2 findings'] })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface($, async ui => {
    const texts = await shownTexts(ui)
    expect(texts[texts.indexOf('Stops') + 1]).toBe('none')
    expect(texts.slice(texts.indexOf('Rounds'), texts.indexOf('Decisions to review'))).not.toContain('none')
    expect(await ui.find({ type: 'Text', text: /^review 1 +✗ 2 findings$/ })).toBeDefined()
  })
})

test('COCKPIT-AC27: stops, rounds and decisions show their fields', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(
    exitedWith(
      kitStatus({
        stops: ['build 3 | tier | settle loop timed out | retried on deep | passed'],
        rounds: ['review 1 | full | main..a1 | pass', 'verify 1 | delta | a1..b2 | fail: test'],
        decisions: ['plan | Greedy settle | at most n-1 transfers'],
      }),
    ),
  )
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface($, async ui => {
    expect(await ui.find({ type: 'Text', text: 'tier  build 3  settle loop timed out' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^review 1 full +✓ pass$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^verify 1 delta +✗ fail: test$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'plan  Greedy settle' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^ +at most n-1 transfers$/ })).toBeDefined()
  })
})

test('COCKPIT-AC56: a branch without a feature says so and shows only the Autopilot section', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ line: '', feature: null, stage: null, autopilot: null })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface($, async ui => {
    const texts = await shownTexts(ui)
    expect(texts.indexOf('No feature on this branch.')).toBeGreaterThanOrEqual(0)
    expect(texts.indexOf('No feature on this branch.')).toBeLessThan(texts.indexOf('Autopilot'))
    expect(texts.filter(text => SECTIONS.includes(text))).toEqual(['Autopilot'])
  })
})

test('COCKPIT-AC56: a branch without a feature still shows the autopilot run', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ line: '', feature: null, stage: null, autopilot: activeRun('a') })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface($, async ui => {
    expect(await ui.find({ type: 'Text', text: /^▸ a {2}plan ━▶ build$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '● live' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Criteria' })).toBeUndefined()
  })
})

test('COCKPIT-AC28: the open pane follows the autopilot to its next feature on its own', async ($, on) => {
  const kit = fakeKit(on)
  kit.autopilotWrites(RUN_LOG)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('b') })))
  kit.autopilotWrites('20261031-230000-b-build.jsonl')

  await kit.clock.advance(10_000)

  await forEachSurface($, async ui => {
    expect(await ui.find({ type: 'Text', text: /^▸ b {2}plan ━▶ build$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^• done-one {2}PR opened$/ })).toBeDefined()
  })
})

test('COCKPIT-AC28: once the folder stops changing the status command does not run', async ($, on) => {
  const kit = fakeKit(on)
  kit.autopilotWrites(RUN_LOG)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  kit.answer(exitedWith(kitStatus({ autopilot: { ...activeRun('a'), active: false } })))
  kit.autopilotWrites(RUN_LOG)
  await kit.clock.advance(5000)
  const runsWhenIdle = kit.runs.length

  await kit.clock.advance(20_000)

  expect(runsWhenIdle).toBe(3)
  expect(kit.runs).toHaveLength(runsWhenIdle)
})

test('COCKPIT-AC57: a run that starts after the pane opened shows within 10 s', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('export-csv') })))
  kit.autopilotWrites(RUN_LOG)

  await kit.clock.advance(10_000)

  await forEachSurface($, async ui => {
    expect(await ui.find({ type: 'Text', text: /^▸ export-csv {2}plan ━▶ build$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '● live' })).toBeDefined()
  })
})

test('COCKPIT-AC57: the folder watch starts no second run while a status run hangs', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  kit.answer({ deniedAfterMs: 8000, reason: 'process timed out' })
  kit.autopilotWrites(RUN_LOG)
  await kit.clock.advance(5000)
  kit.autopilotWrites('20261031-230000-a-build.jsonl')

  await kit.clock.advance(5000)

  expect(kit.runs).toHaveLength(3)
})

test('COCKPIT-AC59: a live run whose log stops changing is read again after 60 s', async ($, on) => {
  const kit = fakeKit(on)
  kit.autopilotWrites(RUN_LOG)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  kit.answer(exitedWith(kitStatus({ autopilot: { ...activeRun('a'), active: false } })))

  await kit.clock.advance(60_000)

  expect(kit.runs).toHaveLength(3)
  await forEachSurface($, async ui => {
    expect(await ui.find({ type: 'Text', text: '● live' })).toBeUndefined()
  })
})

test('COCKPIT-AC58: JSON of another shape shows the reason in the pane', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer({ exited: 0, stdout: '{"stage":"build","tasks":null}\n' })
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface($, async ui => {
    expect(await ui.find({ type: 'Text', text: 'status printed an unexpected shape' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Criteria' })).toBeUndefined()
  })
})

test('COCKPIT-AC45: without the kit status command the pane says how to update the kit', async ($, on) => {
  fakeKit(on, { isInstalled: false })
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface($, async ui => {
    expect((await ui.find({ type: 'Text', text: /kit-cockpit needs/ }))?.text).toBe(MISSING_KIT)
  })
})

test('COCKPIT-AC47: the pane shows the first line of the error output', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  kit.answer({ exited: 3, stderr: '\ncannot read specs/README.md\nsecond line\n' })

  await $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' })

  await forEachSurface($, async ui => {
    expect(await ui.find({ type: 'Text', text: 'cannot read specs/README.md' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /second line/ })).toBeUndefined()
  })
})

test('COCKPIT-AC48: an empty error output names the exit code', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer({ exited: 3, stderr: '' })
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface($, async ui => {
    expect(await ui.find({ type: 'Text', text: 'status exited with code 3' })).toBeDefined()
  })
})

test('COCKPIT-AC50: a status command that outlasts 5 s shows the timeout in the pane', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  kit.answer({ deniedAfterMs: 5000, reason: 'process timed out' })

  const opening = $.command.run(COCKPIT_COMMAND)
  await kit.clock.advance(5000)
  await opening

  await forEachSurface($, async ui => {
    expect(await ui.find({ type: 'Text', text: 'status timed out after 5 s' })).toBeDefined()
  })
})

test('COCKPIT-AC50: a status command that cannot start shows its reason', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  kit.answer({ deniedAfterMs: 0, reason: 'permission denied' })

  await $.command.run(COCKPIT_COMMAND)

  await forEachSurface($, async ui => {
    expect(await ui.find({ type: 'Text', text: /permission denied/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /timed out/ })).toBeUndefined()
  })
})

test('COCKPIT-AC51: with the pane closed a changing autopilot folder runs no command', async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)
  kit.autopilotWrites(RUN_LOG)

  await kit.clock.advance(5000)

  expect(kit.runs).toHaveLength(1)
})

test('COCKPIT-AC51: closing the pane stops watching the folder', { plugins: [CLOSER] }, async ($, on) => {
  const kit = fakeKit(on)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  await $.command.run(CLOSE_COMMAND)
  const runsAtClose = kit.runs.length
  kit.autopilotWrites(RUN_LOG)

  await kit.clock.advance(15_000)

  expect(kit.runs).toHaveLength(runsAtClose)
})

test('COCKPIT-AC51: a pane the surface did not place is not watched', async ($, on) => {
  const kit = fakeKit(on, { isPlaced: false })
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  kit.autopilotWrites(RUN_LOG)

  await kit.clock.advance(10_000)

  expect(kit.runs).toHaveLength(2)
})

test('COCKPIT-AC52: an open pane over an unchanged autopilot folder runs no command', async ($, on) => {
  const kit = fakeKit(on)
  kit.autopilotWrites(RUN_LOG)
  kit.answer(exitedWith(kitStatus({ autopilot: activeRun('a') })))
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await kit.clock.advance(5000)

  expect(kit.runs).toHaveLength(2)
})

test('COCKPIT-AC52: an open pane with no autopilot folder runs no command', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)

  await kit.clock.advance(5000)

  expect(kit.runs).toHaveLength(2)
})

test('COCKPIT-AC53: running /cockpit again keeps one pane and one watch', async ($, on) => {
  const kit = fakeKit(on)
  await $.session.start(START)
  await $.command.run(COCKPIT_COMMAND)
  await $.command.run(COCKPIT_COMMAND)
  const runsAfterOpens = kit.runs.length
  kit.autopilotWrites(RUN_LOG)

  await kit.clock.advance(5000)

  expect(kit.opened).toEqual([
    { id: 'cockpit', title: 'Cockpit' },
    { id: 'cockpit', title: 'Cockpit' },
  ])
  expect(kit.listedPanes()).toEqual(['cockpit'])
  expect(kit.runs).toHaveLength(runsAfterOpens + 1)
})

test('COCKPIT-AC53: a reload with the pane still open watches the folder again', async ($, on) => {
  const kit = fakeKit(on, { openPanes: ['cockpit'] })
  await $.session.start(START)
  kit.autopilotWrites(RUN_LOG)

  await kit.clock.advance(5000)

  expect(kit.runs).toHaveLength(2)
})
