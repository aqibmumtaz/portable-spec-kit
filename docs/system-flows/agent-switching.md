# Flow: Agent Switching

> **When:** User switches from one AI agent to another (e.g., Claude → Cursor → Copilot).

## Why It Works
All agents read the same framework file via symlinks. All managed files (AGENT_CONTEXT.md, TASKS.md, user profiles) are standard markdown — no proprietary formats.

## Flow

```
Day 1: User works with Claude
    Claude reads CLAUDE.md (symlink → portable-spec-kit.md)
    Reads user profile from .portable-spec-kit/user-profile/
    Reads agent/AGENT_CONTEXT.md
    Works on project → updates AGENT_CONTEXT.md, TASKS.md
    │
    ▼
Day 2: User switches to Cursor
    Cursor reads .cursorrules (symlink → same portable-spec-kit.md)
    Reads SAME user profile
    Reads SAME agent/AGENT_CONTEXT.md
    "Welcome back, Jane! Here's where we left off..."
    Picks up exactly where Claude stopped
    │
    ▼
Day 3: User switches to Copilot
    Copilot reads .github/copilot-instructions.md (symlink → same file)
    Reads SAME profile, SAME context
    Continues seamlessly — zero data loss
```

## What Transfers Across Agents
| Data | Storage | Transfers? |
|---|---|---|
| User profile (name, style, preferences) | `.portable-spec-kit/user-profile/` | Yes — standard markdown |
| Project state (what's done, next, decisions) | `agent/AGENT_CONTEXT.md` | Yes — standard markdown |
| Tasks (completed, pending) | `agent/TASKS.md` | Yes — standard markdown |
| Specs, planning, tracker | `agent/SPECS.md`, `PLANS.md`, `RELEASES.md` | Yes — standard markdown |
| Framework rules | `portable-spec-kit.md` (via symlinks) | Yes — all agents read same file |

## What Does NOT Transfer
| Data | Why |
|---|---|
| Agent's internal memory | Each agent has its own memory system (Claude: `.claude/`, Cursor: internal). Not portable. |
| In-session conversation | Conversations don't carry across agents. But AGENT_CONTEXT.md captures the key decisions. |

## Symlink Setup
```
portable-spec-kit.md                  ← Source (edit this one)
CLAUDE.md → portable-spec-kit.md      ← Claude Code
.cursorrules → portable-spec-kit.md   ← Cursor
.windsurfrules → portable-spec-kit.md ← Windsurf
.clinerules → portable-spec-kit.md    ← Cline
.github/copilot-instructions.md → portable-spec-kit.md ← Copilot
```

Edit `portable-spec-kit.md` → all 5 agents see the change instantly.

## Key Guarantee
All managed files are **plain markdown** — no proprietary formats, no agent-specific storage. Any agent can read what any other agent wrote.
