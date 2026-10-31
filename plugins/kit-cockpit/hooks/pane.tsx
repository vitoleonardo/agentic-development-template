import type {
  BoxProps,
  ElementConstructor,
  EngineInterface,
  RenderElement,
  RenderInput,
  TextProps,
  ThemeKey,
} from 'claude-code'

import type { KitCockpitAutopilot, KitCockpitCriterion, KitCockpitSnapshot, KitCockpitStatus } from '../types'
import { barSegments, percentColor, stageRail } from './meters'
import type { Segment } from './meters'
import { shownSnapshot } from './refresh'

const MISSING_KIT_TEXT =
  "kit-cockpit needs the Agentic Workflow Kit 0.3.0 or newer. Run ./install.sh <project> --update from the kit's repository."

const PANEL_FRAME_COLUMNS = 4
const METER_LABEL_COLUMNS = 9
const MIN_BAR_COLUMNS = 4
const CHIP_GAP = '  '
const SHORT_HEAD_LENGTH = 7

type Ui = { Box: ElementConstructor<BoxProps>; Text: ElementConstructor<TextProps> }
type Span = Segment | string
type Badge = { text: string; color: ThemeKey }
type Look = { title?: string; badge?: Badge; border: ThemeKey }
type Meter = { label: string; bar?: { parts: number[]; colors: ThemeKey[]; glyphs: string[] }; value: Span[] }

export async function drawCockpit($: EngineInterface, e: RenderInput<'Pane'>) {
  const ui = $.ui.resolve(e)
  const { Box } = ui
  const width = e.props.bodyColumns

  return (
    <Box flexDirection="column" width={width}>
      {panelsOf(ui, await shownSnapshot($), width)}
    </Box>
  )
}

function panelsOf(ui: Ui, shown: KitCockpitSnapshot, width: number): RenderElement[] {
  if (shown.kind === 'unread') return [notice(ui, width, 'subtle', "Reading the kit's status...")]
  if (shown.kind === 'missing') return [notice(ui, width, 'warning', MISSING_KIT_TEXT)]
  if (shown.kind === 'error') return [notice(ui, width, 'error', shown.reason)]
  const { status } = shown
  if (status.stage === null) {
    return [notice(ui, width, 'subtle', 'No feature on this branch.'), autopilotPanel(ui, width, status.autopilot)]
  }
  return [
    headerPanel(ui, width, status),
    criteriaPanel(ui, width, status.criteria),
    tasksPanel(ui, width, status.tasks),
    stopsPanel(ui, width, status.stops),
    roundsPanel(ui, width, status.rounds),
    decisionsPanel(ui, width, status.decisions),
    evidencePanel(ui, width, status.evidence),
    autopilotPanel(ui, width, status.autopilot),
  ]
}

function panel(ui: Ui, width: number, look: Look, rows: RenderElement[]): RenderElement {
  const { Box, Text } = ui
  return (
    <Box flexDirection="column" width={width} borderStyle="round" borderColor={look.border} paddingX={1}>
      {look.title !== undefined && (
        <Box flexDirection="row" justifyContent="space-between">
          <Text weight="bold">{look.title}</Text>
          {look.badge !== undefined && <Text color={look.badge.color}>{look.badge.text}</Text>}
        </Box>
      )}
      {rows}
    </Box>
  )
}

function section(ui: Ui, width: number, look: Look, rows: RenderElement[]): RenderElement {
  if (rows.length > 0) return panel(ui, width, look, rows)
  return panel(ui, width, { ...look, badge: { text: 'none', color: 'subtle' } }, [])
}

function notice(ui: Ui, width: number, border: ThemeKey, text: string): RenderElement {
  const { Text } = ui
  return panel(ui, width, { border }, [<Text color={border === 'subtle' ? 'subtle' : 'text'}>{text}</Text>])
}

function line(ui: Ui, spans: Span[]): RenderElement {
  const { Text } = ui
  const [only] = spans
  if (spans.length === 1 && only !== undefined && typeof only !== 'string') {
    if (only.isBold === true) return <Text wrap="truncate-end" color={only.color} weight="bold">{only.text}</Text>
    return <Text wrap="truncate-end" color={only.color}>{only.text}</Text>
  }
  return (
    <Text wrap="truncate-end">
      {spans.map(span => {
        if (typeof span === 'string') return span
        if (span.isBold === true) return <Text color={span.color} weight="bold">{span.text}</Text>
        return <Text color={span.color}>{span.text}</Text>
      })}
    </Text>
  )
}

