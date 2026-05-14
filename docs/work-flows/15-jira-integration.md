# Flow 15 — Jira Integration

Sync TASKS.md to Jira Cloud. Explicit only — never automatic.

This flow documents the **Jira Cloud integration** surface of the kit: `sync to jira`, credential handling, R→F→Epic→Story→Task hierarchy auto-creation, and the psk-tracker daemon. Companion scripts: `agent/scripts/psk-jira-sync.sh` and `agent/scripts/psk-tracker.sh`.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | User says `"sync to jira"` — explicit command only, never automatic |
| **Inputs** | `agent/TASKS.md` (completed `[x]` tasks), `agent/AGENT_CONTEXT.md` (session hours), `.env` (Jira credentials), `agent/AGENT.md` (Jira URL + project key) |
| **Outputs** | Jira tickets created/transitioned to Done, worklogs posted, `[PROJ-NNN]` tags written back to `TASKS.md`, `last_sync` timestamp in `AGENT_CONTEXT.md` |
| **Script** | `bash agent/scripts/psk-jira-sync.sh` · `bash agent/scripts/psk-tracker.sh` (optional daemon) |
| **Gate** | PID-based lock (`agent/.jira-sync.lock`); credential check and project key validation at Step 1 before any writes |
| **When blocked** | Credential check fails · project key invalid · `JIRA_API_TOKEN` missing from `.env` · concurrent sync already running (lock held) |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  USER SAYS "sync to jira"                                   │
│     Trigger: explicit command only                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  STEP 1: CREDENTIAL CHECK + LOCK                            │
│     bash agent/scripts/psk-jira-sync.sh --test              │
│     ├─ Reads JIRA_EMAIL + JIRA_API_TOKEN from .env          │
│     ├─ Reads JIRA_URL + JIRA_PROJECT_KEY from AGENT.md      │
│     ├─ Acquires PID-based lock (agent/.jira-sync.lock)      │
│     ├─ Tests: GET /rest/api/3/myself                        │
│     ├─ Validates project key: GET /project/{KEY}            │
│     ├─ Pass → continue                                      │
│     └─ Fail → actionable error message + exit               │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  STEP 2: RECONCILE HOURS (Track A + Track B)                │
│     a. Read AGENT_CONTEXT.md → Track A sessions             │
│     b. If psk-tracker installed → report.sh → Track B       │
│     c. Dedup overlap (A takes precedence)                   │
│     d. Cross-check with git elapsed                         │
│     e. Per-task totals: AgentMin + DirectMin = Total        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  STEP 3: SCAN TASKS.md                                      │
│     Collect all [x] tasks not yet synced                    │
│     ├─ N = 0 → "Nothing to sync" → exit                     │
│     ├─ N > 20 → "Large sync — all / recent / select?"       │
│     └─ N ≤ 20 → "N tasks found. Sync all? (Enter/select)"   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  STEP 4: JIRA HIERARCHY CREATION (untagged tasks)           │
│     Resolve R→F chain → create Epic/Story/Task              │
│     Write [PROJ-NNN] tags back to TASKS.md                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  STEP 5: HOURS CONFIRMATION UI (Automatic hours tracking)   │
│     Show per-task: ticket, hours, grade, confidence         │
│     ├─ User accepts (Enter) → proceed                       │
│     ├─ User edits ("1 2.5") → adjust                        │
│     └─ User skips task → excluded from sync                 │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  STEP 6: PUSH TO JIRA (per ticket)                          │
│     For each ticket via psk-jira-sync.sh:                   │
│     ├─ POST worklog (hours + started timestamp)             │
│     ├─ POST transition → Done (auto-detect or mapped)       │
│     ├─ POST comment with commit hash                        │
│     └─ Errors → continue to next, report at end             │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  STEP 7: CONFIRMATION OUTPUT                                │
│     Synced: N ok  Skipped: M skip  Errors: E warn           │
│     Per-ticket status line                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  STEP 8: UPDATE CONTEXT + RELEASE LOCK                      │
│     Write last_sync timestamp to AGENT_CONTEXT.md           │
│     Clear synced sessions from Time Tracking                │
│     Failed tickets → pending_retry for next sync            │
│     Delete agent/.jira-sync.lock                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Rules

- **Explicit only — never automatic.** The Jira sync never runs without `"sync to jira"` from the user. No release step, session start, or hook triggers it automatically.
- **Credential gate runs first.** Step 1 tests the Jira API connection and validates the project key before any read or write operation. A failed credential check exits immediately with an actionable error — no partial state.
- **PID-based lock prevents concurrent syncs.** `agent/.jira-sync.lock` is acquired at Step 1 and released at Step 8. A second sync attempt while the lock is held fails fast with a clear message.
- **API keys never appear in committed files.** `JIRA_EMAIL` and `JIRA_API_TOKEN` live in `.env` (gitignored). `JIRA_URL` and `JIRA_PROJECT_KEY` go in `agent/AGENT.md` (committed — not secrets). Never store credentials in TASKS.md or any committed file.
- **Errors per ticket do not abort the sync.** Step 6 continues to the next ticket on failure, collects all errors, and reports them at Step 7. A partial sync is better than no sync.
- **`[PROJ-NNN]` tags are written back to TASKS.md.** After Jira ticket creation, the tag is appended to the matching task line so subsequent syncs can detect already-synced tasks without querying Jira.
- **Hours confirmation is mandatory before push.** The user reviews and can edit per-task hour estimates at Step 5. No worklog is posted without user acceptance — the agent never silently submits hours.
