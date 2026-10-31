# Greenfield Next.js Template

A starting point for a new Next.js app that AI agents build in parallel. You write down what the product is and what its contracts are (API, database, permissions, quality targets). The agents then work through numbered workflow files: two sequential setup steps, feature slices in parallel tracks, and checkpoints that merge the tracks again. Every workflow names the files it may touch, the checks it must pass, and the contracts it reads or locks.

Use it when you start from an empty repository and want the structure decided before the first agent writes code. For an existing codebase, use the [agentic-workflow-kit](../../plugins/agentic-workflow-kit/) instead.

## Quick start

Requirements: Node 20+ and git. The YAML syntax part of the contract check needs `yq` or Python 3 with PyYAML and is skipped without them.

```sh
git clone https://github.com/vitoleonardo/agentic-development-template
cp -R agentic-development-template/templates/greenfield-nextjs ~/code/my-app
cd ~/code/my-app
git init -q && npm install

npm run validate:naming      # kebab-case file names
npm run validate:docs        # Markdown only in allowed places
npm run validate:contracts   # contracts/*.yaml are valid and consistent
npm run validate:design      # product/design.yaml has every required field
```

All four pass on the untouched template. Lint, format, typecheck and tests start working once the foundation workflow has installed the stack (step 3 below). Until then `./scripts/checkpoint --quick` reports them as "not configured".

## How you use it

1. **Describe the product.** `product/brief.md` (what and why), `product/scope.yaml` (features and the track each one belongs to), `product/design.yaml` (visual and UX decisions, made once).
2. **Write the contracts.** `contracts/api-contract.yaml`, `db-schema.yaml`, `policies.yaml` and `nfr.yaml` describe your domain. Code implements the contracts, never the other way round.
3. **Let an agent run the sequential workflows.** Give it `workflows/current/01-foundation.md` (sets up Next.js, Prisma, Biome, Docker Compose), then `02-shell.md` (the app shell and layout).
4. **Run the feature slices in parallel.** For each feature in `scope.yaml`, copy the slice template of its track and fill it in:

   ```sh
   cp workflows/current/tracks/track-a/03-slice-template.md \
      workflows/current/tracks/track-a/03-slice-invite-members.md
   ```

   One agent per track. `coordination/file-map.yaml` declares who owns which files, `coordination/slice-graph.yaml` tracks dependencies and status.
5. **Converge.** `90-integration-checkpoint.md`, `91-visual-checkpoint.md`, `95-hygiene.md`, `99-release.md`, in this order.

`./scripts/checkpoint` runs every gate at once: structure, lint, format, typecheck, tests, contracts, and in full mode Storybook and Playwright visual tests. `--quick` skips the visual gates.

## Rules every agent follows

A workflow file is an instruction, not documentation. An agent that executes one:

1. reads it completely, including acceptance criteria and file plan;
2. starts only when every `depends-on` slice is `COMPLETE`;
3. takes a lock in `coordination/.contract-locks.yaml` before it writes to a contract;
4. creates or changes only the files in its file plan and never touches `forbidden` paths;
5. runs the required checks, and stops on the first failure instead of moving on;
6. sets its status in `slice-graph.yaml` and releases its locks.

When two slices may run at the same time:

| Situation | Parallel? |
|---|---|
| Different tracks, no shared files | Yes |
| Same track | No, one after the other |
| Both only read the same contract | Yes |
| Either one writes to a contract or a shared write zone | No, it needs the lock |
| One depends on the other | No, it waits |

## Fixed stack

Agents do not choose tools. [contracts/tech-stack.yaml](./contracts/tech-stack.yaml) is the source; substitutions are not allowed.

| Layer | Choice |
|---|---|
| Framework | Next.js (App Router), fullstack: API routes and Server Actions, no separate backend |
| Validation | Zod for env, API input and forms |
| Auth | Auth.js (NextAuth) |
| UI | shadcn/ui and Tailwind CSS 3, mobile first |
| Database | PostgreSQL and Prisma |
| Local runtime | Docker Compose |
| Lint and format | Biome |
| Tests | Vitest (unit), Playwright (e2e and visual) |

When the app outgrows one Next.js codebase, [contracts/monorepo.yaml](./contracts/monorepo.yaml) describes the next step: `apps/web`, `apps/api` and a shared package for models and types.

## Layout

```text
product/        what you are building: brief, scope, design intent
contracts/      the source of truth: API, database, policies, NFRs, stack
coordination/   tracks, file ownership, dependencies, locks, quality gates
workflows/      the instructions agents execute, in order
scripts/        validators, check wrappers and the checkpoint runner
src/, tests/    application code and tests (an example component to start from)
ARCHITECTURE.md the rules of the repository in full
```

[ARCHITECTURE.md](./ARCHITECTURE.md) has the complete rules: which artifacts are authoritative, naming, folder responsibilities, the growth path and the quality gates.

## Limits

- The workflows coordinate agents through files and locks. Nothing stops an agent that ignores them; review each slice before you merge it.
- `scripts/generate-workflows` is a starting point, not a generator yet: it reads the inputs but copies no slices. Copy the slice templates by hand, as in step 4.
- The template contains no application code beyond an example component. The foundation workflow installs the stack.

## License

MIT. See [LICENSE](../../LICENSE).
