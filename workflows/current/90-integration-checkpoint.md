# 90 Integration Checkpoint

## Metadata
```yaml
id: checkpoint-integration
track: convergence
depends-on: all-active-slices
risk-tags: [data, security]
conflict-risk: high
```

## Trigger Conditions
```yaml
any-of:
  - all-tracks-complete: true
  - slice-count-since-last: 3
  - high-risk-slice-complete: true
  - cross-track-dependency-resolved: true
```

## Acceptance Criteria
- [ ] AC-001: All slice statuses in slice-graph.yaml are COMPLETE
- [ ] AC-002: No contract lock conflicts in .contract-locks.yaml
- [ ] AC-003: Cross-track imports resolve correctly
- [ ] AC-004: Full test suite passes
- [ ] AC-005: No TypeScript errors across codebase
- [ ] AC-006: Bundle size within NFR limits

## Contract Touches
```yaml
reads:
  - contracts/api.yaml#/**
  - contracts/db.yaml#/**
  - contracts/nfr.yaml#/bundle-size
  - contracts/nfr.yaml#/performance
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
npm run lint
npm run format -- --check
npm run typecheck
npm run test
npm run build
npm run validate:contracts
npm run validate:docs
npm run validate:naming
```

## Validation Matrix
```yaml
cross-track:
  - import-resolution: tsc --noEmit
  - circular-deps: madge --circular src/
  - api-contract: npm run validate:api
data-integrity:
  - schema-match: npm run validate:db
  - migration-order: npm run validate:migrations
```

## On Failure
```yaml
action: block-all-tracks
notify: [lead-agent, track-owners]
required:
  - identify-failing-slice
  - rollback-or-fix decision
  - re-run checkpoint after fix
```

## Non-Goals
- No new features
- No refactoring
- No dependency updates
