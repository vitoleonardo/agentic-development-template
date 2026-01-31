# 01 Foundation

## Metadata
```yaml
id: foundation-001
track: sequential
depends-on: []
risk-tags: [security, data]
conflict-risk: low
```

## Acceptance Criteria
- [ ] AC-001: Project structure matches file-map.yaml
- [ ] AC-002: All contract schemas valid (contracts/*.yaml)
- [ ] AC-003: TypeScript config strict mode enabled
- [ ] AC-004: ESLint + Prettier configured
- [ ] AC-005: Base CI pipeline defined

## Contract Touches
```yaml
reads:
  - contracts/api.yaml#/info
  - contracts/db.yaml#/version
writes: []
```

## File Plan
```yaml
max-new-files: 5
no-new-folders: false
create:
  - src/index.ts
  - src/types/index.ts
  - .eslintrc.json
  - .prettierrc
  - tsconfig.json
modify: []
forbidden:
  - "**/*.test.ts"
  - "contracts/**"
patch-budget: 5
```

## Required Checks
```bash
npm run lint
npm run format:check
npm run typecheck
```

## Non-Goals
- No business logic
- No UI components
- No test implementation
- No CI execution (define only)
