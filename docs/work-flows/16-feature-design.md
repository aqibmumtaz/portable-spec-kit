# Flow 16 — Feature Design Pipeline

Every feature gets a design plan in `agent/design/`. Three triggers, one flow.

```
┌─────────────────────────────────────────────────────────────┐
│  TRIGGER 1: User says "plan F3" / "design F3"               │
│  TRIGGER 2: Feature added to SPECS.md (auto)                │
│  TRIGGER 3: User says "implement F3" (gate check)           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  CHECK: Does agent/design/f{N}-name.md exist?               │
│     ├─ Yes → open and continue filling                      │
│     └─ No  → create from template                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  CREATE PLAN FROM TEMPLATE                                  │
│     File: agent/design/f{N}-feature-name.md                 │
│     Sections:                                               │
│       ## Context         — what + why + Rn ref              │
│       ## Approach        — architecture, tech choices       │
│       ## Decisions       — options table (auto-flows to ADL)│
│       ## Data Model      — schema, formats (skip if none)   │
│       ## Edge Cases      — filled during design             │
│       ## Commands        — new commands (skip if none)      │
│       ## Config Changes  — AGENT.md, .env, framework        │
│       ## Scope Exclusions — what this does NOT do           │
│       ## Files to Modify — new + existing                   │
│       ## Tests           — maps to SPECS.md criteria        │
│       ## Implementation Order — build sequence              │
│       ## Current State   — Plan only / In progress / Done   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  FILL PLAN FROM CONVERSATION                                │
│     Agent writes/updates as user discusses the feature      │
│     Decisions captured → auto-flow to PLANS.md ADL          │
│     ADL row includes Plan Ref column linking back           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  IMPLEMENTATION GATE (on "implement F3" / "start F3")       │
│     Check plan exists AND is filled (not just stub)         │
│     ├─ Filled → proceed to implement                        │
│     └─ Stub/empty → fill first → confirm → then implement   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  AFTER IMPLEMENTATION                                       │
│     Update plan: ## Current State → Done                    │
│     Sync all 5 pipeline files:                              │
│       SPECS.md, agent/design/, PLANS.md, TASKS.md,          │
│       RELEASES.md (if version complete)                     │
└─────────────────────────────────────────────────────────────┘
```

## Traceability Chain

```
R (requirement) → F (feature) → Plan (design) → ADR (indexed) → T (tests)
    SPECS.md        SPECS.md     agent/design/     PLANS.md       tests/
```

Every decision traceable backwards:
Release → Task → Design → Feature → Requirement