function columnsOf(spans: Span[]): number {
  return spans.reduce((sum, span) => sum + (typeof span === 'string' ? span : span.text).length, 0)
}

function headerPanel(ui: Ui, width: number, status: KitCockpitStatus): RenderElement {
  const { Box, Text } = ui
  const inner = width - PANEL_FRAME_COLUMNS
  const stage = status.stage ?? ''
  const { rail, labels } = stageRail(stage, inner)
  const meters = metersOf(status)

  return (
    <Box flexDirection="column" width={width} borderStyle="round" borderColor="claude" paddingX={1}>
      <Box flexDirection="row" justifyContent="space-between">
        <Text wrap="truncate-end">
          <Text color="claude" weight="bold" inverse>{` ${stage.toUpperCase()} `}</Text>
          {'  '}
          <Text weight="bold">{status.feature ?? ''}</Text>
        </Text>
        {status.tasks !== null && status.tasks.total > 0 && (
          <Text color="subtle">{`tasks ${status.tasks.done}/${status.tasks.total}`}</Text>
        )}
      </Box>
      <Box flexDirection="column" marginTop={1}>
        {line(ui, rail)}
        {labels.length > 0 && line(ui, labels)}
      </Box>
      {meters.length > 0 && (
        <Box flexDirection="column" marginTop={1}>
          {meterRows(ui, inner, meters)}
        </Box>
      )}
    </Box>
  )
}

function metersOf(status: KitCockpitStatus): Meter[] {
  const meters: Meter[] = []
  const { tasks, criteria, budget, red } = status
  if (tasks !== null && tasks.total > 0) {
    meters.push({
      label: 'tasks',
      bar: { parts: [tasks.done, tasks.total - tasks.done], colors: ['success', 'subtle'], glyphs: ['█', '░'] },
      value: [`${tasks.done}/${tasks.total}`],
    })
  }
  if (criteria.length > 0) {
    const [green, redCount, open] = (['green', 'red', 'open'] as const).map(
      state => criteria.filter(criterion => criterion.state === state).length,
    )
    meters.push({
      label: 'criteria',
      bar: { parts: [green!, redCount!, open!], colors: ['success', 'error', 'subtle'], glyphs: ['█', '█', '░'] },
      value: [
        { text: `${green}✓`, color: 'success' },
        ' ',
        { text: `${redCount}✗`, color: 'error' },
        ' ',
        { text: `${open}○`, color: 'subtle' },
      ],
    })
  }
  if (budget !== null) {
    const filled = Math.min(budget.percent, 100)
    const color = percentColor(budget.percent)
    meters.push({
      label: 'budget',
      bar: { parts: [filled, 100 - filled], colors: [color, 'subtle'], glyphs: ['█', '░'] },
      value: [{ text: `${budget.percent}%`, color }],
    })
  }
  if (red !== null && red > 0) meters.push({ label: 'checks', value: [{ text: `${red} red this turn`, color: 'error' }] })
  return meters
}

function meterRows(ui: Ui, inner: number, meters: Meter[]): RenderElement[] {
  const valueColumns = Math.max(0, ...meters.filter(meter => meter.bar !== undefined).map(meter => columnsOf(meter.value)))
  const barColumns = Math.max(MIN_BAR_COLUMNS, inner - METER_LABEL_COLUMNS - 1 - valueColumns)
  return meters.map(meter => {
    const label: Span = { text: meter.label.padEnd(METER_LABEL_COLUMNS), color: 'subtle' }
    if (meter.bar === undefined) return line(ui, [label, ...meter.value])
    const { parts, colors, glyphs } = meter.bar
    const bar = barSegments(barColumns, parts).flatMap((count, index): Span[] =>
      count > 0 ? [{ text: glyphs[index]!.repeat(count), color: colors[index]! }] : [],
    )
    return line(ui, [label, ...bar, ' ', ...meter.value])
  })
}

const CRITERION_LOOK = {
  green: { mark: '✓', color: 'success' },
  red: { mark: '✗', color: 'error' },
  open: { mark: '○', color: 'subtle' },
} as const satisfies Record<KitCockpitCriterion['state'], { mark: string; color: ThemeKey }>

