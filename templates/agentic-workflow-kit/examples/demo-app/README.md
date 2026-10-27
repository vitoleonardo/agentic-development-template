# Demo app: Split

A small Next.js 16 app for trying the kit. Type in who paid what for whom; it shows the fewest payments that settle everything. The logic lives in `src/features/split/`, with tests named after the acceptance criteria in `specs/expense-split.md`.

The kit is not committed here, so you install it the way you would in your own project.

## Try it (about 5 minutes)

```sh
# from templates/agentic-workflow-kit
cp -R examples/demo-app /tmp/demo
./install.sh /tmp/demo --adapter typescript --preset nextjs
cd /tmp/demo && npm ci
git init -q -b main && git add -A && git commit -qm "Demo with kit"
.claude/bin/check test        # 12 tests, all green
claude                        # accept the trust prompt once
```

The installer keeps the demo's own `specs/README.md`, because it already lists the existing feature.

## Things to try

1. **The workflow.** Run `/ship-feature Below the transfers, show how much each person paid in total.`
   - It extends the existing spec instead of creating a second one and asks before deciding open points.
   - After you approve the spec, it writes a plan to `.work/` and waits again.
   - After you approve the plan, implementer subagents build it test first, the reviewer checks it, and it writes a PR description. It asks before pushing.
2. **A hook catching a broken edit.** Ask: "Change shares in src/features/split/settle.ts to round every share down." The edit breaks SPLIT-AC2. The hook runs the related tests, Claude sees the failure in the same turn, and the session does not end quietly while it is red.
3. **The guardrails.** Ask Claude to `cat .env` or run `rm -rf src`. The permission rules or the guard hook block both.
4. **The CI gates.** Push a branch to a GitHub repository and open a pull request. `.github/workflows/quality-gates.yml` runs typecheck, lint, tests with coverage of the changed files, and the build.
