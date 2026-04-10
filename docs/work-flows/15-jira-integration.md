# Flow 15 — Jira Integration

Sync TASKS.md to Jira Cloud. Explicit only — never automatic.

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
│  STEP 5: HOURS CONFIRMATION UI                              │
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
