# Workflow Index

## Execution Order

```
SEQUENTIAL (blocking):
  01-foundation.md
  02-shell.md

PARALLEL (after shell complete):
  tracks/track-a/03-slice-*.md
  tracks/track-b/03-slice-*.md

SEQUENTIAL (after all tracks converge):
  90-integration-checkpoint.md
  91-visual-checkpoint.md
  95-hygiene.md
  99-release.md
```

## Parallelization Rules

### Start Condition
Parallel tracks begin when:
- `01-foundation.md` status: COMPLETE
- `02-shell.md` status: COMPLETE
- All contracts in `contracts/` have version >= 1.0

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
