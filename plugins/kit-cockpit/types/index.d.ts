export type KitCockpitTask = { text: string; done: boolean }

export type KitCockpitCriterion = {
  id: string
  state: 'green' | 'red' | 'open'
  tests: string[]
}

export type KitCockpitGate = { name: string; result: string }

export type KitCockpitAutopilotFeature = {
  feature: string
  branch: string
  result: string
}

export type KitCockpitAutopilot = {
  active: boolean
  current: { feature: string; phase: string } | null
  features: KitCockpitAutopilotFeature[]
}

export type KitCockpitStatus = {
  line: string
  branch: string | null
  feature: string | null
  spec: string | null
  stage: string | null
  tasks: { done: number; total: number; items: KitCockpitTask[] } | null
  criteria: KitCockpitCriterion[]
  stops: string[]
  rounds: string[]
  decisions: string[]
  red: number | null
  budget: { used: number; limit: number; percent: number } | null
  evidence: { current: boolean; head: string | null; gates: KitCockpitGate[] } | null
  autopilot: KitCockpitAutopilot | null
  warnings: string[]
}

export type KitCockpitSnapshot =
  | { kind: 'unread' }
  | { kind: 'missing' }
  | { kind: 'error'; reason: string }
  | { kind: 'ok'; status: KitCockpitStatus }

declare module 'claude-code' {
  interface PluginState {
    'kit-cockpit': { snapshot: Shaped<KitCockpitSnapshot> }
  }
}
