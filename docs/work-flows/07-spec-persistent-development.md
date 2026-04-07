# Flow: Spec-Persistent Development

> **When:** User follows any development workflow — structured, agile, or mixed. The agent maintains living specs throughout. Also applies when agent fills gaps retroactively. The framework doesn't enforce a methodology — it adapts to yours.

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. SPECS — Define what to build                            │
│     Write agent/SPECS.md — requirements (Rn), features (Fn) │
│     Per-feature acceptance criteria (### F{n} subsections)  │
│     Agent generates test stubs for forward-flow features    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. PLANS — Architect how to build it                       │
│     Write agent/PLANS.md — stack, architecture, phases      │
│     Data model, API endpoints, security, methodology        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. TASKS + BUILD — Execute                                 │
│     Write agent/TASKS.md (version-based, checkboxes)        │
│     For each task: TASKS.md FIRST → build → test → done     │
│     Stubs RED → implement → stubs GREEN → mark [x]          │
│     check_stub_complete() gate before marking [x]           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. SYNC — Keep all 4 pipeline files current                │
│     SPECS.md, PLANS.md, TASKS.md, AGENT_CONTEXT.md          │
│     Record scope changes (DROP/ADD/MODIFY/REPLACE)          │
│     R→F traceability: Rn → Fn through every change          │
│     F→T traceability: Fn → test ref in Tests column         │
└──────────────────────┬──────────────────────────────────────┘
                       │ When all version tasks [x] done
┌──────────────────────▼──────────────────────────────────────┐
│  5. PREPARE RELEASE (8-step gate)                           │
│     Run 3 suites → update counts → bump version             │
│     PDFs → RELEASES.md → CHANGELOG.md → publish             │
│     Section 41 (28 tests) catches any sync gaps             │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  6. RELEASES.md — Record what happened                      │
│     Version summary, Kit range, changes by category         │
│     Test results, deployment, known issues                  │
└─────────────────────────────────────────────────────────────┘
```

## The Pipeline

```
SPECS.md  →  PLANS.md  →  TASKS.md  →  RELEASES.md
What to      How to       Track        Log
build        build it     progress     results
```

## Pipeline Sync Rules

All 4 files must stay in sync. When anything changes:

| Event | Files to update |
|-------|----------------|
| **Feature added** | SPECS.md (features table) + PLANS.md (if architecture affected) + TASKS.md (new task) + AGENT_CONTEXT.md |
| **Feature descoped** | SPECS.md (move to Out of scope) + TASKS.md (remove from current, add to Backlog) + AGENT_CONTEXT.md |
| **Architecture changed** | PLANS.md (Stack, Data Model, API Endpoints) + AGENT.md (Stack table) + AGENT_CONTEXT.md (Key Decisions) |
| **After implementation** | AGENT_CONTEXT.md (progress) + SPECS.md (if scope changed) + PLANS.md (if architecture evolved) + docs/work-flows/ (if any flow changed) + ci.yml (if stack changed) |
| **Version released** | Run prepare release gate (8-step) → RELEASES.md + TASKS.md (Done) + AGENT_CONTEXT.md (bump) + ARD |

```
┌─────────────────────────────────────────────────────────────┐
│  FEATURE ACCEPTANCE CRITERIA FORMAT (SPECS.md)              │
│                                                             │
│  ## Feature Acceptance Criteria                             │
│                                                             │
│  ### F1 — Feature Name                                      │
│  - [ ] Criterion 1 (what a passing state looks like)        │
│  - [ ] Criterion 2                                          │
│  - [ ] Edge case: what happens when X is empty              │
│                                                             │
│  ### F2 — Another Feature                                   │
│  - [ ] Criterion 1                                          │
└─────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────┐
│  TEST STUB LIFECYCLE (forward-flow features)                │
│                                                             │
│  Stubs generated RED (all TODO markers — expected)          │
│       │                                                     │
│  Implement feature code                                     │
│       │                                                     │
│  Fill stub implementations (remove TODO, write assertions)  │
│       │                                                     │
│  check_stub_complete() — no TODO/skip/placeholder markers   │
│       ├─ Markers found → refuse [x], show count             │
│       └─ No markers → run tests                             │
│                        ├─ Fail → fix code, re-run           │
│                        └─ Pass → mark [x] in SPECS.md       │
└─────────────────────────────────────────────────────────────┘
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
