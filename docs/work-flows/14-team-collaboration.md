# Flow: Team Collaboration

> **When:** Multiple developers work on the same project, each with
> their own AI agent. Shows how agents coordinate via TASKS.md
> (Persistent Memory Architecture) — no direct messaging, no APIs.
> Also covers the Progress Dashboard trigger.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | Multiple developers working on the same project; `"my tasks"` / `"assign"` / `"delegate"` / `"progress"` / `"dashboard"` |
| **Inputs** | `agent/TASKS.md` (with `@username` tags), `git config user.name` for identity |
| **Outputs** | Per-user filtered task view, delegation updates in `TASKS.md`, inline progress dashboard |
| **Script** | No dedicated script — agent reads `TASKS.md` directly; dashboard rendered inline |
| **Gate** | None (advisory workflow) — TASKS.md is committed to git so every pull syncs the shared state |
| **When blocked** | `TASKS.md` missing → `"run init"` · git user not configured → prompt for username |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  SETUP — tag tasks with @username ownership                 │
│     Format: - [ ] Task description @username                │
│     Multiple owners: - [ ] Review schema @aqib @sara        │
│     Untagged = unassigned                                   │
│     Username = slugified git config user.name               │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  PER-USER VIEW — "my tasks" / "what do I have"              │
│     Agent detects current user: git config user.name        │
│     Filters TASKS.md for @{current-user} tasks              │
│     Shows pending + done tasks for that user                │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  DELEGATION — "assign [task] to @username"                  │
│     Agent finds task in TASKS.md (by keyword or Fn number)  │
│     Adds @username tag · commits · Agent B pulls and sees   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  CROSS-AGENT COORDINATION (no APIs, no messages)            │
│     Agent A assigns task → commits → pushes                 │
│     Agent B pulls → sees new @username tag in TASKS.md      │
│     TASKS.md is the coordination channel                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  PROGRESS DASHBOARD — "progress" / "dashboard" / "burndown" │
│     Agent reads TASKS.md · counts done vs total per version │
│     Renders inline dashboard with progress bars             │
│     BY CONTRIBUTOR section when @username tags present      │
└─────────────────────────────────────────────────────────────┘
```

---

## End-to-End Flow: Multi-Agent Task Tracking

```
┌─────────────────────────────────────────────────────────────┐
│  SETUP — tag tasks with @username ownership                 │
│     Format: - [ ] Task description @username                │
│     Multiple owners: - [ ] Review schema @aqib @sara        │
│     Untagged = unassigned                                   │
│     Username = slugified git config user.name               │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  PER-USER VIEW — "my tasks" / "what do I have"              │
│     Agent detects current user: git config user.name        │
│     Filters TASKS.md for @{current-user} tasks              │
│     Output:                                                 │
│       TASKS — @aqib  (v0.4 — Portable Spec Kit)             │
│       v0.4 — Current                                        │
│         [ ] Implement login API                             │
│         [ ] Review schema  (shared with @sara)              │
│         [x] Setup project structure                         │
│       ASSIGNED TO @aqib: 3 tasks (1 done, 2 pending)        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  DELEGATION — "assign [task] to @username"                  │
│     Agent finds task in TASKS.md (by keyword or Fn number)  │
│     Adds @username tag to that line                         │
│     Confirms: "Assigned 'Task X' to @sara — ProjectName"    │
│     ├─ Already assigned → skip, confirm already assigned    │
│     └─ Multiple owners → append tag (@aqib @sara)           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  CROSS-AGENT COORDINATION (no APIs, no messages)            │
│     Agent A assigns task → commits → pushes                 │
│     Agent B pulls → sees new @username tag in TASKS.md      │
│     Agent B shows task in @B's per-user view                │
│     TASKS.md is the coordination channel                    │
│     This is Persistent Memory Architecture in action        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  SHARED TASK COMPLETION (@a @b)                             │
│     Both owners must mark done (last to mark = complete)    │
│     Until @b marks done → still shows [ ] in @b's view      │
│     Shown in dashboard as pending until both confirm        │
└─────────────────────────────────────────────────────────────┘
```

---

## Progress Dashboard Flow

```
┌─────────────────────────────────────────────────────────────┐
│  TRIGGER WORDS (say any of these)                           │
│     "progress" · "dashboard" · "burndown"                   │
│     "status report" · "how are we doing" · "what's left"    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  AGENT READS TASKS.md (read-only — never modifies)          │
│     Parse every - [x] and - [ ] line per version heading    │
│     Count done vs total per version group                   │
│     Compute percentage: done / total * 100                  │
│     Build progress bar: each █ = 5%, width = 20 chars       │
│     Right-pad with ░ to fill 20 chars                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  GENERATES DASHBOARD INLINE                                 │
│     ══ PROGRESS DASHBOARD — ProjectName (v0.4.x)            │
│     OVERALL — Done: 13  [████████████░░░░░░░░]  65%         │
│     Pending: 7  ·  Total: 20                                │
│     BY VERSION:                                             │
│       v0.0  ████████████████████  8/8   100%  ✅ Done       │
│       v0.1  ████████████████████  14/14 100%  ✅ Done       │
│       v0.4  ████████░░░░░░░░░░░░  13/20  65%  🔄 Current    │
│     CURRENT VERSION TASKS (v0.4):                           │
│       [x] F58 Progress Dashboard                            │
│       [ ] Sync to GitHub                                    │
│     NEXT ACTIONS:                                           │
│       1. Sync to aqibmumtaz/portable-spec-kit               │
│       2. Submit paper to arXiv cs.SE                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  BY CONTRIBUTOR (if @username tags present in TASKS.md)     │
│     @aqib      ████████████░░░░  6/8   75%                  │
│     @sara      ████░░░░░░░░░░░░  2/6   33%                  │
│     Unassigned ████░░░░░░░░░░░░  2/10  20%                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Edge Cases

