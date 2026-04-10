# Flow: User Profile Setup

> **When:** First time using the kit on any machine — no profile exists anywhere.

## Trigger
Agent reads framework → checks lookup order → no profile found anywhere.

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. DETECT USERNAME                                         │
│     git config user.name → slugified (lowercase, spaces→-)  │
│     Filename: user-profile-jane-smith.md                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. FETCH GITHUB PROFILE                                    │
│     gh api user → full name, bio (if gh authenticated)      │
│     ├─ gh available → "Welcome, Jane Smith!"                │
│     ├─ gh not authenticated → ask name + expertise manually │
│     └─ gh not installed → ask manually                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. ASK 3 PREFERENCE QUESTIONS                              │
│     Q1: Communication style?                                │
│         (a) direct and concise ← RECOMMENDED                │
│         (b) data-driven, comprehensive with tables          │
│         (c) conversational and collaborative                │
│         Enter = use recommended                             │
│                                                             │
│     Q2: Working pattern?                                    │
│         (a) iterative ← RECOMMENDED                         │
│         (b) plan-first                                      │
│         (c) prototype-fast                                  │
│         Enter = use recommended                             │
│                                                             │
│     Q3: AI delegation?                                      │
│         (a) AI does 70%, user guides 30% ← RECOMMENDED      │
│         (b) AI does 90%, user reviews 10%                   │
│         (c) 50/50 collaboration                             │
│         Enter = use recommended                             │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. CONFIRM PROFILE                                         │
│     ┌─────────────────────────────────┐                     │
│     │ Your profile:                   │                     │
│     │ Jane Smith — B.S. CS.           │                     │
│     │ Communication: direct           │                     │
│     │ Working pattern: iterative      │                     │
│     │ AI delegation: AI does 70%      │                     │
│     └─────────────────────────────────┘                     │
│     "Looks good? (Enter = yes, or type changes)"            │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  5. SAVE PROFILE                                            │
│     ~/.portable-spec-kit/user-profile/user-profile-{u}.md   │
│     workspace/.portable-spec-kit/user-profile/...           │
│     → won't ask again on this machine                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  6. CONTINUE TO PROJECT SETUP                               │
│     ✓ Profile ready — proceeds to workspace/project scan    │
└─────────────────────────────────────────────────────────────┘
```

## User Actions
- **Pick a/b/c** → selects that option
- **Press Enter** → uses recommended
- **Type custom text** → saved as-is
- **Skip all (Enter through everything)** → all recommended defaults applied

## Edge Cases
| Scenario | Handling |
|---|---|
| No gh CLI | Ask name/expertise manually |
| gh not authenticated | Fall back to asking manually |
| GitHub name empty | Use GitHub login as fallback |
| GitHub bio empty | Ask for education and expertise |
| Profile file exists but empty | Treat as missing — run full setup |
| Profile file exists with content | Read and use directly — don't recreate |
| Agent can't write files | Show content, ask user to create manually |
| User skips all questions | Recommended defaults applied for all |

## Files Created
- `~/.portable-spec-kit/user-profile/user-profile-{username}.md`
- `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md`
