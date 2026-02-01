# 91 Visual Checkpoint

## Metadata
```yaml
id: checkpoint-visual
track: convergence
depends-on: [checkpoint-integration]
risk-tags: [ux]
conflict-risk: low
```

## Trigger Conditions
```yaml
all-of:
  - integration-checkpoint: COMPLETE
  - visual-plan-exists: true
```

## Acceptance Criteria
- [ ] AC-001: All Storybook stories build without error
- [ ] AC-002: Visual regression tests pass (< 0.1% diff threshold)
- [ ] AC-003: Accessibility audit passes (axe-core)
- [ ] AC-004: Responsive breakpoints render correctly
- [ ] AC-005: Theme variants (light/dark) consistent

## Contract Touches
```yaml
reads:
  - contracts/nfr.yaml#/accessibility
  - contracts/nfr.yaml#/browser-support
  - product/design.yaml  # Design intent validation
writes: []
```

## File Plan
```yaml
max-new-files: 0
no-new-folders: true
create: []
modify: []
forbidden:
  - "src/**"
  - "contracts/**"
patch-budget: 0
```

## Visual Plan
```yaml
stories:
  - storybook/stories/**/*.stories.tsx
screenshots:
  - tests/visual/**/*.spec.ts
```

## Required Checks
```bash
npm run storybook:build
npm run test:visual
npm run test:a11y
# Responsive validation
npm run test:visual -- --project=mobile
npm run test:visual -- --project=tablet
npm run test:visual -- --project=desktop
```

## Validation Matrix
```yaml
visual-regression:
  tool: playwright
  threshold: 0.1%
  baseline-dir: tests/visual/__snapshots__
accessibility:
  tool: axe-core
  standards: [wcag2aa]
  ignore: []
responsive:
  breakpoints: [320, 768, 1024, 1440]
```

## Design Intent Validation
```yaml
# Validates UI against product/design.yaml constraints
source: product/design.yaml

checks:
  - id: theme-consistency
    desc: "All pages respect theme.mode (light/dark/system)"
    verify: "No hardcoded light/dark colors outside theme system"
    severity: error

  - id: color-compliance
    desc: "Only declared colors from design palette used"
    verify: "Grep for hex/rgb values not in Tailwind/shadcn config"
    severity: error

  - id: density-compliance
    desc: "Spacing matches density.level setting"
    verify: "Audit padding/margin usage against density spec"
    severity: warning

  - id: forbidden-patterns
    desc: "No forbidden patterns present"
    verify: "Manual review against design.yaml forbidden[]"
    severity: error

  - id: ux-pattern-compliance
    desc: "UX patterns match declared preferences"
    verify: "Navigation, feedback, loading match design.yaml ux section"
    severity: error

  - id: typography-compliance
    desc: "Font usage follows typography constraints"
    verify: "Max 3 font weights, minimum body text size"
    severity: warning

ux-regressions:
  # Detect semantic UX changes, not just pixel diffs
  - id: nav-position-drift
    baseline: "Navigation structure per ux.navigation"
    detect: "Layout shift in shell component"

  - id: feedback-pattern-drift
    baseline: "Feedback pattern per ux.feedback"
    detect: "Different error/success patterns appearing"

  - id: loading-pattern-drift
    baseline: "Loading pattern per ux.loading"
    detect: "Different loading indicators appearing"

on-design-violation:
  action: block-merge
  required:
    - Identify violating component(s)
    - Reference design.yaml constraint violated
    - Fix violation OR request design.yaml update
    - Re-run visual checkpoint
```

## On Failure
```yaml
action: block-release
notify: [lead-agent, ux-owner]
required:
  - screenshot-diff-review
  - design-intent-review (check against product/design.yaml)
  - update-baseline OR fix-regression
  - re-run visual checkpoint

design-failure-protocol:
  # If failure is due to design intent violation (not just pixel diff)
  - Identify which design.yaml constraint was violated
  - Determine if violation is intentional design change or error
  - If intentional: update design.yaml, bump version, rebaseline
  - If error: fix component to comply with design.yaml
  - Document decision in visual checkpoint report
```

## Non-Goals
- No functional testing
- No API testing
- No performance testing
