# Architecture Template Reference (Big Tier)

Use this template for architecture-level planning.
Big tier is a forest view: decisions, boundaries, milestones.

## System Overview Diagram

Use simple ASCII diagrams (max ~15 lines).

### Pattern: Simple service

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  Client  │────▶│   API    │────▶│    DB    │
└──────────┘     └──────────┘     └──────────┘
```

### Pattern: Multi-service

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  Client  │────▶│ Gateway  │────▶│ Service A│────▶ DB-A
└──────────┘     └────┬─────┘     └──────────┘
                      │
                      └──────────▶┌──────────┐
                                  │ Service B│────▶ DB-B
                                  └──────────┘
```

## Key Decisions Format

Each decision should capture:
1. What decision is being made
2. Chosen option
3. Alternatives considered
4. Rationale

| Decision | Choice | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| Database | PostgreSQL | MongoDB, SQLite | Relational model + team expertise |
| API style | REST | GraphQL, gRPC | Simpler adoption path |

## Tech Stack Table

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Language | TypeScript | Type safety + team familiarity |
| Runtime | Node.js LTS | Stable ecosystem |
| Database | PostgreSQL | ACID + tooling |

## Risk Table

| Risk | Impact | Mitigation |
|------|--------|------------|
| Integration complexity | High | Add early integration milestone |
| Scope expansion | Medium | Freeze scope per phase |

## Phase Sizing Guide

In big tier, define phase milestones only (no detailed implementation plan files).

| Tier hint for later | Typical size |
|---------------------|--------------|
| small | 1-5 files, ~2h |
| medium | 6-15 files, 2-8h |

## Big Plan `main.md` Template

```markdown
---
type: project
status: active
start-date: YYYY-MM-DD
area:
tier: big
tags: [project]
---

# <Title>

## Status
- [ ] Phase 1: <name> (next-tier hint: small|medium)
- [ ] Phase 2: <name> (next-tier hint: small|medium)
- [ ] Phase 3: <name> (next-tier hint: small|medium)

## Goal
<2-3 sentences: what we're building, for whom, and why>

## Scope

**In scope:**
- <major deliverables>

**Out of scope:**
- <explicit exclusions>

## Architecture

### System Overview
```
<ASCII diagram>
```

### Components
| Component | Responsibility | Tech |
|-----------|---------------|------|
| <name> | <what it does> | <technology> |

### Data Flow
<2-4 sentences>

### Tech Stack
| Layer | Technology | Rationale |
|-------|-----------|-----------|
| <layer> | <tech> | <why> |

### Key Decisions
| Decision | Choice | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| <what> | <chosen> | <others> | <why> |

## Phases

### Phase 1: <Name>
- **Milestone:** <what is true when done>
- **Description:** <2-3 sentences>
- **Depends on:** none
- **Estimated effort:** ~<X>h
- **Next-tier hint:** small | medium

### Phase 2: <Name>
- **Milestone:** <what is true when done>
- **Description:** <2-3 sentences>
- **Depends on:** Phase 1
- **Estimated effort:** ~<X>h
- **Next-tier hint:** small | medium

## Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| <risk> | <high/medium/low> | <mitigation> |

## Principles
- <architecture principle>
- <testing principle>
- <delivery principle>

## Log
- YYYY-MM-DD: Created big architecture plan
```

## Important

- Do not create `phase-*.md` or `task-*.md` from big tier.
- Keep details at architecture/milestone granularity.
- Down-size planning is a later, explicit user action.
