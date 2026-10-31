import type { ThemeKey } from 'claude-code'

export type Segment = { text: string; color: ThemeKey; isBold?: boolean }

export const STAGES = ['spec', 'plan', 'build', 'review', 'verify', 'pr', 'done'] as const

const LABELLED_RAIL_MIN_COLUMNS = 50
const BUDGET_WARNING_PERCENT = 80
const BUDGET_EXCEEDED_PERCENT = 100

export function barSegments(width: number, parts: readonly number[]): number[] {
  const cells = Math.max(0, Math.floor(width))
  const weights = parts.map(part => Math.max(0, part))
  const total = weights.reduce((sum, weight) => sum + weight, 0)
  if (weights.length === 0) return []
  if (total === 0) return weights.map((_, index) => (index === weights.length - 1 ? cells : 0))

  const exact = weights.map(weight => (weight / total) * cells)
  const counts = exact.map(Math.floor)
  const nonzeroParts = weights.filter(weight => weight > 0).length
  if (nonzeroParts <= cells) {
    weights.forEach((weight, index) => {
      if (weight > 0 && counts[index] === 0) counts[index] = 1
    })
  }
  const byRemainder = exact
    .map((value, index) => ({ index, remainder: value - Math.floor(value) }))
    .sort((a, b) => b.remainder - a.remainder)
  let missing = cells - counts.reduce((sum, count) => sum + count, 0)
  for (let turn = 0; missing > 0; turn += 1) {
    const target = byRemainder[turn % byRemainder.length]
    if (target !== undefined && weights[target.index]! > 0) {
      counts[target.index]! += 1
      missing -= 1
    }
  }
  while (missing < 0) {
    const largest = counts.indexOf(Math.max(...counts))
    counts[largest]! -= 1
    missing += 1
  }
  return counts
}

export function percentColor(percent: number): ThemeKey {
  if (percent >= BUDGET_EXCEEDED_PERCENT) return 'error'
  if (percent >= BUDGET_WARNING_PERCENT) return 'warning'
  return 'success'
}

type Cell = { char: string; color: ThemeKey; isBold: boolean }

export function stageRail(stage: string, width: number): { rail: Segment[]; labels: Segment[] } {
  const cells = Math.max(STAGES.length, Math.floor(width))
  const current = stage === 'done' ? STAGES.length : STAGES.indexOf(stage as (typeof STAGES)[number])
  const toneOf = (index: number): ThemeKey => {
    if (index < current) return 'success'
    if (index === current) return 'claude'
    return 'subtle'
  }
  const dotAt = STAGES.map((_, index) => Math.round((index * (cells - 1)) / (STAGES.length - 1)))

  const rail: Cell[] = Array.from({ length: cells }, () => ({ char: '─', color: 'subtle', isBold: false }))
  dotAt.forEach((at, index) => {
    const next = dotAt[index + 1]
    if (next !== undefined) {
      const linkColor: ThemeKey = index + 1 <= current ? 'success' : 'subtle'
      for (let x = at + 1; x < next; x += 1) rail[x] = { char: '─', color: linkColor, isBold: false }
      if (next - at >= 4) {
        rail[at + 1] = { char: ' ', color: linkColor, isBold: false }
        rail[next - 1] = { char: ' ', color: linkColor, isBold: false }
      }
    }
    const tone = toneOf(index)
    rail[at] = { char: tone === 'claude' ? '◉' : tone === 'success' ? '●' : '○', color: tone, isBold: false }
  })

  if (cells < LABELLED_RAIL_MIN_COLUMNS) return { rail: joinCells(rail), labels: [] }
  const labels: Cell[] = Array.from({ length: cells }, () => ({ char: ' ', color: 'subtle', isBold: false }))
  STAGES.forEach((name, index) => {
    const start = Math.min(cells - name.length, Math.max(0, dotAt[index]! - Math.floor((name.length - 1) / 2)))
    const tone = toneOf(index)
    for (let offset = 0; offset < name.length; offset += 1) {
      labels[start + offset] = { char: name[offset]!, color: tone, isBold: tone === 'claude' }
    }
  })
  return { rail: joinCells(rail), labels: joinCells(labels) }
}

function joinCells(cells: Cell[]): Segment[] {
  const segments: Segment[] = []
  for (const cell of cells) {
    const last = segments.at(-1)
    if (last !== undefined && last.color === cell.color && (last.isBold === true) === cell.isBold) {
      last.text += cell.char
      continue
    }
    segments.push(cell.isBold ? { text: cell.char, color: cell.color, isBold: true } : { text: cell.char, color: cell.color })
  }
  return segments
}
