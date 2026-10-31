import type { FsEntry, On, ProcessRunResult, UiPane } from 'claude-code'
import { mock } from 'claude-code/testing'
import type { Engine, Mounted } from 'claude-code/testing'

import type { KitCockpitAutopilot, KitCockpitStatus } from '../types'

const ROOT = '/project'
const STATUS_COMMAND = `${ROOT}/.claude/bin/status`
const AUTOPILOT_FOLDER = `${ROOT}/.work/autopilot`
const SESSION_ID = 'session-1'
export const STATUS_ARGV = [STATUS_COMMAND, '--json', '--session', SESSION_ID]

export const PANE = {
  plugin: 'kit-cockpit',
  component: 'Pane',
  requestId: 'cockpit',
  props: {
    title: 'Cockpit',
    isFocused: false,
    bodyColumns: 80,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 40 },
    view: {},
  },
} as const

export const SURFACES = ['terminal', 'desktop'] as const

type MountedPane = Mounted<(typeof SURFACES)[number], 'Pane'>

export async function forEachSurface(
  $: Engine,
  check: (ui: MountedPane) => Promise<void>,
  bodyColumns: number = PANE.props.bodyColumns,
): Promise<void> {
  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, props: { ...PANE.props, bodyColumns }, surface })
    await check(ui)
    await ui.unmount()
  }
}

export async function shownTexts(ui: MountedPane): Promise<string[]> {
  return (await ui.findAll({ type: 'Text' })).map(found => found.text)
}

export function kitStatus(overrides: Partial<KitCockpitStatus> = {}): KitCockpitStatus {
  return {
    line: 'invite-users · build · tasks 3/7',
    branch: 'invite-users',
    feature: 'invite-users',
    spec: 'specs/invite-users.md',
    stage: 'build',
    tasks: null,
    criteria: [],
    stops: [],
    rounds: [],
    decisions: [],
    red: 0,
    budget: null,
    evidence: null,
    autopilot: null,
    warnings: [],
    ...overrides,
  }
}

export function activeRun(feature: string): KitCockpitAutopilot {
  return {
    active: true,
    current: { feature, phase: 'build' },
    features: [{ feature: 'done-one', branch: 'done-one', result: 'PR opened' }],
  }
}

type StatusAnswer =
  | { exited: number; stdout?: string; stderr?: string; afterMs?: number }
  | { deniedAfterMs: number; reason: string }

export function exitedWith(status: KitCockpitStatus, afterMs?: number): StatusAnswer {
  return { exited: 0, stdout: `${JSON.stringify(status)}\n`, afterMs }
}

type FakeKitSetup = { isInstalled?: boolean; openPanes?: string[]; isPlaced?: boolean }

export function fakeKit(on: On, setup: FakeKitSetup = {}) {
  const clock = mock.clock(on, { now: 1_000_000 })
  const runs: { argv: readonly string[]; timeoutMs: number | undefined }[] = []
  const statusLines: (string | undefined)[] = []
  const writes: string[] = []
  const opened: { id: string; title: string | undefined }[] = []
  const openPanes: UiPane[] = (setup.openPanes ?? []).map(id => listedPane(id))
  let autopilotFolder: FsEntry[] | undefined
  let fileTime = 1_000_000
  let answer: StatusAnswer = exitedWith(kitStatus())
  let queued: StatusAnswer[] = []
  let whileToolRuns: () => void = () => {}

  on('session.root', () => ({ value: ROOT }))
  on('session.id', () => ({ value: SESSION_ID }))
  on('fs.exists', (_, e) => {
    if (e.path === AUTOPILOT_FOLDER) return { value: autopilotFolder !== undefined }
    return { value: (setup.isInstalled ?? true) && e.path === STATUS_COMMAND }
  })
  on('fs.list', (_, e) => {
    if (e.path !== AUTOPILOT_FOLDER || autopilotFolder === undefined) throw new Error(`ENOENT: ${e.path}`)
    return { value: autopilotFolder.map(entry => ({ ...entry })) }
  })
  on('fs.write', (_, e) => {
    writes.push(e.path)
    return { value: undefined }
  })
  on('process.run', async (_, e) => {
    runs.push({ argv: e.argv, timeoutMs: e.init?.timeoutMs })
    const now = queued.shift() ?? answer
    if ('deniedAfterMs' in now) {
      if (now.deniedAfterMs > 0) await clock.sleep(now.deniedAfterMs)
      return { deny: now.reason }
    }
    if (now.afterMs !== undefined) await clock.sleep(now.afterMs)
    const result: ProcessRunResult = {
      exitCode: now.exited,
      stdout: now.stdout ?? '',
      stderr: now.stderr ?? '',
      isStdoutTruncated: false,
      isStderrTruncated: false,
    }
    return { value: result }
  })
  on('ui.status', (_, e) => {
    statusLines.push(e.text)
    return { value: undefined }
  })
  on('command.register', (_, e) => ({ value: { command: e.name } }))
  on('ui.open', (_, e) => {
    opened.push({ id: e.id, title: e.title })
    if (setup.isPlaced === false) return { value: { isPlaced: false, reason: 'the terminal is too narrow' } }
    if (!openPanes.some(pane => pane.id === e.id)) openPanes.push(listedPane(e.id))
    return { value: { isPlaced: true } }
  })
  on('ui.panes', () => ({ value: openPanes.map(pane => ({ ...pane })) }))
  on('ui.close', (_, e) => {
    const index = openPanes.findIndex(pane => pane.id === e.id)
    if (index >= 0) openPanes.splice(index, 1)
    return { value: undefined }
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('tool.call', () => {
    whileToolRuns()
    return { result: {} }
  })
  on('turn.complete', (_, e) => ({ text: e.answer }))

  return {
    clock,
    runs,
    statusLines,
    writes,
    opened,
    shownStatus: () => statusLines.at(-1),
    listedPanes: () => openPanes.map(pane => pane.id),
    answer: (next: StatusAnswer) => {
      answer = next
    },
    answerInOrder: (...next: StatusAnswer[]) => {
      queued = next
    },
    whileToolRuns: (change: () => void) => {
      whileToolRuns = change
    },
    autopilotWrites: (name: string) => {
      fileTime += 1000
      const others = (autopilotFolder ?? []).filter(entry => entry.name !== name)
      autopilotFolder = [...others, { name, kind: 'file', size: 1, mtimeMs: fileTime, isLink: false }]
    },
  }
}

function listedPane(id: string): UiPane {
  return { id, title: 'Cockpit', isShown: true, isFocused: false, isPlaced: true }
}

export const START = { cwd: ROOT, surface: 'terminal', isInteractive: true } as const

export const COCKPIT_COMMAND = {
  command: 'cockpit',
  args: '',
  origin: { kind: 'composer' },
  presentation: { isFullscreen: true, columns: 200 },
} as const

export function mainTurnEnd(turnId: string) {
  return {
    answer: 'done',
    durationMs: 1000,
    isAborted: false,
    turnId,
    reason: 'answer',
  } as const
}
