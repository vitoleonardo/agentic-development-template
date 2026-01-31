# 02 Shell

## Metadata
```yaml
id: shell-001
track: sequential
depends-on: [foundation-001]
risk-tags: [ux, perf]
conflict-risk: low
```

## Acceptance Criteria
- [ ] AC-001: App shell renders without error
- [ ] AC-002: Router configured with placeholder routes
- [ ] AC-003: Layout component accepts children
- [ ] AC-004: Error boundary at root level
- [ ] AC-005: Loading state component exists

## Contract Touches
```yaml
reads:
  - contracts/api.yaml#/paths
writes: []
```

## File Plan
```yaml
max-new-files: 6
no-new-folders: false
create:
  - src/app.tsx
  - src/components/layout/shell.tsx
  - src/components/layout/error-boundary.tsx
  - src/components/ui/loading.tsx
  - src/router/index.ts
  - src/router/routes.ts
modify:
  - src/index.ts
forbidden:
  - "**/*.stories.tsx"
  - "contracts/**"
  - "tests/**"
patch-budget: 7
```

## Visual Plan
```yaml
stories: []
screenshots: []
deferred-to: track-slices
```

## Required Checks
```bash
npm run lint
npm run format:check
npm run typecheck
npm run test -- --passWithNoTests
```

## Non-Goals
- No feature components
- No API integration
- No state management setup
- No styling beyond structure
