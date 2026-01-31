# 99 Release

## Metadata
```yaml
id: release-001
track: sequential
depends-on: [hygiene-001]
risk-tags: [security, data]
conflict-risk: low
```

## Pre-Conditions
```yaml
required:
  - hygiene-001: COMPLETE
  - checkpoint-integration: COMPLETE
  - checkpoint-visual: COMPLETE
  - all-slices: COMPLETE
  - contract-locks: empty
```

## Acceptance Criteria
- [ ] AC-001: Version bumped per semver
- [ ] AC-002: Changelog updated
- [ ] AC-003: Build artifacts generated
- [ ] AC-004: All checks green
- [ ] AC-005: Git tag created
- [ ] AC-006: Release notes drafted

## Contract Touches
```yaml
reads:
  - contracts/api.yaml#/info/version
  - contracts/nfr.yaml#/**
writes: []
```

## File Plan
```yaml
max-new-files: 1
no-new-folders: true
create:
  - CHANGELOG.md (append only)
modify:
  - package.json (version field only)
forbidden:
  - "src/**"
  - "contracts/**"
  - "tests/**"
patch-budget: 2
```

## Required Checks
```bash
# Final validation
npm run lint
npm run typecheck
npm run test
npm run build

# Release prep
npm version {patch|minor|major} --no-git-tag-version
npm run changelog:generate

# Artifact validation
npm pack --dry-run
```

## Release Checklist
```
[ ] 1. Verify all workflows COMPLETE
[ ] 2. Determine version bump type
[ ] 3. Update package.json version
[ ] 4. Generate/update CHANGELOG.md
[ ] 5. Create release commit
[ ] 6. Tag release: git tag v{version}
[ ] 7. Build final artifacts
[ ] 8. Archive coordination state
```

## Version Bump Rules
```yaml
patch:
  - bug fixes only
  - no new features
  - no breaking changes
minor:
  - new features
  - backward compatible
  - no breaking changes
major:
  - breaking changes
  - api contract version bump
```

## Post-Release
```yaml
actions:
  - archive: coordination/ → coordination/archive/{version}/
  - reset: slice-graph.yaml statuses to PENDING
  - clear: .contract-locks.yaml
  - notify: [stakeholders]
```

## Non-Goals
- No feature work
- No bug fixes (defer to next cycle)
- No contract modifications
