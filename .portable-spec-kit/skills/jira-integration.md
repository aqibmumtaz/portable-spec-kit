# Skill: Jira Integration & Time Tracking
> Loaded when: User says `sync to jira`, `jira status`, `jira setup`, `link jira`, `hours summary`, `install tracker`, or `tracker status`.

---

## Jira Integration (Optional)

Connect TASKS.md to Jira Cloud — sync completed tasks, hours, and logs to Jira's hierarchy via explicit `sync to jira` command. Everything is optional: works without Jira configured, tags ignored silently.

**Core rules:**
- **TASKS.md is single source of truth.** Jira is a mirror. No two-way sync. Ever.
- **Explicit signals only.** Never sync automatically. Only on `sync to jira` command.
- **Zero-install, optional.** Works without Jira configured — tags ignored silently. No breakage.
- **One connection method: Jira REST API v3 via `psk-jira-sync.sh`.** Agent calls the script; script calls Jira. Consistent across all agents and IDEs. Requires `curl` only.
- **Never post worklogs without user confirmation.** Hours confirmation UI is mandatory, not skippable.
- **Hierarchy auto-created** from R→F→T chain on first sync (Epic from Rn, Story from Fn). Existing tickets reused if pre-mapped in AGENT.md.
- **Secrets:** `JIRA_EMAIL`, `JIRA_API_TOKEN` in `.env` only — never commit. **Structural config:** `JIRA_URL`, `JIRA_PROJECT_KEY`, username/epic/version mappings in `agent/AGENT.md` (safe to commit — no sensitive values).
- **Jira Cloud only.** REST API v3 targets Jira Cloud. Jira Server / Data Center uses v2 — not supported in this release.

**TASKS.md inline tags** (backward compatible — ignored if Jira not configured):
```markdown
- [x] Implement login API @aqib [PROJ-101] [story] ~2.5h
```
| Tag | Format | Meaning |
|-----|--------|---------|
| Jira ticket ID | `[PROJ-123]` | Links task to Jira ticket. Pattern: `[A-Z]+-[0-9]+`. One per task |
| Issue type | `[epic]` `[story]` `[task]` `[subtask]` | Explicit Jira type (inferred if absent) |
| Parent ticket | `^PROJ-456` | Explicit parent in Jira hierarchy |
| Auto hours | `~2.5h` | Tracked hours — `~` = unconfirmed, dropped after sync |

**Jira commands:**
| Command | What it does |
|---------|-------------|
| `"sync to jira"` | Full sync flow — reconcile hours, confirm, push to Jira |
| `"jira status"` | Read-only: show tasks pending sync + hours (no API calls) |
| `"link jira PROJ-123"` | Tag active task with Jira ticket ID |
| `"unlink jira from [task]"` | Remove Jira ticket tag |
| `"jira setup"` | Interactive: validate .env, test connection, map issue types |
| `"hours summary"` | Show Track A + Track B breakdown for current session |

---

## Time Tracking (Automatic)

Hours are tracked automatically from two sources, combined, and presented to user before any Jira post.

**Track A — Agent session time:** Wall-clock from first message to last, minus gaps > idle threshold (default 15 min). Every moment engaged with the agent counts.

**Track B — Direct work time:** Time project window was frontmost (from `psk-tracker` daemon log), minus overlap with Track A. Falls back to git/mtime detection if psk-tracker not installed.

**psk-tracker is optional.** Without it, Track B falls back to git log + file mtime detection. Install improves accuracy; absence does not break anything.

**psk-tracker commands:**
| Command | What it does |
|---------|-------------|
| `"install tracker"` | Run `bash agent/scripts/install-tracker.sh` — sets up OS daemon + registers project |
| `"uninstall tracker"` | Stops daemon, removes OS service |
| `"tracker status"` | Show daemon status, last event, today's Track B minutes |
| `"start working on [task]"` | Explicit task-start marker — improves time attribution confidence |

**Deduplication:** When Track A and Track B overlap, count once. Track A takes precedence during active agent turns. `Final = Track A + (Track B − overlap)`.

**Idle threshold:** Default 15 min, configurable in `agent/AGENT.md`: `- **Time tracking idle threshold:** 15 min`
