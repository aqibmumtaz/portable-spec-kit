# Refine — Actor–Critic Remediation Loop for Speckit Projects

Automated QA + auto-fix loop that runs after prep release. A fresh-context **QA-Agent** (Critic) black-box-tests the project against SPECS acceptance criteria, files bugs to `agent/TASKS.md`, and a fresh-context **Dev-Agent** (Actor) fixes them atomically — without the user doing manual integration testing.

## Why

Existing kit gates (`psk-sync-check`, `psk-doc-sync`, R→F→T, validation critics) enforce **structural** completeness: every feature has a test, counts align, docs mention things. They cannot catch a trivial assertion against a stub implementation — both pass, feature is broken, "lost in the middle" during development.

Refine adds the **functional** layer. QA-Agent exercises every feature through its real public interface (CLI/API/UI), compares output to the user-facing promise in SPECS, and files bugs when reality doesn't match promise.

## Usage

```bash
# One-time (kit already has refine; for other projects use installer)
bash reflex/install-into-project.sh ~/my-project   # Phase 4+

# Every cycle
bash reflex/run.sh
```

Refine refuses to run unless HEAD is a prep-release commit (enforced via `agent/.release-state/last-prep-release` marker).

## Architecture

- **QA-Agent** (fresh context, black-box, no source access) — reads REQS/SPECS/PLANS/DESIGN/TASKS, exercises features, files bugs as `@reflex-dev` tasks in TASKS.md.
- **Dev-Agent** (fresh context, full repo access) — fixes `@reflex-dev` tasks atomically, per-commit mechanical gates.
- **Orchestrator** (`run.sh`) — precondition check → spawn QA → spawn Dev → record outcome.

Research framing: Actor–Critic loop (Sutton & Barto; Shinn et al. 2023 *Reflexion*) with verification derived from spec-driven program synthesis (Solar-Lezama 2008). Counters lost-in-the-middle (Liu et al. 2023).

## Directory layout

| Path | Purpose |
|---|---|
| `run.sh` | Orchestrator |
| `lib/` | Precondition, spawn, gates, file-bugs, regression-diff helpers |
| `prompts/qa-agent.md` | Critic prompt (generic) |
| `prompts/dev-agent.md` | Actor prompt (generic) |
| `config.yml` | Budget, gates, cadence, coverage strategy |
| `history/` | Per-cycle artifacts — mostly gitignored, `summary.csv` + `latest.md` + `verdict.md` tracked |
| `sandbox/` | Ephemeral (gitignored) |

## Safety rails

- Per-commit mechanical gates (tests + sync-check + doc-sync)
- Max 3 retries per fix attempt
- Max 200 tool calls per cycle (budget cap)
- Cycle-over-cycle regression check via TASKS.md diff
- Auto-merge only when `progress > 0` (Phase 3+)
- Every refine commit is a single revertable git commit

## Phases

| Phase | Delivered |
|---|---|
| 1 | QA-Agent alone; user reads reports manually |
| 2 | Dev-Agent wired; mechanical gates per commit |
| 3 | Regression check + auto-merge |
| 4 | `install-into-project.sh` for user projects |
| 5 (optional) | Cron + notifications |

See `/Users/AqibMumtaz/.claude/plans/parsed-plotting-dusk.md` for full spec.
