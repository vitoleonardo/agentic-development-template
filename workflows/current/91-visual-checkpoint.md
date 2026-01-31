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

## On Failure
```yaml
action: block-release
notify: [lead-agent, ux-owner]
required:
  - screenshot-diff-review
  - update-baseline OR fix-regression
  - re-run visual checkpoint
```

## Non-Goals
- No functional testing
- No API testing
- No performance testing
