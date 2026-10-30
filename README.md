# Agentic Development Templates

Templates for building software with AI coding agents. Each template is self-contained: copy its folder into a project.

| Template | For | Status |
|----------|-----|--------|
| [greenfield-nextjs](./templates/greenfield-nextjs/) | New Next.js apps built by agents in parallel tracks, contract-first | Usable |
| [agentic-workflow-kit](./templates/agentic-workflow-kit/) | Existing projects in any language: spec-driven workflow, rules, permissions, hooks, subagents and CI gates for Claude Code. Ships a TypeScript adapter | Usable. TypeScript adapter tested; also installable as the `agentic-workflow-kit` plugin |
| [repo-check](./templates/repo-check/) | Any repository: where delivery is jammed right now (writing, review or release), by interview or a read-only scan | Usable. Plugin `repo-check`, or a single-file prompt |

## Repository layout

```
.claude-plugin/         # plugin marketplace: lists the agentic-workflow-kit and repo-check plugins
templates/
  greenfield-nextjs/    # contract-first greenfield template (own README, ARCHITECTURE, validators)
  agentic-workflow-kit/           # governed Claude Code workflow kit
  repo-check/           # read-only repo assessment: plugin and single-file prompt
references/             # private source material, gitignored, never published
```

## License

MIT. See [LICENSE](./LICENSE).
