# Agentic Development Templates

Templates for building software with AI coding agents. Each template is self-contained: copy its folder into a project.

| Template | For | Status |
|----------|-----|--------|
| [greenfield-nextjs](./templates/greenfield-nextjs/) | New Next.js apps built by agents in parallel tracks, contract-first | Usable |
| [claude-kit](./templates/claude-kit/) | Existing projects in any language: spec-driven workflow, rules, permissions, hooks, subagents and CI gates for Claude Code. Ships a TypeScript adapter | Phase 1 done (rules, permissions, adapter) |

## Repository layout

```
templates/
  greenfield-nextjs/   # contract-first greenfield template (own README, ARCHITECTURE, validators)
  claude-kit/          # governed Claude Code workflow kit
references/            # private source material, gitignored, never published
```
