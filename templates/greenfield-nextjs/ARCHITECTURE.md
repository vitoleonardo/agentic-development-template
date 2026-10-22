# Architecture

> TypeScript-first AI-agent workflow template for building web applications with parallel development tracks.

---

## Repository Constitution

This section defines the non-negotiable rules that govern this repository.

### Authoritative Artifacts

**Contracts are truth. Markdown is not.**

| Artifact | Location | Authority |
|----------|----------|-----------|
| API definitions | `contracts/api-contract.yaml` | Authoritative |
| Database schema | `contracts/db-schema.yaml` | Authoritative |
| Access control | `contracts/policies.yaml` | Authoritative |
| Quality requirements | `contracts/nfr.yaml` | Authoritative |
| **Design intent** | `product/design.yaml` | **Authoritative** |
| **Tech stack** | `contracts/tech-stack.yaml` | **Authoritative** |
| **Monorepo (growth path)** | `contracts/monorepo.yaml` | **Authoritative** when growth path chosen |
| Slice coordination | `coordination/*.yaml` | Authoritative |
| Source code | `src/**/*.ts` | Authoritative |
| Tests | `tests/**/*.ts` | Authoritative |
| Workflow instructions | `workflows/**/*.md` | Executable (not truth) |
| README.md | Root | Navigational (not truth) |
| ARCHITECTURE.md | Root | Constitutional (this file) |

### Forbidden Documentation Rule

**Only these markdown files are allowed at repository root:**
- `README.md` - Quick start and navigation
- `ARCHITECTURE.md` - This constitution
- `CHANGELOG.md` - Release history (when created)

**Markdown is allowed in these directories:**
- `product/**/*.md` - Product definition (brief, specs)
- `workflows/**/*.md` - Agent-executable instructions

**No other `.md` files anywhere.** Documentation lives in:
- Code comments (for implementation details)
- Contract YAML files (for API/schema/policy specs)
- Type definitions (for interface documentation)

Enforced by: `npm run validate:docs`

### File Naming Convention

**All files must use kebab-case**, except standard root files.

```
ALLOWED:
  my-component.ts       ✓
  user-service.test.ts  ✓
  api-contract.yaml     ✓
  README.md             ✓ (standard exception)
  package.json          ✓ (standard exception)

FORBIDDEN:
  myComponent.ts        ✗ (camelCase)
  UserService.ts        ✗ (PascalCase)
  user_service.ts       ✗ (snake_case)
```

**Why kebab-case?**
- Consistent across all platforms (case-insensitive filesystems)
- URL-friendly (no encoding needed)
- Readable in file trees
- Easy to enforce programmatically

Enforced by: `npm run validate:naming`

---

## Directory Structure

```
.
├── contracts/          # Authoritative API, DB, policy, tech stack
│   ├── tech-stack.yaml # FIXED: Next.js, Next Auth, shadcn, Tailwind, Postgres, Docker
│   ├── api-contract.yaml
│   ├── db-schema.yaml
│   ├── policies.yaml
│   ├── nfr.yaml
│   └── index.yaml
│
├── coordination/       # Parallel work coordination (slice assignments, locks)
│   ├── assignments.yaml
│   ├── slice-graph.yaml
│   ├── file-map.yaml
│   ├── quality-gates.yaml
│   └── .contract-locks.yaml
│
├── workflows/          # Agent-executable workflow instructions
│   └── current/
│       ├── 00-index.md
│       ├── 01-foundation.md
│       ├── 02-shell.md
│       ├── 90-integration-checkpoint.md
│       ├── 91-visual-checkpoint.md
│       ├── 95-hygiene.md
│       ├── 99-release.md
│       └── tracks/
│           ├── track-a/
│           └── track-b/
│
├── src/                # Next.js App Router application
│   ├── app/            # App Router: layout.tsx, page.tsx, api/, error.tsx, loading.tsx
│   ├── components/     # Shared UI (layout, ui from shadcn)
│   ├── features/       # Feature modules (track-isolated)
│   ├── lib/            # Shared utilities, db client
│   └── types/          # Shared TypeScript types
│
├── tests/              # Test files
│   ├── *.test.ts       # Unit/integration (Vitest)
│   └── visual/         # Visual regression (Playwright)
│
├── scripts/            # Build, validation, workflow scripts
├── docker-compose.yml  # Local Postgres + app (optional)
│
├── README.md           # Quick start guide
├── ARCHITECTURE.md     # This file (constitution)
├── package.json        # Dependencies and scripts
├── biome.json          # Lint + format (Biome)
└── tsconfig.json       # TypeScript configuration
```

### Folder Responsibilities

