# Flow: Profile Customization

> **When:** User wants different preferences for a specific project (e.g., more autonomous for personal projects, more collaborative for team work).

## Trigger
On new project setup or returning session (global only), user selects "(b) Customize for this project".

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | User selects `"(b) Customize for this project"` during new project setup or returning session when only a global profile exists |
| **Inputs** | `~/.portable-spec-kit/user-profile/user-profile-{username}.md` (global profile) |
| **Outputs** | `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md` (workspace-local profile); global profile is unchanged |
| **Script** | n/a — agent-driven interactive flow (3 questions with current + recommended values) |
| **Gate** | User must confirm summary before save; pressing Enter at any question keeps the current value |
| **When blocked** | Global profile missing → run User Profile Setup first; workspace directory not writable → agent shows profile content and asks user to create file manually |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: SHOW CURRENT PROFILE (agent)                       │
│     Load global: ~/.portable-spec-kit/user-profile/...      │
│     Display: name, communication, working pattern,          │
│              AI delegation                                  │
│     "Keep or customize? (Enter = keep)"                     │
│     ├─ (a) Keep as-is → done, no changes                    │
│     └─ (b) Customize  → proceed to Step 2                   │
└──────────────────────┬──────────────────────────────────────┘
                       │ User selects (b)
┌──────────────────────▼──────────────────────────────────────┐
│  Step 2: ASK 3 QUESTIONS (agent)                            │
│     Each question shows CURRENT and RECOMMENDED values      │
│     Q1: Communication style?                                │
│     Q2: Working pattern?                                    │
│     Q3: AI delegation?                                      │
│     [Enter] keeps current value — no retyping needed        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 3: CONFIRM CHANGES (agent)                            │
│     Show summary: changed vs unchanged fields               │
│     "Looks good? (Enter = yes, or type changes)"            │
│     ├─ Confirmed → proceed to Step 4                        │
│     └─ Changes   → loop back to Step 2                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 4: SAVE TO WORKSPACE (automated)                      │
│     Write: workspace/.portable-spec-kit/user-profile/...    │
│     Global profile unchanged                                │
│     "This workspace uses local profile from now on"         │
└─────────────────────────────────────────────────────────────┘
```

---

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

---

## Key Rules

- **Global profile is never modified.** Customization always creates a workspace-local copy; the global profile stays as-is for use in other projects.
- **Workspace profile takes precedence.** Once a workspace profile exists, it is loaded silently on every return — no questions asked, no prompts shown.
- **Enter always keeps the current value.** No question forces the user to retype their existing answer; pressing Enter at any prompt is a no-op for that field.
- **RECOMMENDED and CURRENT shown together.** When both values are the same, the label reads `← RECOMMENDED · CURRENT`. This prevents confusion when the user's existing value already matches the framework default.
- **Custom text is accepted verbatim.** If the user types a free-form answer instead of picking a lettered option, it is saved as-is — no validation, no coercion.
- **Customization is project-scoped, not global.** Changes made here do not propagate to other workspace profiles or the global profile. Each project's workspace profile is independent.
