# Flow: Returning Session

> **When:** User opens an AI agent in an existing project — coming back after hours, days, weeks, or months.

## Trigger
Agent reads framework in a workspace that already has `agent/` files.

## Flow — Workspace Profile Exists

```
Agent reads framework
    │
    ▼
Check workspace/.portable-spec-kit/user-profile/user-profile-{username}.md → FOUND ✓
    │
    ▼
Load profile — no questions
    │
    ▼
Read project context:
    agent/AGENT.md — project rules, stack
    agent/AGENT_CONTEXT.md — living state (what's done, next, decisions)
    agent/TASKS.md — current tasks
    agent/PLANS.md — architecture
    │
    ▼
Greet by name + summarize:
"Welcome back, Jane! Here's where we left off:"
    - v0.2 in progress — 3 of 8 tasks complete
    - Last session: built auth system, 45 tests passing
    - Next: payment integration (blocked on Stripe key)
    - Decision pending: PostgreSQL vs MongoDB
    │
    ▼
"Want to continue with payment integration?"
    │
    ▼
User gives instructions → agent works
    │
    ▼
Session ends → agent updates agent/AGENT_CONTEXT.md
```

## Flow — No Workspace Profile (global only)

```
Agent reads framework
    │
    ▼
Check workspace/.portable-spec-kit/user-profile/user-profile-{username}.md → NOT FOUND
Check ~/.portable-spec-kit/user-profile/user-profile-{username}.md → FOUND ✓
    │
    ▼
Load from global → show profile to user:
"Using your global profile:"
┌─────────────────────────────────────┐
│ Jane Smith — B.S. CS. Full-stack.   │
│ Communication: direct and concise   │
│ Working pattern: iterative          │
│ AI delegation: AI does 70%          │
└─────────────────────────────────────┘

Keep or customize for this project? (Enter = keep)
  (a) Keep as-is
  (b) Customize for this project
    │
    ├─ Enter or (a) → save to workspace as-is
    └─ (b) → 3 questions (CURRENT + RECOMMENDED) → save customized to workspace
    │
    ▼
✓ Workspace copy created — won't ask again next session
    │
    ▼
Read project context → greet → summarize → continue working
```

## Flow — No Profile Anywhere

```
Check workspace → NOT FOUND
Check global → NOT FOUND
    │
    ▼
Run First Time Profile Setup flow
(GitHub fetch → 3 questions → save global + workspace)
    │
    ▼
Read project context → greet → summarize → continue working
```

## Key Rules
- **Workspace profile exists** → loaded silently, zero friction
- **Only global exists** → shown to user, keep or customize, then saved to workspace
- **No profile anywhere** → full first-time setup
- **Kit version changed** → compare `<!-- Framework Version -->` in portable-spec-kit.md against `**Kit:**` in AGENT_CONTEXT.md → if different, restructure agent/ files to match new templates, retain all content, update Kit version in AGENT_CONTEXT.md

## Files Read
- `.portable-spec-kit/user-profile/user-profile-{username}.md`
- `agent/AGENT.md`
- `agent/AGENT_CONTEXT.md`
- `agent/TASKS.md`
- `agent/PLANS.md`

## Files Updated (after significant work, after commits, before push)
- `agent/AGENT_CONTEXT.md` — progress, decisions, what's next
- `docs/system-flows/` — if any system flow changed during implementation