function criteriaPanel(ui: Ui, width: number, criteria: KitCockpitCriterion[]): RenderElement {
  const untested = criteria.filter(criterion => criterion.state === 'open' && criterion.tests.length === 0)
  const listed = criteria.filter(criterion => !untested.includes(criterion))
  const headColumns = Math.max(0, ...listed.map(criterion => `${criterion.id} ${criterion.state}`.length))
  const rows = listed.map(criterion => {
    const look = CRITERION_LOOK[criterion.state]
    const gap = ' '.repeat(headColumns - `${criterion.id} ${criterion.state}`.length + 2)
    return line(ui, [
      { text: look.mark, color: look.color },
      ` ${criterion.id} `,
      { text: criterion.state, color: look.color },
      gap,
      { text: criterion.tests.join(', '), color: 'subtle' },
    ])
  })
  if (untested.length > 0) {
    const ids = untested.map(criterion => criterion.id).join(', ')
    rows.push(line(ui, [{ text: `○ ${untested.length} open without a test: ${ids}`, color: 'subtle' }]))
  }
  const red = criteria.filter(criterion => criterion.state === 'red').length
  const green = criteria.filter(criterion => criterion.state === 'green').length
  const badge: Badge | undefined =
    criteria.length === 0
      ? undefined
      : red > 0
        ? { text: `${red} red`, color: 'error' }
        : { text: `${green}/${criteria.length} green`, color: green === criteria.length ? 'success' : 'subtle' }
  return section(ui, width, { title: 'Criteria', badge, border: red > 0 ? 'error' : 'subtle' }, rows)
}

function tasksPanel(ui: Ui, width: number, tasks: KitCockpitStatus['tasks']): RenderElement {
  const items = tasks?.items ?? []
  const next = items.findIndex(task => !task.done)
  const rows = items.map((task, index) => {
    if (task.done) return line(ui, ['  ', { text: '☑', color: 'success' }, ` ${task.text}`])
    if (index === next) return line(ui, [{ text: `▸ ☐ ${task.text}`, color: 'claude' }])
    return line(ui, [{ text: `  ☐ ${task.text}`, color: 'subtle' }])
  })
  const badge: Badge | undefined =
    tasks === null || tasks.total === 0
      ? undefined
      : { text: `${tasks.done}/${tasks.total}`, color: tasks.done === tasks.total ? 'success' : 'claude' }
  return section(ui, width, { title: 'Tasks', badge, border: 'subtle' }, rows)
}

function fieldsOf(row: string): string[] {
  return row.split('|').map(field => field.trim())
}

function stopsPanel(ui: Ui, width: number, stops: string[]): RenderElement {
  const parsed = stops.map(fieldsOf)
  const classColumns = Math.max(0, ...parsed.map(fields => (fields.length >= 3 ? fields[1]!.length : 0)))
  const rows = parsed.map((fields, index) => {
    const [step = '', stopClass = '', trigger = ''] = fields
    if (fields.length < 3) return line(ui, [stops[index]!])
    return line(ui, [
      { text: stopClass.padEnd(classColumns), color: 'warning' },
      `  ${step}  `,
      { text: trigger, color: 'subtle' },
    ])
  })
  const badge: Badge | undefined = stops.length > 0 ? { text: `${stops.length}`, color: 'warning' } : undefined
  return section(ui, width, { title: 'Stops', badge, border: stops.length > 0 ? 'warning' : 'subtle' }, rows)
}

function isPassing(result: string): boolean {
  return result.startsWith('pass')
}

function roundsPanel(ui: Ui, width: number, rounds: string[]): RenderElement {
  const parsed = rounds.map(row => {
    const fields = fieldsOf(row)
    return {
      name: fields[0] ?? row,
      scope: fields.length >= 4 ? fields[1] : undefined,
      result: fields.length > 1 ? fields.at(-1) : undefined,
    }
  })
  const headColumns = Math.max(0, ...parsed.map(round => columnsOf([round.name, round.scope ? ` ${round.scope}` : ''])))
  const rows = parsed.map(round => {
    const head: Span[] = [round.name, ...(round.scope ? [' ', { text: round.scope, color: 'subtle' } as Span] : [])]
    const gap = ' '.repeat(headColumns - columnsOf(head) + 2)
    if (round.result === undefined) return line(ui, head)
    const verdict: Span = isPassing(round.result)
      ? { text: `✓ ${round.result}`, color: 'success' }
      : { text: `✗ ${round.result}`, color: 'error' }
    return line(ui, [...head, gap, verdict])
  })
  const last = parsed.at(-1)
  const lastFailed = last?.result !== undefined && !isPassing(last.result)
  const badge: Badge | undefined =
    last === undefined ? undefined : { text: `${rounds.length}`, color: lastFailed ? 'error' : 'success' }
  return section(ui, width, { title: 'Rounds', badge, border: lastFailed ? 'error' : 'subtle' }, rows)
}

