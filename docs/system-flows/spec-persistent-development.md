# Flow: Spec-Persistent Development

> **When:** User follows any development workflow — structured, agile, or mixed. The agent maintains living specs throughout. Also applies when agent fills gaps retroactively. The framework doesn't enforce a methodology — it adapts to yours.

## The Pipeline

```
SPECS.md        →  PLANS.md      →  TASKS.md        →  RELEASES.md
What to build      How to build it     Track progress      Log results
```

## Flow

```
Phase 1: Specification
    User: "I want to build a resume editor"
        │
        ▼
    Agent writes agent/SPECS.md:
        - Requirements
        - Features table (priority, status)
        - Scope (in/out)
        - Acceptance criteria
        │
        ▼
Phase 2: Planning
    Agent writes agent/PLANS.md:
        - Stack recommendation (with Why column)
        - Architecture design
        - Directory structure (from 8 templates)
        - Data model
        - API endpoints
        - Security considerations
        - Build phases
        - Methodology & Research (decision log with evidence)
        │
        ▼
Phase 3: Execution
    Agent writes agent/TASKS.md:
        - Version-based task breakdown (v0.1 — Current)
        - Checkboxes for each task
        │
        ▼
    For each task:
        Add to TASKS.md FIRST → build → test → mark done
        │
        ▼
    Agent self-validates:
        - Writes tests for every feature
        - Runs tests, shows coverage
        - Fixes failures before presenting
        - User should never discover broken features
        │
        ▼
    After implementation + tests:
        - Update agent/AGENT_CONTEXT.md (what was built, test results, what's next)
        - Update SPECS.md if scope changed (new features, descoped features)
        - Update PLANS.md if architecture evolved (new tech, data model, APIs)
        - Update docs/system-flows/ if any system flow changed
        - Context, specs, planning, and flows must always match actual code state
        │
        ▼
Phase 4: Tracking
    Agent writes agent/RELEASES.md:
        - Version summary
        - Framework version range (v0.x.1 — v0.x.y)
        - Categorized changes (Frontend, Backend, AI, Infrastructure)
        - Test results and coverage
        - Deployment info
        - Known issues
```

## Pipeline Sync Rules

All 4 files must stay in sync throughout development:

```
Feature added during dev
    │
    ├─ SPECS.md → add feature to features table
    ├─ PLANS.md → update architecture if affected
    ├─ TASKS.md → add task under current version
    └─ AGENT_CONTEXT.md → update current state

Feature descoped
    │
    ├─ SPECS.md → move to "Out of scope (future)"
    ├─ TASKS.md → remove from current, add to Backlog
    └─ AGENT_CONTEXT.md → note the decision

Architecture changed
    │
    ├─ PLANS.md → update Stack, Data Model, API Endpoints
    ├─ AGENT.md → update Stack table if tech changed
    └─ AGENT_CONTEXT.md → add to Key Decisions

Version released
    │
    ├─ RELEASES.md → changelog + framework version range + test results
    ├─ TASKS.md → move current to Done, start new version
    ├─ AGENT_CONTEXT.md → bump version
    └─ ARD docs → update Technical Overview
```

## Retroactive Gap Filling

If the user doesn't follow the pipeline sequentially, the agent fills gaps:

| Condition | Agent Action |
|---|---|
| SPECS.md empty after 3+ tasks completed | Fill features from what's been built |
| PLANS.md empty after stack chosen | Document architecture from codebase |
| TASKS.md has completed tasks not in SPECS.md | Add features to SPECS.md |
| Architecture changed during dev | Update PLANS.md to match reality |
| No RELEASES.md entry after version milestone | Create entry with changelog |

## Non-Blocking

The user doesn't HAVE to follow this flow sequentially:

| User Does | Agent Does |
|---|---|
| "Build me a login page" | Adds to TASKS.md → builds → tests → done → updates SPECS if new feature |
| "Fix this bug" | Adds to TASKS.md → fixes → marks done |
| "Change from PostgreSQL to MongoDB" | Updates PLANS.md (stack + why) → AGENT.md → continues |
| "What should I do next?" | Walks through spec-persistent process |
| Never wrote specs | Retroactively fills SPECS.md from what's built |
| Comes back after weeks | Reads AGENT_CONTEXT.md → summarizes → continues |

## The 6 Agent Files

| File | Purpose | When Updated |
|------|---------|---|
| `AGENT.md` | Project rules, stack, brand | Setup, when stack/config changes |
| `AGENT_CONTEXT.md` | Living state — done, next, decisions | Every session + after every implementation |
| `SPECS.md` | Requirements, features, acceptance criteria | Before dev + when scope changes |
| `PLANS.md` | Architecture, data model, phases, methodology | Before dev + when architecture evolves |
| `TASKS.md` | Version-based task tracking | Before and after every task |
| `RELEASES.md` | Version changelog, test results | End of version release |
