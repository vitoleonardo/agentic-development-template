# 01 Foundation

## Metadata
```yaml
id: foundation-001
track: sequential
depends-on: []
risk-tags: [security, data]
conflict-risk: low
```

## Tech Stack (Fixed)
```yaml
# MUST use contracts/tech-stack.yaml — no substitutions
reads: contracts/tech-stack.yaml
stack: Next.js, Next Auth, shadcn, Tailwind 3, Postgres (Prisma), Docker, Biome, Vitest, Zod
```

## Acceptance Criteria
- [ ] AC-001: Project structure matches file-map.yaml
- [ ] AC-002: All contract schemas valid (contracts/*.yaml)
- [ ] AC-003: TypeScript config strict mode enabled
- [ ] AC-004: Biome configured (lint + format; no ESLint/Prettier)
- [ ] AC-005: Next.js, Prisma, Tailwind, NextAuth deps present
- [ ] AC-006: Docker Compose for local Postgres
- [ ] AC-007: Design system configured from design.yaml (if exists)

## Contract Touches
```yaml
reads:
  - contracts/tech-stack.yaml
  - contracts/api-contract.yaml#/info
  - contracts/db-schema.yaml#/version
  - product/design.yaml (optional)
writes: []
```

## File Plan
```yaml
# Next.js App Router — no src/index.ts; entry is src/app/layout.tsx (shell step)
max-new-files: 8
no-new-folders: false
create:
  - biome.json
  - tsconfig.json
  - .env.example
  - prisma/schema.prisma
  - docker-compose.yml
  - src/types/index.ts
  - src/lib/db.ts
  - next.config.ts
modify:
  - package.json
forbidden:
  - "**/*.test.ts"
  - "contracts/**"
  - ".eslintrc*"
  - ".prettierrc*"
patch-budget: 6
```

## Required Checks
```bash
npm run lint
npm run format -- --check
npm run typecheck
npm run validate:contracts
```

## Non-Goals
- No UI components (shell step)
- No app routes (shell step)
- No test implementation
- No CI execution (define only)
