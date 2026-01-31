# Agentic Development Template

> TypeScript-first AI-agent workflow template for building web applications with parallel development tracks.

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

This template is **framework-agnostic**. Configure tooling based on project needs:

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

## Repository Rules

1. **Kebab-case only** - All files must use kebab-case naming
2. **No stray markdown** - Only `README.md`, `ARCHITECTURE.md`, and `workflows/**/*.md`
3. **Contracts are authoritative** - Code implements contracts, not the reverse
4. **Explicit file ownership** - Slices only modify files they own

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the complete constitution.

## License

MIT
