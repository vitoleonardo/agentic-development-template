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

## Contract Touches
```yaml
reads:
  # - contracts/api.yaml#/paths/{endpoint}
  # - contracts/db.yaml#/tables/{table}
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
  # - src/features/{feature}/hooks/use-{hook}.ts
modify:
  # - src/router/routes.ts
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
npm run format:check
npm run typecheck
npm run test -- --testPathPattern="{feature}"
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
