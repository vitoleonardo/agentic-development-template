# 95 Hygiene

## Metadata
```yaml
id: hygiene-001
track: convergence
depends-on: [checkpoint-integration, checkpoint-visual]
risk-tags: [security]
conflict-risk: low
```

## Acceptance Criteria
- [ ] AC-001: No lint errors
- [ ] AC-002: No format violations
- [ ] AC-003: No TypeScript errors (strict)
- [ ] AC-004: No unused exports
- [ ] AC-005: No circular dependencies
- [ ] AC-006: All files kebab-case
- [ ] AC-007: No secrets in codebase
- [ ] AC-008: License headers present (if required)
- [ ] AC-009: Documentation links valid

## Contract Touches
```yaml
reads:
  - contracts/nfr.yaml#/code-quality
  - contracts/policies.yaml#/naming-conventions
writes: []
```

## File Plan
```yaml
max-new-files: 0
no-new-folders: true
create: []
modify: []
forbidden:
  - "**/*"
patch-budget: 0
```

## Required Checks
```bash
# Code quality (Biome = lint + format)
npm run lint
npm run format -- --check
npm run typecheck

# Structural
npx madge --circular src/
npx ts-unused-exports tsconfig.json

# Naming
npm run validate:naming

# Security
npm run audit
npx secretlint "**/*"

# Contracts + docs
npm run validate:contracts
npm run validate:docs
npx markdown-link-check docs/**/*.md 2>/dev/null || true
```

## Validation Matrix
```yaml
lint-format:
  tool: biome
  config: biome.json
  max-warnings: 0
types:
  strict: true
  no-implicit-any: true
naming:
  pattern: kebab-case
  exceptions: []
security:
  audit-level: moderate
  secret-patterns: [aws, api_key, password, token]
```

## Auto-Fix Rules
```yaml
allowed:
  - npm run lint -- --write
  - npm run format
forbidden:
  - any src/ logic changes
  - any test modifications
```

## On Failure
```yaml
action: attempt-auto-fix
max-retries: 1
on-retry-fail:
  action: block-release
  notify: [lead-agent]
```

## Non-Goals
- No feature work
- No test additions
- No dependency updates (except security)
