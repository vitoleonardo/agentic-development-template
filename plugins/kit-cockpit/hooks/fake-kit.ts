import type { On, ProcessRunResult, UiPane } from 'claude-code'
import { mock } from 'claude-code/testing'

import type { KitCockpitAutopilot, KitCockpitStatus } from '../types'

const ROOT = '/project'
const STATUS_COMMAND = `${ROOT}/.claude/bin/status`
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
  | { exited: number; stdout?: string; stderr?: string }
  | { deniedAfterMs: number; reason: string }

export function exitedWith(status: KitCockpitStatus): StatusAnswer {
  return { exited: 0, stdout: `${JSON.stringify(status)}\n` }
}

export function fakeKit(on: On, setup: { isInstalled?: boolean; openPanes?: string[] } = {}) {
  const clock = mock.clock(on, { now: 1_000_000 })
  const runs: { argv: readonly string[]; timeoutMs: number | undefined }[] = []
  const statusLines: (string | undefined)[] = []
  const writes: string[] = []
  const opened: { id: string; title: string | undefined }[] = []
  const openPanes: UiPane[] = (setup.openPanes ?? []).map(id => ({
    id,
    title: 'Cockpit',
    isShown: true,
    isFocused: false,
    isPlaced: true,
  }))
  let answer: StatusAnswer = exitedWith(kitStatus())
  let whileToolRuns: () => void = () => {}

  on('session.root', () => ({ value: ROOT }))
  on('session.id', () => ({ value: SESSION_ID }))
  on('fs.exists', (_, e) => ({ value: (setup.isInstalled ?? true) && e.path === STATUS_COMMAND }))
  on('fs.write', (_, e) => {
    writes.push(e.path)
    return { value: undefined }
  })
  on('process.run', async (_, e) => {
    runs.push({ argv: e.argv, timeoutMs: e.init?.timeoutMs })
    const now = answer
    if ('deniedAfterMs' in now) {
      if (now.deniedAfterMs > 0) await clock.sleep(now.deniedAfterMs)
      return { deny: now.reason }
    }
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
    return { value: { isPlaced: true } }
  })
  on('ui.panes', () => ({ value: openPanes }))
  on('ui.close', () => ({ value: undefined }))
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
    answer: (next: StatusAnswer) => {
      answer = next
    },
    whileToolRuns: (change: () => void) => {
      whileToolRuns = change
    },
  }
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
