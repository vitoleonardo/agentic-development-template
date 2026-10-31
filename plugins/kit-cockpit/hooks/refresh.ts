import { atom, read, update } from 'claude-code'
import type { EngineInterface, Timer } from 'claude-code'

import type { KitCockpitSnapshot, KitCockpitStatus } from '../types'

const STATUS_TIMEOUT_MS = 5000
const ERROR_STATUS_LINE = 'cockpit: error'
const WATCH_MS = 5000
const LIVE_RUN_RECHECK_MS = 60_000
const UNEXPECTED_SHAPE = 'status printed an unexpected shape'
const NO_FOLDER = 'no folder'
const UNREADABLE_FOLDER = 'unreadable folder'

const snapshot = atom(
  { plugin: 'kit-cockpit', key: 'snapshot' } as const,
  { kind: 'unread' },
  { shape: 'snapshot-1' },
)

export function shownSnapshot($: EngineInterface): Promise<KitCockpitSnapshot> {
  return read($, snapshot)
}

let watch: Timer | undefined
let folderSeen: string | undefined
let refreshesStarted = 0
let newestApplied = 0
let refreshesRunning = 0
let lastRefreshStartedAt = 0

export async function markPaneOpen($: EngineInterface, isOpen: boolean): Promise<void> {
  if (!isOpen) return stopWatching()
  if (watch !== undefined) return
  watch = $.clock.every(WATCH_MS, () => watchOnce($))
  folderSeen = await autopilotFolderState($)
}

export async function refreshCockpit($: EngineInterface): Promise<void> {
  refreshesStarted += 1
  const ticket = refreshesStarted
  refreshesRunning += 1
  try {
    lastRefreshStartedAt = await $.clock.now()
    const latest = await readSnapshot($)
    if (ticket < newestApplied) return
    newestApplied = ticket
    $.ui.status(statusLineOf(latest))
    await update($, snapshot, () => latest)
  } finally {
    refreshesRunning -= 1
  }
}

function watchOnce($: EngineInterface): void {
  refreshOnFolderChange($).catch(failure =>
    $.ui.log(`kit-cockpit: watching the autopilot folder failed: ${String(failure)}`),
  )
}

async function refreshOnFolderChange($: EngineInterface): Promise<void> {
  if (refreshesRunning > 0) return
  const state = await autopilotFolderState($)
  if (state === folderSeen && !(await liveRunDueForRecheck($))) return
  if (watch === undefined) return
  folderSeen = state
  await refreshCockpit($)
}

async function liveRunDueForRecheck($: EngineInterface): Promise<boolean> {
  const shown = await read($, snapshot)
  if (shown.kind !== 'ok' || shown.status.autopilot?.active !== true) return false
  return (await $.clock.now()) - lastRefreshStartedAt >= LIVE_RUN_RECHECK_MS
}

async function autopilotFolderState($: EngineInterface): Promise<string> {
  const folder = `${await $.session.root()}/.work/autopilot`
  try {
    if (!(await $.fs.exists(folder))) return NO_FOLDER
    const entries = await $.fs.list(folder)
    const newest = Math.max(0, ...entries.map(entry => entry.mtimeMs))
    return `${entries.length} ${newest}`
  } catch {
    return UNREADABLE_FOLDER
  }
}

function stopWatching(): void {
  watch?.cancel()
  watch = undefined
  folderSeen = undefined
}

async function readSnapshot($: EngineInterface): Promise<KitCockpitSnapshot> {
  const command = `${await $.session.root()}/.claude/bin/status`
  if (!(await $.fs.exists(command))) return { kind: 'missing' }
  const sessionId = await $.session.id()
  const startedAt = await $.clock.now()
  try {
    const ran = await $.process.run([command, '--json', '--session', sessionId], {
      timeoutMs: STATUS_TIMEOUT_MS,
    })
    if (ran.exitCode !== 0) return { kind: 'error', reason: exitReason(ran.exitCode, ran.stderr) }
    return parseStatus(ran.stdout)
  } catch (failure) {
    const ranForMs = (await $.clock.now()) - startedAt
    if (ranForMs >= STATUS_TIMEOUT_MS) return { kind: 'error', reason: 'status timed out after 5 s' }
    return { kind: 'error', reason: failure instanceof Error ? failure.message : String(failure) }
  }
}

function statusLineOf(latest: KitCockpitSnapshot): string | undefined {
  if (latest.kind === 'error') return ERROR_STATUS_LINE
  if (latest.kind === 'ok' && latest.status.line !== '') return latest.status.line
  return undefined
}

function exitReason(exitCode: number, stderr: string): string {
  const firstLine = stderr
    .split('\n')
    .map(line => line.trim())
    .find(line => line !== '')
  return firstLine ?? `status exited with code ${exitCode}`
}

function parseStatus(stdout: string): KitCockpitSnapshot {
  let parsed: unknown
  try {
    parsed = JSON.parse(stdout)
  } catch {
    return { kind: 'error', reason: 'status printed no JSON' }
  }
  if (!isStatus(parsed)) return { kind: 'error', reason: UNEXPECTED_SHAPE }
  return { kind: 'ok', status: parsed }
}

function isStatus(value: unknown): value is KitCockpitStatus {
  if (!isRecord(value) || typeof value.line !== 'string') return false
  const lists = ['criteria', 'stops', 'rounds', 'decisions', 'warnings'] as const
  if (!lists.every(key => Array.isArray(value[key]))) return false
  if (!(value.stage === null || typeof value.stage === 'string')) return false
  const objects = ['tasks', 'budget', 'evidence'] as const
  if (!objects.every(key => isNullOrRecord(value[key]))) return false
  if (isRecord(value.tasks) && !Array.isArray(value.tasks.items)) return false
  if (isRecord(value.evidence) && !Array.isArray(value.evidence.gates)) return false
  const { autopilot } = value
  if (autopilot === null) return true
  return isRecord(autopilot) && typeof autopilot.active === 'boolean' && Array.isArray(autopilot.features) && isNullOrRecord(autopilot.current)
}

function isNullOrRecord(value: unknown): boolean {
  return value === null || isRecord(value)
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}
