# 01 Foundation

## Metadata
```yaml
id: foundation-001
track: sequential
depends-on: []
risk-tags: [security, data]
conflict-risk: low
```

## Design System Setup
```yaml
# If product/design.yaml exists, foundation must configure the design system
reads: product/design.yaml (optional)
configures:
  - Tailwind CSS with colors from design.yaml
  - CSS variables for theme switching (light/dark/system)
  - Spacing scale matching density.level
  - Typography defaults matching typography section
```

### Design-Aware Foundation Tasks
If `product/design.yaml` exists:
- [ ] Configure Tailwind with primary/accent colors from design.yaml
- [ ] Set up CSS custom properties for theme switching
- [ ] Configure spacing scale matching density.level
- [ ] Add shadcn/ui components with design-compliant theme

If `product/design.yaml` does not exist:
- [ ] Use sensible defaults (Tailwind defaults, system theme)
- [ ] Log warning: "No design.yaml found - using defaults"

## Acceptance Criteria
- [ ] AC-001: Project structure matches file-map.yaml
- [ ] AC-002: All contract schemas valid (contracts/*.yaml)
- [ ] AC-003: TypeScript config strict mode enabled
- [ ] AC-004: ESLint + Prettier configured
- [ ] AC-005: Base CI pipeline defined
- [ ] AC-006: Design system configured (if design.yaml exists)

## Contract Touches
```yaml
reads:
  - contracts/api.yaml#/info
  - contracts/db.yaml#/version
  - product/design.yaml (optional)
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
