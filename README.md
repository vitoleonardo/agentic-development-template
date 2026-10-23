# Agentic Development Templates

Templates for building software with AI coding agents. Each template is self-contained: copy its folder into a project.

| Template | For | Status |
|----------|-----|--------|
| [greenfield-nextjs](./templates/greenfield-nextjs/) | New Next.js apps built by agents in parallel tracks, contract-first | Usable |
| [agentic-workflow-kit](./templates/agentic-workflow-kit/) | Existing projects in any language: spec-driven workflow, rules, permissions, hooks, subagents and CI gates for Claude Code. Ships a TypeScript adapter | Usable. TypeScript adapter tested; also installable as the `agentic-workflow-kit` plugin |

## Repository layout

```
.claude-plugin/         # plugin marketplace: lists the agentic-workflow-kit plugin
templates/
  greenfield-nextjs/    # contract-first greenfield template (own README, ARCHITECTURE, validators)
  agentic-workflow-kit/           # governed Claude Code workflow kit
references/             # private source material, gitignored, never published
```

## License

MIT. See [LICENSE](./LICENSE).
