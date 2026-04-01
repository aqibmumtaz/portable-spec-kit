# Flow: Spec-Driven Development

> **When:** User follows the full specification-driven workflow (or agent guides them through it when asked).

## The Pipeline

```
SPECS.md        →  PLANNING.md      →  TASKS.md        →  TRACKER.md
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
    Agent writes agent/PLANNING.md:
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
        - Module-based task breakdown
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
        - Update docs/system-flows/ if any system flow changed
        - Context and flows must always match actual code state
        │
        ▼
Phase 4: Tracking
    Agent writes agent/TRACKER.md:
        - Version summary
        - Categorized changes (Frontend, Backend, AI, Infrastructure)
        - Test results and coverage
        - Deployment info
        - Known issues
```

## Non-Blocking
The user doesn't HAVE to follow this flow sequentially:

| User Does | Agent Does |
|---|---|
| "Build me a login page" | Adds to TASKS.md → builds → tests → done |
| "Fix this bug" | Adds to TASKS.md → fixes → marks done |
| "What should I do next?" | Walks through spec-driven process |
| Never wrote specs | Retroactively fills SPECS.md from what's built |

## The 6 Agent Files

| File | Purpose | When Updated |
|------|---------|---|
| `AGENT.md` | Project rules, stack, brand | Setup |
| `AGENT_CONTEXT.md` | Living state — done, next, decisions | Every session |
| `SPECS.md` | Requirements, features, acceptance criteria | Before dev |
| `PLANNING.md` | Architecture, data model, phases, methodology | Before dev |
| `TASKS.md` | Module-based task tracking | During dev |
| `TRACKER.md` | Version changelog, test results | End of version |
