# Product Brief

> Define your application before development begins.

---

## One-Liner

{Describe your app in one sentence — what it does and for whom.}

**Example**: "A task management app that helps remote teams track work across time zones."

---

## Problem Statement

{What problem does this solve? Why does it matter?}

**Template**:
- **Who** has the problem: {target users}
- **What** is the problem: {pain point}
- **Why** existing solutions fail: {gap in market}
- **Impact** of not solving: {consequences}

---

## Target Users

{Who are the primary users? Be specific.}

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| {Persona 1} | {Description} | {What they need most} |
| {Persona 2} | {Description} | {What they need most} |

---

## Core Features

{What are the must-have features for v1.0?}

| Feature | Priority | Maps to Contract |
|---------|----------|------------------|
| {Feature 1} | P0 | `api-contract.yaml#/resources/{resource}` |
| {Feature 2} | P0 | `db-schema.yaml#/entities/{entity}` |
| {Feature 3} | P1 | |

**Priority Key**: P0 = Must have, P1 = Should have, P2 = Nice to have

---

## Success Criteria

{How do we know the product succeeded?}

| Metric | Target | Measurement |
|--------|--------|-------------|
| {Metric 1} | {Target value} | {How to measure} |
| {Metric 2} | {Target value} | {How to measure} |

---

## Out of Scope (v1.0)

{What are we explicitly NOT building?}

- {Feature/capability 1} — Reason: {why deferred}
- {Feature/capability 2} — Reason: {why deferred}
- {Feature/capability 3} — Reason: {why deferred}

---

## Technical Constraints

{Any fixed technical decisions?}

| Constraint | Decision | Rationale |
|------------|----------|-----------|
| Framework | {e.g., Next.js, none} | {why} |
| Database | {e.g., PostgreSQL, SQLite} | {why} |
| Hosting | {e.g., Vercel, self-hosted} | {why} |

---

## Timeline

{High-level milestones — no specific dates, just sequence.}

1. **Foundation**: Project setup, tooling, contracts finalized
2. **Shell**: App skeleton, routing, layout components
3. **Core Features**: Parallel track execution
4. **Integration**: Cross-track testing, visual validation
5. **Release**: Production deployment

---

*Fill in the placeholders above before executing `01-foundation.md`.*
