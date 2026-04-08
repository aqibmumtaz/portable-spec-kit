# Flow: Team Collaboration

> **When:** Multiple developers work on the same project, each with
> their own AI agent. Shows how agents coordinate via TASKS.md
> (Persistent Memory Architecture) — no direct messaging, no APIs.
> Also covers the Progress Dashboard trigger.

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
