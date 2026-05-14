# Flow: New Project Setup

> **When:** User asks to create a new project or enters a directory without `agent/` files.

## Trigger
User says "create a new project" or agent detects missing `agent/` directory.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | User says "create a new project" / agent detects missing `agent/` directory |
| **Inputs** | User profile, desired stack, project name |
| **Outputs** | `agent/` (6 files), `src/`, `tests/`, `docs/`, `ard/`, `README.md`, `.gitignore`, `.env.example`, `.github/workflows/ci.yml` |
| **Script** | `bash agent/scripts/psk-new-setup.sh` (optional ergonomic wrapper) |
| **Gate** | Dual-gate validation via `bash agent/scripts/psk-validate.sh new-setup` — both bash critic and sub-agent critic must pass |
| **When blocked** | Dual gate fails → fix flagged issues and re-run; exit 2 = spawn sub-agent critic then re-run |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: LOAD USER PROFILE (agent)                          │
│     workspace/.portable-spec-kit/ → global → setup flow     │
│     Show: "Welcome back, Jane! Setting up new project."     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 2: CREATE PROJECT STRUCTURE (automated)               │
│     agent/ + 6 files, src/, tests/, docs/, ard/             │
│     input/, output/, cache/                                 │
│     README.md, .gitignore, .env.example                     │
│     tests/test-release-check.sh (R→F→T validator)           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 3: REPORT TO USER (agent)                             │
│     Show structure created — wait for user to start         │
└──────────────────────┬──────────────────────────────────────┘
                       │  When user is ready:
┌──────────────────────▼──────────────────────────────────────┐
│  Step 4: SPECS DISCUSSION (agent)                           │
│     Write agent/SPECS.md — requirements, features           │
│     Write per-feature acceptance criteria (### F{n})        │
│     Agent generates test stubs for forward-flow features    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 5: TECH STACK — user approves (agent)                 │
│     Write agent/PLANS.md — architecture, phases             │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 6: INITIALIZE STACK (automated)                       │
│     Install deps, update .gitignore, assign port            │
│     If Python → conda environment selection flow            │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 7: CREATE CI WORKFLOW (automated)                     │
│     .github/workflows/ci.yml (stack-aware test command)     │
│     Always includes test-release-check.sh as final step     │
│     Add CI badge to README.md                               │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 8: DUAL-GATE VALIDATION (agent + critic)              │
│     bash agent/scripts/psk-validate.sh new-setup            │
│     Exit 0 → setup complete                                 │
│     Exit 2 → AWAITING_CRITIC: spawn sub-agent, re-run       │
│     Exit 1/3 → fix issues and re-run                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Rules

- **Structure first, no questions** — the directory scaffold (Step 2) is created immediately without asking; user shapes the project through SPECS and stack discussion afterwards.
- **Test stubs generated automatically** — for every forward-flow feature with acceptance criteria written under `### F{n}`, stubs are generated immediately; no manual trigger needed.
- **Environment selection before any runtime command** — if Python detected, conda/venv selection runs before any `pip install`. No stack-runtime command runs before env is selected.
- **CI is always included** — `.github/workflows/ci.yml` is created for every new project with `test-release-check.sh` as the final step.
- **Dual-gate mandatory** — setup is not complete until both bash critic and sub-agent critic pass via `psk-validate.sh new-setup`.
- **Secrets never committed** — `.env` is always in `.gitignore`; only `.env.example` with placeholder values is committed.

---

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. LOAD USER PROFILE                                       │
│     workspace/.portable-spec-kit/ → global → setup flow     │
│     Show: "Welcome back, Jane! Setting up new project."     │
│     Keep or customize for this project?                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. CREATE PROJECT STRUCTURE (immediately — no questions)   │
│     agent/ + 6 files, src/, tests/, docs/, ard/             │
│     input/, output/, cache/                                 │
│     README.md, .gitignore, .env.example                     │
│     tests/test-release-check.sh (R→F→T validator)           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. REPORT TO USER                                          │
│     Show structure created — wait for user to start         │
└──────────────────────┬──────────────────────────────────────┘
                       │  When user is ready:
┌──────────────────────▼──────────────────────────────────────┐
│  4. SPECS DISCUSSION                                        │
│     Write agent/SPECS.md — requirements, features           │
│     Write per-feature acceptance criteria (### F{n})        │
│     Agent generates test stubs for forward-flow features    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  5. TECH STACK → user approves                              │
│     Write agent/PLANS.md — architecture, phases             │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  6. INITIALIZE STACK                                        │
│     Install deps, update .gitignore, assign port            │
│     If Python → conda environment selection flow            │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  7. CREATE CI WORKFLOW                                      │
│     .github/workflows/ci.yml (stack-aware test command)     │
│     Always includes test-release-check.sh as final step     │
│     Add CI badge to README.md                               │
│     "CI will run on every push and PR."                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  8. START DEVELOPMENT                                       │
│     Update agent/TASKS.md → begin building                  │
└─────────────────────────────────────────────────────────────┘
```

## After Setup (when user is ready)
1. Specs discussion → write `agent/SPECS.md`
   - For each feature, write acceptance criteria under `## Feature Acceptance Criteria / ### F{n} — Feature Name`
   - Agent generates test stubs immediately for any forward-flow feature with criteria written
2. Recommend tech stack → user approves
3. Write `agent/PLANS.md` — architecture, phases
4. Initialize stack → install deps, create source code structure (from 8 templates)
5. **If Python project** → run Environment Selection flow:
   - List existing conda envs
   - Ask user: create new env `<project-name>` or use existing
   - Install deps from `requirements.txt` / `pyproject.toml` / `environment.yml` if present
   - Record env name in `agent/AGENT.md` Stack table
6. **Create CI workflow** → `.github/workflows/ci.yml created` from the ci.yml template
   - Detect test command from confirmed stack (Jest / pytest / Go / Bash)
   - Always include `bash tests/test-release-check.sh agent/SPECS.md` as final step (R→F→T gate)
   - Add CI badge to README.md as first badge
   - Tell user: "CI will run on every push and PR. Enable branch protection in GitHub Settings → Branches."
7. Start development → update `agent/TASKS.md`, begin building

## Files Created — Agent directory structure
- `agent/` — 6 management files
- `README.md`, `.gitignore`, `.env.example`
- `src/`, `tests/`, `docs/`, `ard/`, `input/`, `output/`
- `.portable-spec-kit/user-profile/user-profile-{username}.md` (if not already present)

## Final Validation (MANDATORY — dual gate)

After the scaffold is complete, agent MUST run the dual-gate validation:

```bash
bash agent/scripts/psk-validate.sh new-setup
```

This runs both critics:
1. **Bash critic** — `psk-sync-check.sh --full` verifies file presence, structure, version consistency
2. **Sub-agent critic** — spawns fresh sub-agent via Task tool with `NEW_SETUP` prompt; reads `agent/*`, `README.md`, `.gitignore`, config files; reports `CURRENT:` or `STALE:` per file

Both must pass. Exit code `2 = AWAITING_CRITIC` means agent must spawn sub-agent, write `critic-result.md`, and re-run. Do not mark setup complete until both gates are clean.

### Orchestrator (optional ergonomic wrapper)

```bash
bash agent/scripts/psk-new-setup.sh         # runs preflight + dual gate
```

The orchestrator adds workflow-specific preflight checks before the dual gate. Using it is equivalent to running `psk-validate.sh new-setup` directly, with extra early-failure protection.
