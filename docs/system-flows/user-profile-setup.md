# Flow: User Profile Setup

> **When:** First time using the kit on any machine — no profile exists anywhere.

## Trigger
Agent reads framework → checks lookup order → no profile found.

## Flow

```
Agent reads framework
    │
    ▼
Check workspace/.portable-spec-kit/user-profile/user-profile-{username}.md → not found
Check ~/.portable-spec-kit/user-profile/user-profile-{username}.md → not found
    │
    ▼
Detect username:
    git config user.name → slugified (lowercase, spaces→dashes) → "jane-smith"
    Supplementary: gh api user → fetch full name, bio for greeting
    │
    ▼
Fetch GitHub profile (if gh CLI available + authenticated):
    gh api user → name, bio
    │
    ├─ gh available → "Welcome, Jane Smith!"
    ├─ gh not authenticated → "Welcome! What's your name and expertise?"
    └─ gh not installed → "Welcome! What's your name and expertise?"
    │
    ▼
"Let me set up your development profile."

Communication style?
  (a) direct and concise ← RECOMMENDED
  (b) direct, data-driven, comprehensive with tables and evidence
  (c) conversational and collaborative
  (or type your own)
  Press Enter to use recommended (a)
    │
    ▼
Working pattern?
  (a) iterative — starts brief, expands scope, builds ambitiously ← RECOMMENDED
  (b) plan-first — defines full specs and architecture before writing code
  (c) prototype-fast — gets something working quickly, then refines
  (or type your own)
  Press Enter to use recommended (a)
    │
    ▼
AI delegation?
  (a) AI does 70%, user guides 30% ← RECOMMENDED
  (b) AI does 90%, user reviews 10%
  (c) 50/50 collaboration
  (or type your own)
  Press Enter to use recommended (a)
    │
    ▼
Show summary:
┌─────────────────────────────────────┐
│ Your profile:                       │
│ Jane Smith — B.S. CS. Full-stack.   │
│ Communication: direct and concise   │
│ Working pattern: iterative          │
│ AI delegation: AI does 70%          │
└─────────────────────────────────────┘
Looks good? (Enter = yes, or type changes)
    │
    ▼
Save to ~/.portable-spec-kit/user-profile/user-profile-janesmith.md (global)
Save to workspace/.portable-spec-kit/user-profile/user-profile-janesmith.md (committed)
    │
    ▼
✓ Profile ready — continues with project setup
```

## User Actions
- **Pick a/b/c** → selects that option
- **Press Enter** → uses recommended
- **Type custom text** → saved as-is
- **Skip all (Enter through everything)** → all recommended defaults

## Edge Cases
| Scenario | Handling |
|---|---|
| No gh CLI | Ask name/expertise manually |
| gh not authenticated | Fall back to asking |
| GitHub name empty | Use GitHub login as fallback |
| GitHub bio empty | Ask for education and expertise |
| Agent can't write files | Show content, ask user to create manually |

## Files Created
- `~/.portable-spec-kit/user-profile/user-profile-{username}.md`
- `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md`