| Folder | Purpose | Who Modifies |
|--------|---------|--------------|
| `contracts/` | Define WHAT the system does | Contract changes via gatekeeper |
| `coordination/` | Coordinate WHO does what | Orchestrator agent |
| `workflows/` | Define HOW agents execute | Workflow agent |
| `src/` | Implement the system | Slice agents (per assignment) |
| `tests/` | Verify the system | Slice agents (per assignment) |
| `scripts/` | Automate validation | Integrator agent |

---

## Growth Path: Monorepo + Backend

**When features and business logic grow**, consider adding a separate backend and moving to a monorepo. See `contracts/tech-stack.yaml` (growth-path) and `contracts/monorepo.yaml`.

### When to Add

- Business logic outgrows Next.js API routes
- Multiple API consumers (web, mobile, partners)
- Need for Deno runtime (tooling, performance, security)
- Clear split between frontend and backend ownership

### Monorepo Layout

```
.
├── apps/
│   ├── web/              # Next.js (existing app moved here)
│   │   ├── src/app/
│   │   ├── src/components/
│   │   ├── prisma/
│   │   └── package.json
│   └── api/               # Deno backend (Express or NestJS)
│       ├── main.ts
│       ├── deno.json      # config, tasks: lint, test, fmt
│       └── import_map.json
├── packages/
│   └── shared/            # Single source for types and schemas
│       ├── src/
│       │   ├── types/    # Entity types, DTOs, API shapes
│       │   ├── schemas/  # Zod schemas (define once; z.infer for types)
│       │   └── constants/
│       ├── package.json
│       └── tsconfig.json
├── contracts/
├── coordination/
└── workflows/
```

### Shared Package — Define Models Once

- **Rule**: Types and Zod schemas live in `packages/shared`. Consumed by `apps/web` (Node) and `apps/api` (Deno). **Do not define models twice.**
- **Prefer**: Zod schemas as source of truth; use `z.infer<typeof schema>` for TypeScript types.
- **No**: Duplicate type definitions in web and api; Prisma schema in shared (stays in apps/web); React/Deno-specific code in shared.

### Backend: Deno + Express or NestJS

- **Runtime**: Deno (use Deno 2 when available).
- **Framework**: Express for simpler APIs; NestJS when complexity warrants (modules, DI, structure).
- **Tooling**: Use Deno built-in only — no extra config:
  - `deno lint`
  - `deno fmt`
  - `deno test`
  - `deno check` (typecheck)

No ESLint, Prettier, or Vitest in `apps/api`; Deno covers lint, format, test, and typecheck.

---

## Module Boundary Rules

### Slice Isolation

Each slice owns specific files declared in `coordination/file-map.yaml`:

```yaml
# Example slice boundary
slices:
  auth-login:
    owns:
      - src/features/auth/login.ts
      - src/features/auth/login.test.ts
    touches:
      - src/features/auth/types.ts  # shared, read-only
```

**Rules:**
1. Slices may only CREATE/MODIFY files in their `owns` list
2. Slices may READ files in their `touches` list
3. Slices must NOT modify files owned by other slices
4. Shared types go in designated shared modules

### Import Boundaries

```
src/
├── app/                # Next.js App Router (layout, pages, api, error, loading)
├── components/         # Shared UI (layout/, ui/ from shadcn)
├── features/           # Feature modules (isolated)
│   ├── auth/
│   └── users/
├── lib/                # Shared utilities, db (Prisma), auth helpers
└── types/              # Shared TypeScript types
```

**Allowed imports:**
- `app/*` → `components/*`, `lib/*`, `types/*` ✓
- `features/*` → `components/*`, `lib/*`, `types/*` ✓
- `features/a` → `features/b` ✗ (cross-feature forbidden)

---

## Design Intent

### Purpose

`product/design.yaml` captures visual and UX constraints **once**, **early**, and makes them **enforceable** across all UI work.

### Why Design Intent Matters

Without explicit design intent:
- Parallel agents interpret "appropriate styling" differently
- Visual consistency is only caught at visual checkpoint (too late)
- UX patterns drift across tracks
- Rework required after integration

With design intent:
- All agents share the same design vocabulary
- Foundation configures design system correctly
- Shell implements correct layout pattern
- Slices receive explicit constraints
- Visual checkpoint validates compliance

### Design Intent Lifecycle

```
1. CAPTURE (before workflows)
   └── Answer UX questions → populate product/design.yaml

2. CONFIGURE (foundation)
   └── Tailwind/shadcn setup reads design.yaml

3. ENFORCE (shell + slices)
   └── Constraints injected into UI-touching workflows

4. VALIDATE (visual checkpoint)
   └── Screenshots reviewed against design.yaml

5. CHANGE (explicit only)
   └── Update design.yaml → rebaseline → regenerate MDs
```

### What Design Intent Is NOT