function decisionsPanel(ui: Ui, width: number, decisions: string[]): RenderElement {
  const parsed = decisions.map(fieldsOf)
  const gateColumns = Math.max(0, ...parsed.map(fields => (fields.length >= 2 ? fields[0]!.length : 0)))
  const rows = parsed.flatMap((fields, index) => {
    const [gate = '', decision = '', ...why] = fields
    if (fields.length < 2) return [line(ui, [decisions[index]!])]
    const decided = line(ui, [{ text: gate.padEnd(gateColumns), color: 'suggestion' }, `  ${decision}`])
    if (why.length === 0) return [decided]
    return [decided, line(ui, [' '.repeat(gateColumns + 2), { text: why.join(' | '), color: 'subtle' }])]
  })
  const badge: Badge | undefined = decisions.length > 0 ? { text: `${decisions.length}`, color: 'suggestion' } : undefined
  return section(ui, width, { title: 'Decisions to review', badge, border: 'subtle' }, rows)
}

function gateChip(gate: { name: string; result: string }): Segment {
  if (gate.result === 'pass') return { text: `✓ ${gate.name}`, color: 'success' }
  if (gate.result === 'n/a') return { text: `– ${gate.name}`, color: 'subtle' }
  return { text: `✗ ${gate.name}`, color: 'error' }
}

function evidencePanel(ui: Ui, width: number, evidence: KitCockpitStatus['evidence']): RenderElement {
  if (evidence === null) return section(ui, width, { title: 'Evidence', border: 'subtle' }, [])
  const inner = width - PANEL_FRAME_COLUMNS
  const chipRows: Span[][] = []
  for (const chip of evidence.gates.map(gateChip)) {
    const last = chipRows.at(-1)
    if (last !== undefined && columnsOf(last) + CHIP_GAP.length + chip.text.length <= inner) last.push(CHIP_GAP, chip)
    else chipRows.push([chip])
  }
  const rows =
    chipRows.length > 0 ? chipRows.map(chips => line(ui, chips)) : [line(ui, [{ text: 'no gates', color: 'subtle' }])]
  const head = evidence.head === null ? '' : ` ${evidence.head.slice(0, SHORT_HEAD_LENGTH)}`
  const badge: Badge = evidence.current ? { text: 'current', color: 'success' } : { text: `stale${head}`, color: 'warning' }
  const hasFailure = evidence.gates.some(gate => gate.result !== 'pass' && gate.result !== 'n/a')
  const border: ThemeKey = hasFailure ? 'error' : evidence.current ? 'subtle' : 'warning'
  return section(ui, width, { title: 'Evidence', badge, border }, rows)
}

const PHASES = ['plan', 'build'] as const

function phaseDiagram(phase: string): Span[] {
  const current = PHASES.indexOf(phase as (typeof PHASES)[number])
  if (current < 0) return [{ text: phase, color: 'claude', isBold: true }]
  return PHASES.flatMap((name, index): Span[] => {
    const step: Span =
      index < current ? { text: name, color: 'success' } : index === current ? { text: name, color: 'claude', isBold: true } : { text: name, color: 'subtle' }
    return index === 0 ? [step] : [{ text: ' ━▶ ', color: 'subtle' }, step]
  })
}

function resultLook(result: string): { mark: string; color: ThemeKey } {
  if (result.startsWith('in-review') || result.startsWith('done')) return { mark: '✓', color: 'success' }
  if (result.startsWith('stopped')) return { mark: '✗', color: 'error' }
  if (result.startsWith('skipped')) return { mark: '–', color: 'subtle' }
  return { mark: '•', color: 'text' }
}

function autopilotPanel(ui: Ui, width: number, autopilot: KitCockpitAutopilot | null): RenderElement {
  if (autopilot === null) return section(ui, width, { title: 'Autopilot', border: 'subtle' }, [])
  const rows: RenderElement[] = []
  const { current, features } = autopilot
  if (current !== null) {
    rows.push(
      line(ui, [{ text: '▸ ', color: 'claude' }, { text: current.feature, color: 'text', isBold: true }, '  ', ...phaseDiagram(current.phase)]),
    )
  }
  const nameColumns = Math.max(0, ...features.map(finished => finished.feature.length))
  for (const finished of features) {
    const look = resultLook(finished.result)
    rows.push(
      line(ui, [{ text: look.mark, color: look.color }, ` ${finished.feature.padEnd(nameColumns)}  `, { text: finished.result, color: look.color }]),
    )
  }
  const badge: Badge = autopilot.active ? { text: '● live', color: 'success' } : { text: '○ idle', color: 'subtle' }
  return section(ui, width, { title: 'Autopilot', badge, border: 'subtle' }, rows)
}
