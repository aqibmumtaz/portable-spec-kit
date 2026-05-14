# Flow 16 — Feature Design Pipeline

Every feature gets a design plan in `agent/design/`. Three triggers, one flow.

> **Plan-Save Protocol (v0.6.53+):** General (non-feature) plans drafted in conversation persist to `agent/plans/YYYY-MM-DD-<slug>.md` with lifecycle frontmatter via `bash agent/scripts/psk-plan-save.sh {save|approve|start|done} <slug>`. Feature-scoped plans continue to live at `agent/design/f{N}-*.md` per this flow. Both surfaces are committed — interruption-resilient by design.

## Overview

| Field | Value |
|---|---|
| **Trigger** | User says `"plan F3"` / `"design F3"` · feature added to SPECS.md (auto) · user says `"implement F3"` (gate check) |
| **Inputs** | `agent/SPECS.md` (feature list + acceptance criteria), conversation context, `.portable-spec-kit/skills/templates.md` (plan template) |
| **Outputs** | `agent/design/f{N}-feature-name.md` · updated `agent/PLANS.md` ADL · synced `agent/SPECS.md`, `agent/TASKS.md`, `agent/RELEASES.md` |
| **Script** | None — agent-driven; plan files written directly |
| **Gate** | Implementation gate: plan must be filled (not just a stub) before `"implement F3"` proceeds |
| **When blocked** | User says `"implement F3"` but design file is missing or contains only stub sections — agent creates and fills the plan first |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  TRIGGER: "plan F3" / feature added to SPECS / "implement"  │
│     Three entry points; same downstream flow                │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  CHECK: Does agent/design/f{N}-name.md exist? (agent)       │
│     ├─ Yes → open and continue filling                      │
│     └─ No  → create from 12-section template                │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  FILL PLAN FROM CONVERSATION (agent)                        │
│     Sections: Context · Approach · Decisions · Data Model   │
│     Edge Cases · Commands · Config · Scope Exclusions       │
│     Files · Tests · Implementation Order · Current State    │
│     Decisions → auto-flow to PLANS.md ADL                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  IMPLEMENTATION GATE (on "implement F3") (agent)            │
│     ├─ Plan filled → proceed to implement                   │
│     └─ Stub/empty → fill first → confirm → implement        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  AFTER IMPLEMENTATION — sync all 5 pipeline files (agent)   │
│     Update plan: Current State → Done                       │
│     Sync: SPECS.md · agent/design/ · PLANS.md               │
│           TASKS.md · RELEASES.md (if version complete)      │
└─────────────────────────────────────────────────────────────┘
```

---

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

## Key Rules

- **One plan per feature:** every F{N} in SPECS.md gets a corresponding `agent/design/f{N}-feature-name.md`. No feature is implemented without a plan file.
- **Implementation gate is mandatory:** if a user says `"implement F3"` and the plan is missing or is a stub, the agent creates and fills it first, confirms with the user, then proceeds.
- **Decisions auto-flow to ADL:** every decision recorded in the plan's `## Decisions` section is extracted to `agent/PLANS.md` ADL with a `Plan Ref` column. The plan is the source of truth; the ADL is the index.
- **Sync on completion:** when a feature is marked done, the agent updates all five pipeline files in the same session (SPECS.md, agent/design/, PLANS.md, TASKS.md, RELEASES.md). No file is left out of sync.
- **No tests = not done:** a feature cannot be marked `[x]` in SPECS.md without test coverage. The Tests column must reference the test file or function.

---

## Traceability Chain

```
R (requirement) → F (feature) → Plan (design) → ADR (indexed) → T (tests)
    SPECS.md        SPECS.md     agent/design/     PLANS.md       tests/
```

Every decision traceable backwards:
Release → Task → Design → Feature → Requirement

## Template enrichment (`skills/templates.md`) — v0.6.44

**Template enrichment (skills/templates.md):** All 9 agent file templates in `skills/templates.md` were updated with gold-standard sections in v0.6.44:

- **REQS.md**: approval tracking column, requirement type column, source column
- **SPECS.md**: scope-change record block, `tests/features/` stub path in Tests column format
- **AGENT.md**: Security section (OWASP references, secret management rules), Definition of Done checklist
- **TASKS.md**: QA Findings subsection format, Evidence field per finding
- **RESEARCH.md**: Open Research Questions block
- **AGENT_CONTEXT.md**: File Structure section listing `tests/features/` and `.portable-spec-kit/config.md` as required paths

These enrichments ensure agent file templates produced by `psk-init.sh`, `psk-new-setup.sh`, and `psk-existing-setup.sh` include all fields required by the Dim 25 mandate-compliance probe (25.2–25.4). Regression-locked by `tests/features/f72-template-structure.sh` (15 tests).
