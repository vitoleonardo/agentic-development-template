# Agentic Development Templates

Templates for building software with AI coding agents. Each template is self-contained: copy its folder into a project.

| Template | For | Status |
|----------|-----|--------|
| [greenfield-nextjs](./templates/greenfield-nextjs/) | New Next.js apps built by agents in parallel tracks, contract-first | Usable |
| [claude-kit](./templates/claude-kit/) | Existing TypeScript projects: rules, permissions, hooks, commands, subagents and CI gates for Claude Code | Phase 0 (reference analysis) |

## Repository layout

```
templates/
  greenfield-nextjs/   # contract-first greenfield template (own README, ARCHITECTURE, validators)
  claude-kit/          # governed Claude Code workflow kit
references/            # private source material, gitignored, never published
```
