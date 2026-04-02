# Flow: New Project Setup

> **When:** User asks to create a new project or enters a directory without `agent/` files.

## Trigger
User says "create a new project" or agent detects missing `agent/` directory.

## Flow

```
Agent reads framework
    │
    ▼
Load user profile (lookup order):
    1. workspace/.portable-spec-kit/user-profile/user-profile-{username}.md
    2. ~/.portable-spec-kit/user-profile/user-profile-{username}.md
    3. Neither → run User Profile Setup flow first
    │
    ▼
Show profile:
"Welcome back, Jane! Setting up your new project."

Using your profile:
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
    ├─ Enter or (a) → copy global profile to workspace as-is
    │
    └─ (b) Customize → Profile Customization flow
    │
    ▼
Create project structure:
    ✓ agent/ directory with 6 files:
        AGENT.md, AGENT_CONTEXT.md, SPECS.md,
        PLANS.md, TASKS.md, RELEASES.md
    ✓ README.md (standard template)
    ✓ .gitignore
    ✓ .env.example
    ✓ Directories: src/, tests/, docs/, ard/, input/, output/
    │
    ▼
Commit: "Initialize {project-name} — v0.1 setup"
(Do NOT push — wait for user)
    │
    ▼
Report to user:
"✓ Project ready — what would you like to build?"
```

## After Setup (when user is ready)
1. Specs discussion → write `agent/SPECS.md`
2. Recommend tech stack → user approves
3. Write `agent/PLANS.md` — architecture, phases
4. Initialize stack → install deps, create source code structure (from 8 templates)
5. Start development → update `agent/TASKS.md`, begin building

## Files Created
- `agent/` — 6 management files
- `README.md`, `.gitignore`, `.env.example`
- `src/`, `tests/`, `docs/`, `ard/`, `input/`, `output/`
- `.portable-spec-kit/user-profile/user-profile-{username}.md` (if not already present)
