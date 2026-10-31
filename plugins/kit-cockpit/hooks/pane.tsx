import type { EngineInterface, RenderInput } from 'claude-code'

import type { KitCockpitAutopilot, KitCockpitSnapshot, KitCockpitStatus } from '../types'
import { shownSnapshot } from './refresh'

const MISSING_KIT_TEXT =
  "kit-cockpit needs the Agentic Workflow Kit 0.3.0 or newer. Run ./install.sh <project> --update from the kit's repository."

type Section = { title: string; rows: string[] }
type PaneContent = { notice?: string; sections: Section[] }

export async function drawCockpit($: EngineInterface, e: RenderInput<'Pane'>) {
  const { Box, Text } = $.ui.resolve(e)
  const content = contentOf(await shownSnapshot($))

  return (
    <Box flexDirection="column">
      {content.notice !== undefined && <Text>{content.notice}</Text>}
      {content.sections.map(section => (
        <Box flexDirection="column" marginTop={1}>
          <Text bold>{section.title}</Text>
          {(section.rows.length === 0 ? ['none'] : section.rows).map(row => (
            <Text>{row}</Text>
          ))}
        </Box>
      ))}
    </Box>
  )
}

function contentOf(shown: KitCockpitSnapshot): PaneContent {
  if (shown.kind === 'unread') return { notice: "Reading the kit's status...", sections: [] }
  if (shown.kind === 'missing') return { notice: MISSING_KIT_TEXT, sections: [] }
  if (shown.kind === 'error') return { notice: shown.reason, sections: [] }
  const { status } = shown
  if (status.stage === null) {
    const sections = status.autopilot === null ? [] : [autopilotSection(status.autopilot)]
    return { notice: 'No feature on this branch.', sections }
  }
  return { sections: featureSections(status) }
}

function featureSections(status: KitCockpitStatus): Section[] {
  return [
    {
      title: 'Criteria',
      rows: status.criteria.map(criterion =>
        [`${criterion.id} ${criterion.state}`, ...criterion.tests].join('  '),
      ),
    },
    {
      title: 'Tasks',
      rows: (status.tasks?.items ?? []).map(task => `${task.done ? '[x]' : '[ ]'} ${task.text}`),
    },
    { title: 'Stops', rows: status.stops },
    { title: 'Rounds', rows: status.rounds },
    { title: 'Decisions to review', rows: status.decisions },
    { title: 'Evidence', rows: evidenceRows(status.evidence) },
    status.autopilot === null ? { title: 'Autopilot', rows: [] } : autopilotSection(status.autopilot),
  ]
}

function evidenceRows(evidence: KitCockpitStatus['evidence']): string[] {
  if (evidence === null) return []
  const commit = evidence.head === null ? 'an unknown commit' : evidence.head.slice(0, 7)
  return [
    `${evidence.current ? 'current' : 'stale'}, made on ${commit}`,
    ...evidence.gates.map(gate => `${gate.name} ${gate.result}`),
  ]
}

function autopilotSection(autopilot: KitCockpitAutopilot): Section {
  const current = autopilot.current
  return {
    title: 'Autopilot',
    rows: [
      autopilot.active ? 'active' : 'idle',
      ...(current === null ? [] : [`current: ${current.feature} · ${current.phase}`]),
      ...autopilot.features.map(finished => `${finished.feature} ${finished.result}`),
    ],
  }
}
