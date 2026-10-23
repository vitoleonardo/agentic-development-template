# Agentic Development Template

> TypeScript-first AI-agent workflow template for building web applications with parallel development tracks.

## Tech Stack (Fixed)

**Do not substitute.** See [contracts/tech-stack.yaml](./contracts/tech-stack.yaml).

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Framework | Next.js (App Router) | Fullstack, API routes, Server Actions; one codebase |
| Auth | Next Auth (Auth.js) | Standard; no custom auth |
| UI | shadcn/ui + Tailwind CSS 3 | Components + styling; minimal code |
| Database | PostgreSQL + Prisma | One ORM, migrations, type-safe client |
| Runtime | Docker (Compose) | Local Postgres + app |
| Validation | Zod | Env, API, forms |
| Lint/Format | Biome | One tool; fewer tokens |
| Test | Vitest (unit), Playwright (e2e/visual) | Fast, ESM-native |

Using this stack keeps the workflow simple and reduces tokens and code.

**Growth path:** When features and business logic grow, see [contracts/monorepo.yaml](./contracts/monorepo.yaml): add a **monorepo** (apps/web, apps/api, packages/shared), a **Deno backend** (Express or NestJS) using Deno’s built-in lint/test/fmt, and a **shared package** so models are defined once and reused by web and api.

## Quick Start

```bash
# Clone and install
git clone <repo-url>
cd agentic-development-template
npm install

# Validate repository structure
npm run validate:naming    # Check kebab-case file names
npm run validate:docs      # Check markdown locations
npm run validate:contracts # Check contract integrity

# Development (configure tooling first)
npm run typecheck          # TypeScript checking
npm run lint               # Linting
npm run format             # Formatting
npm run test               # Run tests

# Visual development (optional, requires setup)
npm run storybook          # Component development
npm run visual             # Visual regression tests
```

## Project Structure

```
.
├── contracts/        # Authoritative definitions (API, DB, policies, NFRs)
├── coordination/     # Parallel work coordination (assignments, file maps)
├── workflows/        # Agent-executable workflow instructions
├── src/              # Application source code
├── tests/            # Test files (unit, integration, visual)
├── scripts/          # Build and validation scripts
├── ARCHITECTURE.md   # Repository constitution and design principles
└── README.md         # This file
```

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed structure and rules.

## Canonical Scripts

All scripts are in `scripts/` and exposed via `package.json`:

### Validation (Always Available)

| Command | Script | Purpose |
|---------|--------|---------|
| `npm run validate:naming` | `scripts/validate-naming` | Enforce kebab-case file names |
| `npm run validate:docs` | `scripts/validate-docs` | Ensure markdown only in allowed locations |
| `npm run validate:contracts` | `scripts/validate-contracts` | Validate contract YAML files |

### Development (Configure Per Project)

| Command | Script | Purpose |
|---------|--------|---------|
| `npm run typecheck` | `scripts/typecheck` | TypeScript type checking |
| `npm run lint` | `scripts/lint` | Run linter (ESLint or Biome) |
| `npm run format` | `scripts/format` | Run formatter (Prettier or Biome) |
| `npm run test` | `scripts/test` | Run test suite (Vitest or Jest) |

### Visual (Optional Setup Required)

| Command | Script | Purpose |
|---------|--------|---------|
| `npm run storybook` | `scripts/storybook` | Start Storybook dev server |
| `npm run storybook:build` | `scripts/storybook build` | Build static Storybook |
| `npm run visual` | `scripts/visual` | Run Playwright visual tests |
| `npm run visual:update` | `scripts/visual update` | Update visual snapshots |

## Configuring Tooling

This template uses a **fixed stack** (see Tech Stack above). Use **Biome** for lint + format; do not add ESLint + Prettier.

### Linting & Formatting

**Option A: Biome (recommended for speed)**
```bash
npm install -D @biomejs/biome
npx biome init
```

**Option B: ESLint + Prettier**
```bash
npm init @eslint/config@latest
npm install -D prettier
echo '{}' > .prettierrc
```

### Testing

**Option A: Vitest (recommended for Vite projects)**
```bash
npm install -D vitest
```

**Option B: Jest**
```bash
npm install -D jest @types/jest ts-jest
npx ts-jest config:init
```

### Visual Testing (Optional)

```bash
# Storybook
npx storybook@latest init

# Playwright
npm install -D @playwright/test
npx playwright install
```

## Key Concepts

### Contracts Are Truth

All system definitions live in `contracts/`:
- `api-contract.yaml` - API endpoints, request/response schemas
- `db-schema.yaml` - Database entities and relationships
- `policies.yaml` - Roles, permissions, access rules
- `nfr.yaml` - Performance, security, accessibility requirements

### Authoritative vs Non-Authoritative Artifacts

