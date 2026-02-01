# 02 Shell

## Metadata
```yaml
id: shell-001
track: sequential
depends-on: [foundation-001]
risk-tags: [ux, perf]
conflict-risk: low
```

## Design Constraints
```yaml
# Shell must respect design intent from product/design.yaml
reads: product/design.yaml
enforces:
  theme.mode: "CSS variables for light/dark/system theming"
  density.level: "Default spacing scale in layout components"
  ux.navigation: "Shell layout structure (sidebar vs topnav)"
  typography: "Font family and base size configuration"
  responsive: "Breakpoint configuration in Tailwind/CSS"
```

### Shell-Specific Design Rules
- Layout structure MUST match `ux.navigation` (sidebar/topnav/hybrid)
- Spacing MUST be consistent with `density.level`
- Theme toggle (if applicable) MUST respect `theme.mode`
- Error boundary styling MUST use semantic colors from `color.semantic`
- Loading states MUST use pattern from `ux.loading`

### Design Validation
Before marking shell complete:
- [ ] CSS variables configured for theme switching
- [ ] Spacing scale matches density.level
- [ ] Navigation matches ux.navigation pattern
- [ ] No hardcoded colors outside design system

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
- No custom styling beyond design.yaml constraints
