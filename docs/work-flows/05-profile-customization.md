# Flow: Profile Customization

> **When:** User wants different preferences for a specific project (e.g., more autonomous for personal projects, more collaborative for team work).

## Trigger
On new project setup or returning session (global only), user selects "(b) Customize for this project".

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. SHOW CURRENT PROFILE                                    │
│     Load global: ~/.portable-spec-kit/user-profile/...      │
│     ┌─────────────────────────────────┐                     │
│     │ Jane Smith — B.S. CS.           │                     │
│     │ Communication: direct           │                     │
│     │ Working pattern: iterative      │                     │
│     │ AI delegation: AI does 70%      │                     │
│     └─────────────────────────────────┘                     │
│     "Keep or customize? (Enter = keep)"                     │
│     (a) Keep as-is  (b) Customize for this project          │
└──────────────────────┬──────────────────────────────────────┘
                       │ User selects (b)
┌──────────────────────▼──────────────────────────────────────┐
│  2. ASK 3 QUESTIONS — each shows CURRENT and RECOMMENDED    │
│     Q1: Communication style?                                │
│     Q2: Working pattern?                                    │
│     Q3: AI delegation?                                      │
│     Press Enter to keep current value for each              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. CONFIRM CHANGES                                         │
│     Show summary with changed vs unchanged fields           │
│     "Looks good? (Enter = yes, or type changes)"            │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. SAVE TO WORKSPACE — global unchanged                    │
│     workspace/.portable-spec-kit/user-profile/...           │
│     "This workspace uses local profile from now on"         │
└─────────────────────────────────────────────────────────────┘
```

## Example Session

```
┌─────────────────────────────────────────────────────────────┐
│  AGENT shows current global profile                         │
│  ┌─────────────────────────────────┐                        │
│  │ Jane Smith — B.S. CS. Full-stack│                        │
│  │ Communication: direct           │                        │
│  │ Working pattern: iterative      │                        │
│  │ AI delegation: AI does 70%      │                        │
│  └─────────────────────────────────┘                        │
│  "Keep or customize? (Enter = keep)"                        │
│  User: b                                                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Q1: Communication style?                                   │
│  (a) direct and concise ← RECOMMENDED · CURRENT             │
│  (b) data-driven, comprehensive with tables                 │
│  (c) conversational and collaborative                       │
│  User: b  ← changes to comprehensive                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Q2: Working pattern?                                       │
│  (a) iterative ← RECOMMENDED · CURRENT                      │
│  User: [Enter]  ← keeps current                             │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Q3: AI delegation?                                         │
│  (a) AI does 70% ← RECOMMENDED · CURRENT                    │
│  (b) AI does 90%, user reviews 10%                          │
│  User: b  ← changes to 90%                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  CONFIRM                                                    │
│  ┌──────────────────────────────────────┐                   │
│  │ Communication: comprehensive (changed)│                  │
│  │ Working pattern: iterative (unchanged)│                  │
│  │ AI delegation: 90% (changed)          │                  │
│  └──────────────────────────────────────┘                   │
│  "Looks good? (Enter = yes)"                                │
│  User: [Enter]                                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  SAVED to workspace — global unchanged                      │
│  "This workspace uses local profile from now on"            │
└─────────────────────────────────────────────────────────────┘
```

## Label Reference
| Label | Meaning |
|-------|---------|
| `← RECOMMENDED` | Framework's suggested default |
| `← CURRENT` | User's existing global answer |
| `← RECOMMENDED · CURRENT` | Both are the same value |
| **Enter** | Keeps current value (no retyping) |
| **Custom text** | Accepted as-is, saved verbatim |

## Files
- **Read:** `~/.portable-spec-kit/user-profile/user-profile-{username}.md` (global)
- **Written:** `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md` (local override)
- **Global unchanged** — only workspace gets the customized version