| Artifact Type | Location | Authority | Purpose |
|---------------|----------|-----------|---------|
| Contracts | `contracts/*.yaml` | **Authoritative** | Source of truth for API/DB/policies |
| Coordination | `coordination/*.yaml` | **Authoritative** | Source of truth for assignments/deps |
| Source Code | `src/**/*.ts` | **Authoritative** | Implementation |
| Tests | `tests/**/*.ts` | **Authoritative** | Verification |
| Workflows | `workflows/**/*.md` | **Executable** | Agent instructions (not truth) |
| README.md | Root | **Navigational** | Quick start (not truth) |
| ARCHITECTURE.md | Root | **Constitutional** | Repository rules |

### Parallel Development Tracks

Work is divided into independent slices that can execute in parallel:
- Slices are assigned in `coordination/assignments.yaml`
- File ownership is declared in `coordination/file-map.yaml`
- Dependencies are tracked in `coordination/slice-graph.yaml`

### Workflow Instructions

Agent-executable instructions live in `workflows/`:
- Sequential phases (foundation → shell → slices → integration)
- Parallel tracks within phases
- Integration checkpoints to merge work

## Executing Workflows

A workflow MD is **agent-executable instruction** — not documentation.

### What "Execute a Workflow MD" Means

1. **Read completely** — Understand metadata, acceptance criteria, file plan
2. **Verify dependencies** — All `depends-on` items must have status: COMPLETE
3. **Acquire locks** — Check `coordination/.contract-locks.yaml` for contract touches
4. **Follow File Plan exactly** — Only create/modify files listed; respect `forbidden` paths
5. **Run Required Checks** — Execute all checks after completing the work
6. **Update status** — Set slice status in `coordination/slice-graph.yaml`
7. **Release locks** — Clear any acquired contract locks

### Rule Violation Policy

**If any check fails: STOP. Fix the issue before proceeding.**

- Do not proceed with failing gates
- Do not skip steps to "fix later"
- Do not modify files outside your File Plan
- Do not ignore contract lock conflicts

### Parallelization Decision Rules

| Condition | Decision |
|-----------|----------|
| Different tracks, no shared files | ✅ Parallel OK |
| Same track | ❌ Sequential only |
| Shared-write-zone touched | ❌ Sequential (acquire lock) |
| Cross-track dependency exists | ❌ Wait for dependency |
| Both read-only on same contract | ✅ Parallel OK |
| Either writes to contract | ❌ Sequential (lock required) |

Check `coordination/file-map.yaml` for `shared-write-zones` and `lock-required` paths.

### Visual Check Failure Criteria

Visual regression tests fail when:
- Screenshot diff exceeds **0.1% threshold**
- Accessibility audit finds WCAG 2.1 AA violations
- Responsive breakpoints render incorrectly

**On visual failure:**
1. Review screenshot diff (do not auto-approve)
2. Determine: intentional change or regression?
3. If intentional: update baseline with `npm run visual:update`
4. If regression: fix the code, re-run visual tests

## Repository Rules

1. **Kebab-case only** - All files must use kebab-case naming
2. **No stray markdown** - Only `README.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, and `workflows/**/*.md`
3. **Contracts are authoritative** - Code implements contracts, not the reverse
4. **Explicit file ownership** - Slices only modify files they own
5. **File Plan enforcement** - Never create/modify files outside your slice's File Plan

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the complete constitution.

## Getting Started (New App)

### 1. Define Your Product

```bash
# Edit these files first:
product/brief.md      # What are you building and why?
product/scope.yaml    # What features, which tracks?
```

### 2. Update Contracts

```bash
# Modify to match your domain:
contracts/api-contract.yaml   # Your API endpoints
contracts/db-schema.yaml      # Your database entities
contracts/policies.yaml       # Your access control rules
contracts/nfr.yaml            # Your quality requirements
```

### 3. Configure Tooling

```bash
# Option A: Biome (recommended)
npm install -D @biomejs/biome
npx biome init

# Option B: ESLint + Prettier
npm init @eslint/config@latest
npm install -D prettier
echo '{}' > .prettierrc
```

### 4. Validate Setup

```bash
./scripts/checkpoint --quick
```

### 5. Execute Workflows (in order)

```bash
# Sequential (blocking):
workflows/current/01-foundation.md   # Execute first
workflows/current/02-shell.md        # Execute after foundation

# Parallel (after shell complete):
# Copy slice template for each feature in scope.yaml
cp workflows/current/tracks/track-a/03-slice-template.md \
   workflows/current/tracks/track-a/03-slice-{feature-name}.md

# Convergence (after all slices):
workflows/current/90-integration-checkpoint.md
workflows/current/91-visual-checkpoint.md
workflows/current/95-hygiene.md
workflows/current/99-release.md
```

## License

MIT
