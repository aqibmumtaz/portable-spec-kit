# Flow: Agent Switching

> **When:** User switches from one AI agent to another (e.g., Claude → Cursor → Copilot).

## Why It Works
All agents read the same framework file via symlinks. All managed files (AGENT_CONTEXT.md, TASKS.md, user profiles) are plain markdown — no proprietary formats. Any agent can read what any other agent wrote.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | User opens a different AI agent (Cursor, Copilot, Windsurf, Cline) in a project previously managed by another agent |
| **Inputs** | `portable-spec-kit.md` (via agent-specific symlink), `.portable-spec-kit/user-profile/`, `agent/AGENT_CONTEXT.md`, `agent/TASKS.md`, `agent/SPECS.md`, `agent/PLANS.md` |
| **Outputs** | New agent is fully briefed — greets user by name, resumes from exact point where prior agent stopped |
| **Script** | n/a — automatic on session start; symlinks established by `install.sh` |
| **Gate** | Symlinks must exist for the new agent's config file (e.g., `.cursorrules` for Cursor); user profile must be in `.portable-spec-kit/user-profile/` |
| **When blocked** | Symlinks missing (kit not installed for that agent) → run `install.sh --yes`; agent/ files not committed → new agent cannot read prior state |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  DAY 1: AGENT A (e.g., Claude) (agent)                      │
│     Reads CLAUDE.md → symlink → portable-spec-kit.md        │
│     Reads user profile from .portable-spec-kit/user-profile/│
│     Reads agent/AGENT_CONTEXT.md                            │
│     Works on project → updates AGENT_CONTEXT.md, TASKS.md   │
│     Commits changes to git                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │ User switches agent
┌──────────────────────▼──────────────────────────────────────┐
│  DAY 2: AGENT B (e.g., Cursor) (agent)                      │
│     Reads .cursorrules → same symlink → portable-spec-kit.md│
│     Reads SAME user profile                                 │
│     Reads SAME agent/AGENT_CONTEXT.md (committed by Agent A)│
│     "Welcome back, [name]! Here's where we left off..."     │
│     Picks up exactly where Agent A stopped                  │
│     Works → updates SAME AGENT_CONTEXT.md, TASKS.md         │
└──────────────────────┬──────────────────────────────────────┘
                       │ User switches again
┌──────────────────────▼──────────────────────────────────────┐
│  DAY N: AGENT C (e.g., Copilot) (agent)                     │
│     Reads .github/copilot-instructions.md → same source     │
│     Reads SAME profile, SAME context                        │
│     Continues seamlessly — zero data loss                   │
└─────────────────────────────────────────────────────────────┘
```

---

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

---

## Key Rules

- **All agents read the same source file.** `portable-spec-kit.md` is the single source of truth; agent-specific filenames (`CLAUDE.md`, `.cursorrules`, etc.) are symlinks — edit the source, all agents see the update instantly.
- **Commit before switching.** Prior agent's changes must be committed to git so the new agent reads the latest `agent/AGENT_CONTEXT.md` and `agent/TASKS.md`. Uncommitted changes are invisible to the incoming agent.
- **Agent-internal memory does not transfer.** Each agent's proprietary memory store (e.g., Claude Code's `.claude/memory/`) is siloed. Only committed `agent/` files carry state across agents.
- **User profile lookup order is fixed.** Workspace profile first (`workspace/.portable-spec-kit/user-profile/`), then global (`~/.portable-spec-kit/user-profile/`). New agent inherits exactly the same profile as the prior agent.
- **Symlinks must be established for each agent.** `install.sh` creates all agent symlinks. If a new agent's symlink is missing, run `install.sh --yes` — it is idempotent.
