import type { Register } from 'claude-code'

import { drawCockpit } from './pane'
import { markPaneOpen, refreshCockpit } from './refresh'

const PANE_ID = 'cockpit'
const REFRESHING_TOOLS = ['Edit', 'Write', 'Agent'] as const
const COCKPIT_FAILED = 'The Cockpit pane could not read the kit status. Run /cockpit again, or see claude --debug.'

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'cockpit',
      description: "Show where this branch's kit feature stands",
    })
    const started = await next(e)
    const panes = await $.ui.panes()
    await markPaneOpen($, panes.some(pane => pane.id === PANE_ID && pane.isPlaced))
    await refreshCockpit($)
    return started
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: REFRESHING_TOOLS }, async ($, e, next) => {
    const ran = await next(e)
    await refreshCockpit($)
    return ran
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const completed = await next(e)
    if (e.agentId === undefined) await refreshCockpit($)
    return completed
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'cockpit' }, async $ => {
    const opened = await $.ui.open({ id: PANE_ID, title: 'Cockpit' })
    await markPaneOpen($, opened.isPlaced)
    await refreshCockpit($)
    return { text: 'Cockpit pane opened.' }
  }).catch(() => ({ text: COCKPIT_FAILED }))

  on('ui.close', { id: PANE_ID }, async ($, e, next) => {
    const closed = await next(e)
    await markPaneOpen($, false)
    return closed
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: PANE_ID }, ($, e) => drawCockpit($, e))
}
