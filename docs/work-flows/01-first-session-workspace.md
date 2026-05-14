# Flow: First Session in New Workspace

> **When:** User opens an AI agent in a workspace for the first time — no WORKSPACE_CONTEXT.md exists yet.

## Trigger
Agent reads framework → detects `WORKSPACE_CONTEXT.md` does not exist.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | Agent detects `WORKSPACE_CONTEXT.md` does not exist on session start |
| **Inputs** | Workspace directory tree, user profile (workspace or global), installed tools |
| **Outputs** | `WORKSPACE_CONTEXT.md`, `agent/` directories for projects found without them |
| **Script** | None — agent-driven; no dedicated orchestrator script |
| **Gate** | Profile and scan are independent; scan never blocks on profile completion |
| **When blocked** | Never fully blocked — profile setup skipped → defaults applied, scan proceeds |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: CHECK PROFILE (agent)                              │
│     workspace/.portable-spec-kit/user-profile/ → FOUND?     │
│     ~/.portable-spec-kit/user-profile/ → FOUND?             │
│     Neither → run User Profile Setup flow (non-blocking)    │
│     If user skips → apply defaults and proceed              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 2: DETECT ENVIRONMENT (automated)                     │
│     OS, Node version, Python version, tools installed       │
│     → populate Environment & Tools section                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 3: SCAN WORKSPACE (automated)                         │
│     List all directories → identify projects                │
│     → populate Workspace Overview table                     │
│     Announce: "Scanning workspace — found X projects..."    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 4: CREATE WORKSPACE_CONTEXT.md (agent)                │
│     Sections: Workspace Overview, Environment & Tools,      │
│     Key Conventions, Last Updated                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 5: CREATE agent/ DIRS FOR PROJECTS WITHOUT THEM       │
│     For each project found without agent/ dir:              │
│     - Create agent/ with 6 template files                   │
│     - Apply File Creation/Update Rule to README.md          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 6: WORKSPACE READY (agent)                            │
│     "Workspace scanned. X projects found."                  │
│     "What would you like to work on?"                       │
└─────────────────────────────────────────────────────────────┘
```

---

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. CHECK PROFILE                                           │
│     workspace/.portable-spec-kit/user-profile/ → FOUND?     │
│     ~/.portable-spec-kit/user-profile/ → FOUND?             │
│     Neither → run User Profile Setup flow                   │
│                                                             │
│     NOTE: Profile setup and workspace scan are independent  │
│     If user skips profile → apply defaults, proceed         │
│     Never block workspace scan waiting for profile          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. DETECT ENVIRONMENT                                      │
│     OS, Node version, Python version, tools installed       │
│     → populate Environment & Tools section                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. SCAN WORKSPACE                                          │
│     List all directories → identify projects                │
│     → populate Workspace Overview table                     │
│     Announce: "Scanning workspace — found X projects..."    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. CREATE WORKSPACE_CONTEXT.md                             │
│     Sections:                                               │
│     - Workspace Overview (table of all projects)            │
│     - Environment & Tools                                   │
│     - Key Conventions                                       │
│     - Last Updated                                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  5. CREATE AGENT/ DIRS FOR PROJECTS WITHOUT THEM            │
│     For each project found without agent/ dir:              │
│     - Create agent/ with 6 template files                   │
│     - Apply File Creation/Update Rule to README.md          │
│     Show kit status: 🔍 Understanding your project...       │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  6. WORKSPACE READY                                         │
│     "Workspace scanned. X projects found."                  │
│     "What would you like to work on?"                       │
└─────────────────────────────────────────────────────────────┘
```

## WORKSPACE_CONTEXT.md Rules
- Created **once** on first session — never overwritten unless user explicitly asks
- Not for project-specific state — that goes in each project's `agent/AGENT_CONTEXT.md`
- Only update when user explicitly requests it

## Key Rules
- **Profile and scan are decoupled** — workspace scan always proceeds even if profile setup is skipped or deferred
- **Agent/ files are always safe to add** — creating the 6 management files never disrupts existing code
- **Never assume git structure** — each project directory may have its own `.git/`; check before committing

## Files Created
- `WORKSPACE_CONTEXT.md` (workspace root)
- `agent/` directories for projects found without them (6 files each)
