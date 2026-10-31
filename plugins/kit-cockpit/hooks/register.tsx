import type { Register } from 'claude-code'

import { drawCockpit } from './pane'
import { markPaneOpen, refreshCockpit } from './refresh'

const PANE_ID = 'cockpit'
const REFRESHING_TOOLS = ['Edit', 'Write', 'Agent'] as const

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'cockpit',
      description: "Show where this branch's kit feature stands",
    })
    const started = await next(e)
    markPaneOpen((await $.ui.panes()).some(pane => pane.id === PANE_ID))
    await refreshCockpit($)
    return started
  })

  on('tool.call', { tool: REFRESHING_TOOLS }, async ($, e, next) => {
    const ran = await next(e)
    await refreshCockpit($)
    return ran
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const completed = await next(e)
    if (e.agentId === undefined) await refreshCockpit($)
    return completed
  })

  on('command.run', { command: 'cockpit' }, async $ => {
    markPaneOpen(true)
    await $.ui.open({ id: PANE_ID, title: 'Cockpit' })
    await refreshCockpit($)
    return { text: 'Cockpit pane opened.' }
  })

  on('ui.close', { id: PANE_ID }, async ($, e, next) => {
    const closed = await next(e)
    markPaneOpen(false)
    return closed
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: PANE_ID }, ($, e) => drawCockpit($, e))
}
