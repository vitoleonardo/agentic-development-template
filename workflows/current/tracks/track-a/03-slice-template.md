# Track A: Slice Template

> Copy this file as `03-slice-{feature-name}.md` for each slice.

## Metadata
```yaml
slice-id: a-{NNN}-{feature-name}
track: track-a
depends-on:
  - shell-001
  # Add slice dependencies: a-001-*, b-001-*, etc.
risk-tags: []  # Options: security, perf, ux, data, unknown
conflict-risk: low  # Options: low, med, high
```

## Design Constraints
<!-- GENERATED: Injected by generate-workflows for slices with risk-tags: [ux] -->
<!-- If this slice has NO 'ux' risk tag, this section can be removed -->
```yaml
# From product/design.yaml - DO NOT DEVIATE
source: product/design.yaml
theme: ${THEME_MODE}
primary-color: ${PRIMARY_COLOR}
density: ${DENSITY_LEVEL}
personality: ${PERSONALITY_TONE}
navigation: ${UX_NAVIGATION}
feedback: ${UX_FEEDBACK}
loading: ${UX_LOADING}
forbidden:
  # ${FORBIDDEN_PATTERNS}
```

### Enforcement Rules
- Use ONLY colors defined in design.yaml color section
- Use ONLY spacing consistent with declared density level
- Match declared personality tone in all copy and UI decisions
- NEVER use any pattern listed in forbidden[]
- If uncertain, reference product/design.yaml or ask for clarification

### Violations (Auto-Fail)
- Inventing new colors outside design system
- Custom spacing inconsistent with density level
- Implementing any forbidden pattern
- Deviating from declared UX patterns

## Acceptance Criteria
```yaml
# Use sequential IDs per slice
- id: AC-001
  desc: "{Measurable outcome}"
  verify: "{Command or manual step}"
- id: AC-002
  desc: "{Measurable outcome}"
  verify: "{Command or manual step}"
```

## Tech Stack
```yaml
reads: contracts/tech-stack.yaml
# Next.js App Router; no src/router. Routes = app/**/page.tsx
```

## Contract Touches
```yaml
reads:
  # - contracts/api-contract.yaml#/paths/{endpoint}
  # - contracts/db-schema.yaml#/tables/{table}
  # - contracts/policies.yaml#/{policy-id}
  # - contracts/nfr.yaml#/{requirement-id}
writes:
  # Only if slice extends contract (requires approval)
```

## File Plan
```yaml
max-new-files: 4
no-new-folders: true
create:
  # - src/features/{feature}/index.ts
  # - src/features/{feature}/components/{component}.tsx
  # - src/app/{feature}/page.tsx  # Next.js route
modify:
  # - src/app/layout.tsx  # only when adding nav link
forbidden:
  - "src/features/track-b-*/**"
  - "contracts/**"
  - "coordination/**"
patch-budget: 6
```

## Visual Plan
```yaml
stories:
  # - storybook/stories/{feature}/{component}.stories.tsx
screenshots:
  # - tests/visual/{feature}/{component}.spec.ts
```

## Required Checks
```bash
npm run lint
npm run format -- --check
npm run typecheck
npm run test -- --testPathPattern="{feature}"
npm run validate:contracts
npm run validate:docs
npm run validate:naming
# If visual plan exists:
# npm run storybook:build
# npm run test:visual -- --testPathPattern="{feature}"
```

## Non-Goals
```yaml
# Explicit scope boundaries
- no-cross-track: true  # Do not modify track-b files
- no-contract-writes: true  # Unless pre-approved
- no-infra-changes: true  # No CI/CD modifications
- excluded-features:
    # - "{adjacent-feature-name}"
```

---

## Execution Checklist
```
[ ] 1. Lock contracts (coordination/.contract-locks.yaml)
[ ] 2. Verify dependencies complete
[ ] 3. Execute file plan (create/modify only listed)
[ ] 4. Run required checks
[ ] 5. Update slice-graph.yaml status
[ ] 6. Release contract locks
[ ] 7. Signal checkpoint if trigger met
```
