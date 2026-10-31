import { atom, read, update } from 'claude-code'
import type { EngineInterface, Timer } from 'claude-code'

import type { KitCockpitSnapshot, KitCockpitStatus } from '../types'

const STATUS_TIMEOUT_MS = 5000
const ERROR_STATUS_LINE = 'cockpit: error'
const POLL_MS = 5000

const snapshot = atom(
  { plugin: 'kit-cockpit', key: 'snapshot' } as const,
  { kind: 'unread' },
  { shape: 'snapshot-1' },
)

export function shownSnapshot($: EngineInterface): Promise<KitCockpitSnapshot> {
  return read($, snapshot)
}

let poll: Timer | undefined
let isPaneOpen = false

export function markPaneOpen(isOpen: boolean): void {
  isPaneOpen = isOpen
  if (!isOpen) stopPolling()
}

export async function refreshCockpit($: EngineInterface): Promise<void> {
  const latest = await readSnapshot($)
  $.ui.status(statusLineOf(latest))
  await update($, snapshot, () => latest)
  followRun($, latest)
}

function followRun($: EngineInterface, latest: KitCockpitSnapshot): void {
  if (!isPaneOpen || !isRunActive(latest)) return stopPolling()
  if (poll !== undefined) return
  poll = $.clock.every(POLL_MS, () => pollOnce($))
}

function pollOnce($: EngineInterface): void {
  refreshCockpit($).catch(failure => $.ui.log(`kit-cockpit: polling failed: ${String(failure)}`))
}

function stopPolling(): void {
  poll?.cancel()
  poll = undefined
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

function isRunActive(latest: KitCockpitSnapshot): boolean {
  return latest.kind === 'ok' && latest.status.autopilot?.active === true
}

function exitReason(exitCode: number, stderr: string): string {
  const firstLine = stderr
    .split('\n')
    .map(line => line.trim())
    .find(line => line !== '')
  return firstLine ?? `status exited with code ${exitCode}`
}

function parseStatus(stdout: string): KitCockpitSnapshot {
  try {
    return { kind: 'ok', status: JSON.parse(stdout) as KitCockpitStatus }
  } catch {
    return { kind: 'error', reason: 'status printed no JSON' }
  }
}
