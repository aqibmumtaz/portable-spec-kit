# Flow: Returning Session

> **When:** User opens an AI agent in an existing project — coming back after hours, days, weeks, or months.

## Trigger
Agent reads framework in a workspace that already has `agent/` files.

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. LOAD FRAMEWORK                                          │
│     Agent reads portable-spec-kit.md (via symlink)          │
│     Check kit version: <!-- Framework Version --> in kit    │
│     vs **Kit:** in agent/AGENT_CONTEXT.md                   │
│     ├─ Same → proceed normally                              │
│     └─ Different → run Kit Update flow (see below)          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. SHOW KIT STATUS (once at session start)                 │
│     ✅ Spec Kit: Project mapped (vX.X.X) — reading context  │
│     ⚠  Spec Kit: Partial context — filling in gaps...       │
│     🔍 Spec Kit: Understanding your project — scanning...   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. LOAD PROFILE                                            │
│     1. workspace/.portable-spec-kit/user-profile/ → FOUND?  │
│        └─ Yes → load silently, no questions                 │
│     2. ~/.portable-spec-kit/user-profile/ → FOUND?          │
│        └─ Yes → show profile, keep or customize → save WS   │
│     3. Neither → run User Profile Setup flow first          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. READ PROJECT CONTEXT (in this order)                    │
│     1. agent/AGENT.md     — project rules, stack            │
│     2. agent/AGENT_CONTEXT.md — living state                │
│     3. agent/TASKS.md     — current tasks                   │
│     4. agent/PLANS.md     — architecture                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  5. GREET + SUMMARIZE                                       │
│     "Welcome back, Jane! Here's where we left off:"         │
│     - Version and phase from AGENT_CONTEXT.md               │
│     - Tasks completed vs pending from TASKS.md              │
│     - Last decision + next step                             │
│     "Want to continue with [next task]?"                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  6. WORK                                                    │
│     User gives instructions → agent works                   │
│     Track all tasks in TASKS.md (no-slip rule)              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  7. SESSION END UPDATE                                      │
│     Update agent/AGENT_CONTEXT.md — progress, decisions     │
│     Update docs/work-flows/ if any flow changed             │
│     Verify no tasks slipped (scan conversation)             │
└─────────────────────────────────────────────────────────────┘
```

## Kit Version Changed — Update Flow

```
┌─────────────────────────────────────────────────────────────┐
│  VERSION CHECK                                              │
│  <!-- Framework Version --> in portable-spec-kit.md         │
│  vs **Kit:** in agent/AGENT_CONTEXT.md                      │
│     Same → proceed normally                                 │
│     Different → run update flow ↓                           │
└──────────────────────┬──────────────────────────────────────┘
                       │ (kit version updated)
┌──────────────────────▼──────────────────────────────────────┐
│  1. RESTRUCTURE agent/ files                                │
│     Match all 6 files to new templates                      │
│     Preserve ALL existing content — only reorganize         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. STALE FIELD SWEEP                                       │
│     Scan ALL agent/ files for outdated field names:         │
│     "Framework versions:" → "Kit:"                          │
│     "**Framework:**" → "**Kit:**"                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. SCAN PROJECT CODEBASE                                   │
│     Read source files + config files                        │
│     (package.json, requirements.txt, Dockerfile, etc.)      │
│     Update AGENT.md — stack, tech, ports from actual code   │
│     Update AGENT_CONTEXT.md — phase, done, next             │
│     Update **Kit:** field in AGENT_CONTEXT.md to new version│
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. SHOW COMBINED SUMMARY                                   │
│     Scan results + what changed in new kit version          │
│     Continue working — zero interruption                    │
└─────────────────────────────────────────────────────────────┘
```

## Key Rules
- **Workspace profile exists** → loaded silently, zero friction
- **Only global exists** → shown to user, keep or customize, then saved to workspace
- **No profile anywhere** → full first-time setup
- **Kit status shown once** per session (on first load) — not on every message
- **Profile setup and project scan are independent** — if user skips profile setup, kit proceeds to project scan immediately; never block on profile

## Files Read
- `.portable-spec-kit/user-profile/user-profile-{username}.md`
- `agent/AGENT.md`
- `agent/AGENT_CONTEXT.md`
- `agent/TASKS.md`
- `agent/PLANS.md`

## Files Updated (after significant work, after commits, before push)
- `agent/AGENT_CONTEXT.md` — progress, decisions, what's next
- `docs/work-flows/` — if any work flow changed during implementation