| Condition | Behaviour |
|-----------|-----------|
| TASKS.md missing | "No TASKS.md found — run `init` to set up the project" |
| All tasks done | "🎉 All tasks complete — ready for release" |
| No version headings | Show flat list of all done/pending tasks |
| Current version has 0 tasks | "No tasks added for this version yet" |
| 50+ tasks in current version | Truncate CURRENT VERSION TASKS to 10 done + all pending; "(N more done — see TASKS.md)" |
| No blockers section | Omit BLOCKERS row entirely |
| No @username tags | Omit BY CONTRIBUTOR section |
| User runs "my tasks" on fresh project | "No tasks tagged to you yet. Add @{username} to any task to claim ownership" |
| Git user not configured | "What's your username? (used for task filtering)" |
| @username typo in TASKS.md | Show as-is in dashboard — don't silently drop |
| All tasks owned by one user | "All tasks owned by @username — consider distributing" |

---

## Key Rules

- **No direct agent-to-agent communication.** Agents coordinate exclusively by reading and writing committed `agent/TASKS.md` — no APIs, no message queues, no real-time connections.
- **`@username` tag is the ownership contract.** A task without a tag is unassigned. A task with `@aqib @sara` requires both to mark done before it leaves the pending view.
- **Shared task completion requires all owners.** The last owner to mark `[x]` makes the task complete. Until then the task remains `[ ]` in every other owner's per-user view.
- **Dashboard is read-only.** The agent never modifies TASKS.md when generating a dashboard — it reads, parses, and renders inline only.
- **Git is the sync mechanism.** Agent A commits the delegation; Agent B pulls and immediately sees the updated `@username` tag. No additional tooling required.
- **Identity comes from git config.** `git config user.name` is the username source. If not configured, the agent prompts once and uses the answer for the session.
- **All multi-agent state is auditable.** Every assignment, re-assignment, and completion is a git commit — full trail of who did what and when.

---

## Persistent Memory Architecture

The Persistent Memory Architecture is what makes multi-agent collaboration work:

| Property | What it means |
|----------|--------------|
| **Durable** | Persists in git across time — survives context windows |
| **Shared** | Any agent on any machine reads the same TASKS.md |
| **Portable** | Works with Claude, Cursor, Copilot, Cline, Windsurf |
| **Team-scale** | Multiple users/agents coordinate without real-time connection |
| **Auditable** | Git history shows every assignment, change, and completion |

There is no agent-to-agent communication, no API, no message queue. Agents coordinate by reading and writing the same files in git. This is the same mechanism that makes specs persistent — applied to team task management.
