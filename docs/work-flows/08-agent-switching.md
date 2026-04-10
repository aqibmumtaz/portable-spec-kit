# Flow: Agent Switching

> **When:** User switches from one AI agent to another (e.g., Claude → Cursor → Copilot).

## Why It Works
All agents read the same framework file via symlinks. All managed files (AGENT_CONTEXT.md, TASKS.md, user profiles) are plain markdown — no proprietary formats. Any agent can read what any other agent wrote.

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────┐
│  DAY 1: AGENT A (e.g., Claude)                              │
│     Reads CLAUDE.md → symlink → portable-spec-kit.md        │
│     Reads user profile from .portable-spec-kit/user-profile/│
│     Reads agent/AGENT_CONTEXT.md                            │
│     Works on project → updates AGENT_CONTEXT.md, TASKS.md   │
└──────────────────────┬──────────────────────────────────────┘
                       │ User switches agent
┌──────────────────────▼──────────────────────────────────────┐
│  DAY 2: AGENT B (e.g., Cursor)                              │
│     Reads .cursorrules → same symlink → portable-spec-kit.md│
│     Reads SAME user profile                                 │
│     Reads SAME agent/AGENT_CONTEXT.md                       │
│     "Welcome back, Jane! Here's where we left off..."       │
│     Picks up exactly where Agent A stopped                  │
│     Works → updates SAME AGENT_CONTEXT.md, TASKS.md         │
└──────────────────────┬──────────────────────────────────────┘
                       │ User switches again
┌──────────────────────▼──────────────────────────────────────┐
│  DAY N: AGENT C (e.g., Copilot)                             │
│     Reads .github/copilot-instructions.md → same source     │
│     Reads SAME profile, SAME context                        │
│     Continues seamlessly — zero data loss                   │
└─────────────────────────────────────────────────────────────┘
```

## What Transfers Across Agents
| Data | Storage | Transfers? |
|---|---|---|
| User profile (name, style, preferences) | `.portable-spec-kit/user-profile/` | ✅ Standard markdown |
| Project state (what's done, next, decisions) | `agent/AGENT_CONTEXT.md` | ✅ Standard markdown |
| Tasks (completed, pending) | `agent/TASKS.md` | ✅ Standard markdown |
| Specs, planning, releases | `agent/SPECS.md`, `PLANS.md`, `RELEASES.md` | ✅ Standard markdown |
| Framework rules | `portable-spec-kit.md` (via symlinks) | ✅ All agents read same file |

## What Does NOT Transfer
| Data | Why |
|---|---|
| Agent's internal memory | Each agent has its own memory system (e.g., Claude: `.claude/memory/`). Not portable. |
| In-session conversation | Conversations don't carry across agents — AGENT_CONTEXT.md captures key decisions instead |

## Symlink Setup
```
portable-spec-kit.md                         ← Source (edit this one)
CLAUDE.md → portable-spec-kit.md             ← Claude Code
.cursorrules → portable-spec-kit.md          ← Cursor
.windsurfrules → portable-spec-kit.md        ← Windsurf
.clinerules → portable-spec-kit.md           ← Cline
.github/copilot-instructions.md → ...        ← Copilot
```

Edit `portable-spec-kit.md` → all 5 agents see the change instantly.

## Key Guarantee
All managed files are **plain markdown** — no proprietary formats, no agent-specific storage. Any agent can read what any other agent wrote. Context is preserved through the `agent/` directory, not inside the agent.
