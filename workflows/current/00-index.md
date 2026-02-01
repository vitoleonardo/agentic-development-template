# Workflow Index

## Pre-Requisites

Before executing any workflow:
1. `product/brief.md` - Product intent defined
2. `product/scope.yaml` - Features scoped to tracks
3. `product/design.yaml` - Design intent captured (recommended for UI projects)
4. `contracts/*.yaml` - Contracts defined

## Execution Order

```
PRE-WORKFLOW (human input):
  product/brief.md      → Define what we're building
  product/design.yaml   → Capture design intent (UX questions)
  product/scope.yaml    → Define features and tracks

SEQUENTIAL (blocking):
  01-foundation.md      → Project setup, design system config
  02-shell.md           → App shell with design constraints

PARALLEL (after shell complete):
  tracks/track-a/03-slice-*.md  → Feature slices (design-aware)
  tracks/track-b/03-slice-*.md  → Feature slices (design-aware)

SEQUENTIAL (after all tracks converge):
  90-integration-checkpoint.md  → Cross-track integration
  91-visual-checkpoint.md       → Visual + design intent validation
  95-hygiene.md                 → Code quality
  99-release.md                 → Production release
```

## Design Intent

### Purpose
`product/design.yaml` captures visual and UX constraints ONCE, early in the project.
All UI-touching slices receive these constraints via `generate-workflows`.

### Enforcement
- Foundation configures design system from design.yaml
- Shell implements layout per design.yaml ux.navigation
- Slices with `risk-tags: [ux]` receive design constraints block
- Visual checkpoint validates against design.yaml

### Change Protocol
Design changes require:
1. Update `product/design.yaml`
2. Bump `meta.version`
3. Run visual checkpoint with `--rebaseline`
4. Regenerate affected workflow MDs

## Parallelization Rules

### Start Condition
Parallel tracks begin when:
- `01-foundation.md` status: COMPLETE
- `02-shell.md` status: COMPLETE
- All contracts in `contracts/` have version >= 1.0
- `product/design.yaml` exists (for UI projects)

### Contract Collision Protocol
```yaml
default-strategy: contract-lock
lock-file: coordination/.contract-locks.yaml
max-wait: 300s
on-conflict: queue
```

**Lock acquisition:**
1. Check `slice-graph.yaml` for contract touches
2. Acquire locks before slice execution
3. Release on slice completion or failure

### Checkpoint Triggers
- Every 2-3 slices per track
- On any `risk: high` slice completion
- On cross-track dependency resolution

### Merge Protocol
```
1. Track completes slice → update slice-graph.yaml status
2. Check coordination/assignments.yaml for blockers
3. If checkpoint-trigger → pause track, run checkpoint
4. Resume after checkpoint PASS
```

## Status Codes
| Code | Meaning |
|------|---------|
| PENDING | Not started |
| ACTIVE | In progress |
| BLOCKED | Waiting on dependency |
| COMPLETE | Done, checks passed |
| FAILED | Checks failed, needs retry |

## File References
- Coordination: `coordination/*.yaml`
- Contracts: `contracts/*.yaml`
- Outputs: `src/`, per file-map.yaml