- Not a design spec or mockup
- Not pixel-perfect instructions
- Not Figma/screenshot-driven
- Not per-slice overridable

It is a **constraint document** that tells agents what direction to follow and what to avoid.

---

## Design Principles

### DRY (Don't Repeat Yourself)
- Extract shared logic ONLY when used 3+ times
- Prefer duplication over wrong abstraction
- Contracts define canonical shapes; code implements them

### KISS (Keep It Simple, Stupid)
- Use the template stack only (see `contracts/tech-stack.yaml`)
- No extra frameworks or libraries beyond the stack
- No abstraction until pattern emerges; no optimization until measured

### SOLID
- **S**ingle Responsibility: One module, one purpose
- **O**pen/Closed: Extend via composition, not modification
- **L**iskov Substitution: Interfaces over concrete types
- **I**nterface Segregation: Small, focused interfaces
- **D**ependency Inversion: Depend on abstractions

### Anti-Patterns to Avoid
- `utils/helpers.ts` sprawl (be specific: `string-utils.ts`)
- God modules (>300 lines is a smell)
- Circular dependencies (use dependency injection)
- Implicit contracts (if it's important, put it in `contracts/`)

---

## Parallel Development Model

### Track Structure

Work proceeds on parallel tracks that don't touch the same files:

```
Track A: auth-login → auth-session → auth-logout
Track B: user-profile → user-settings → user-avatar
         ↓                ↓               ↓
    [Integration Checkpoint: merge all tracks]
```

### Coordination Files

- `coordination/assignments.yaml` - Who owns which slice
- `coordination/slice-graph.yaml` - Dependencies between slices
- `coordination/file-map.yaml` - Which files each slice touches
- `coordination/.contract-locks.yaml` - Prevents concurrent contract edits

### Integration Checkpoints

Checkpoints occur when:
1. All slices in current phase complete
2. Before any slice depends on another track's output
3. Before release

---

## Integration Checkpoint Checklist

Before merging any integration checkpoint:

### Automated Gates
- [ ] `npm run validate:contracts` - Contract schema valid
- [ ] `npm run validate:naming` - All files kebab-case
- [ ] `npm run validate:docs` - No stray markdown files
- [ ] `npm run lint` - No linting errors
- [ ] `npm run format --check` - Code formatted
- [ ] `npm run typecheck` - No TypeScript errors
- [ ] `npm run test` - All tests pass

### Visual Gates (if configured)
- [ ] `npm run storybook:build` - Storybook builds
- [ ] `npm run visual` - Visual regression tests pass

### Manual Review
- [ ] Touched files per slice ≤ threshold in `coordination/quality-gates.yaml`
- [ ] No dead code introduced (unused exports)
- [ ] No duplication >10 lines across slices
- [ ] Contract changes approved by gatekeeper
- [ ] Breaking changes documented

### Post-Merge
- [ ] Update `coordination/assignments.yaml` status
- [ ] Notify dependent slices they can proceed
- [ ] Tag checkpoint: `checkpoint-{phase}-{date}`

---

## Technology Decisions

### Fixed (Template) — see `contracts/tech-stack.yaml`

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Framework | Next.js (App Router) | Fullstack, RSC, API routes, Server Actions; one codebase |
| Auth | NextAuth (Auth.js) | Standard solution; no custom auth |
| UI | shadcn/ui + Tailwind CSS 3 | Components + styling; minimal custom CSS |
| Database | PostgreSQL + Prisma | One ORM, migrations, type-safe client |
| Runtime | Docker (Compose) | Local Postgres + app; one compose file |
| Validation | Zod | Env, API, forms; one lib |
| Lint + Format | Biome | One tool; fewer tokens than ESLint + Prettier |
| Test | Vitest (unit), Playwright (e2e/visual) | Fast, ESM-native; no Jest |
| Language | TypeScript | Type safety, tooling |
| Node | ≥18.0.0 | LTS |
| Contract format | YAML | Human-readable, diff-friendly |

**Do not substitute.** Agents must use this stack only. Saves tokens and code.

---

## Security Boundaries

Defined in `contracts/policies.yaml`:

- **Authentication**: Required for all API endpoints (except health check)
- **Authorization**: Role-based (admin, member, viewer, service)
- **Data classification**: Sensitive fields marked in `db-schema.yaml`
- **Rate limiting**: Configured per endpoint type

See `contracts/nfr.yaml` for security NFRs.

---

## Quality Gates

Defined in `coordination/quality-gates.yaml`:

- **Test coverage**: ≥80% line coverage
- **Bundle size**: <200KB gzipped (initial)
- **API latency**: p95 <500ms
- **Accessibility**: WCAG 2.1 AA

---

*Last updated: 2024-01-01*
