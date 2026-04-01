# Flow: Profile Customization

> **When:** User wants different preferences for a specific project (e.g., more autonomous for personal projects, more collaborative for team work).

## Trigger
On new project setup, user selects "(b) Customize for this project" instead of keeping current profile.

## Flow

```
Agent shows current profile (loaded from global):
┌─────────────────────────────────────┐
│ Jane Smith — B.S. CS. Full-stack.   │
│ Communication: direct and concise   │
│ Working pattern: iterative          │
│ AI delegation: AI does 70%          │
└─────────────────────────────────────┘

Keep or customize? (Enter = keep)
  (a) Keep as-is
  (b) Customize for this project

User: b
    │
    ▼
Communication style?
  (a) direct and concise ← RECOMMENDED · CURRENT
  (b) direct, data-driven, comprehensive with tables and evidence
  (c) conversational and collaborative
  (or type your own)
  Press Enter to keep current (a)

User: b  ← changes to comprehensive
    │
    ▼
Working pattern?
  (a) iterative ← RECOMMENDED · CURRENT
  (b) plan-first
  (c) prototype-fast
  (or type your own)
  Press Enter to keep current (a)

User: [Enter]  ← keeps current
    │
    ▼
AI delegation?
  (a) AI does 70%, user guides 30% ← RECOMMENDED · CURRENT
  (b) AI does 90%, user reviews 10%
  (c) 50/50 collaboration
  (or type your own)
  Press Enter to keep current (a)

User: b  ← changes to 90%
    │
    ▼
Show summary:
┌──────────────────────────────────────────┐
│ Your project profile:                    │
│ Jane Smith — B.S. CS. Full-stack.        │
│ Communication: comprehensive with tables │
│ Working pattern: iterative (unchanged)   │
│ AI delegation: AI does 90%               │
└──────────────────────────────────────────┘
Looks good? (Enter = yes, or type changes)

User: [Enter]
    │
    ▼
Save to workspace/.portable-spec-kit/user-profile/user-profile-janesmith.md
(Global profile unchanged)
    │
    ▼
This workspace uses local profile from now on
```

## Highlights
- **RECOMMENDED** — framework's suggested default
- **CURRENT** — user's existing global answer
- **RECOMMENDED · CURRENT** — when both are the same
- **Enter** — keeps current value (no retyping)
- **Custom text** — accepted as-is

## Files
- **Read:** `~/.portable-spec-kit/user-profile/user-profile-{username}.md` (global)
- **Written:** `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md` (local override)
- **Global unchanged** — only workspace gets the customized version
