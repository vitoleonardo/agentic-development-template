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

## Tech Stack
```yaml
reads: contracts/tech-stack.yaml
# Next.js App Router only. No src/index.ts, no src/router/*
```

## Acceptance Criteria
- [ ] AC-001: App shell renders without error
- [ ] AC-002: Placeholder route exists (e.g. app/dashboard)
- [ ] AC-003: Root layout uses shell and accepts children
- [ ] AC-004: App-level error boundary (app/error.tsx)
- [ ] AC-005: App-level loading UI (app/loading.tsx)
- [ ] AC-006: Not-found page (app/not-found.tsx)

## Contract Touches
```yaml
reads:
  - contracts/tech-stack.yaml
  - contracts/api-contract.yaml#/paths
  - product/design.yaml
writes: []
```

## File Plan
```yaml
# Next.js App Router — entry is app/layout.tsx; routes are app/**/page.tsx
max-new-files: 6
no-new-folders: false
create:
  - src/components/layout/shell.tsx
  - src/components/layout/error-boundary.tsx
  - src/app/error.tsx
  - src/app/loading.tsx
  - src/app/not-found.tsx
  - src/app/dashboard/page.tsx
modify:
  - src/app/layout.tsx
forbidden:
  - "**/*.stories.tsx"
  - "contracts/**"
  - "tests/**"
patch-budget: 7
```

### Next.js Notes
- **Entry**: `src/app/layout.tsx` (not src/index.ts).
- **Routes**: File-based; add `app/{route}/page.tsx`. No src/router/*.
- **Error**: Use `app/error.tsx`; optional `components/layout/error-boundary.tsx` inside it.
- **Loading**: Use `app/loading.tsx`.

## Visual Plan
```yaml
stories: []
screenshots: []
deferred-to: track-slices
```

## Required Checks
```bash
npm run lint
npm run format -- --check
npm run typecheck
npm run test -- --passWithNoTests
```

## Non-Goals
- No feature components
- No API integration
- No state management setup
- No custom styling beyond design.yaml constraints
