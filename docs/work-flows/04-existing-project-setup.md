# Flow: Existing Project Setup

> **When:** User installs the spec kit on a project that already has
> code — first-time onboarding, not returning. Agent has never seen
> this codebase before.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | Agent detects existing codebase with no `agent/` directory, or user explicitly asks to onboard an existing project |
| **Inputs** | Existing source files, config files (`package.json`, `requirements.txt`, `go.mod`, etc.), `.env.example` |
| **Outputs** | `agent/AGENT.md`, `agent/AGENT_CONTEXT.md`, remaining `agent/*.md` files from templates, optional `ci.yml` |
| **Script** | `bash agent/scripts/psk-existing-setup.sh` (optional ergonomic wrapper) |
| **Gate** | Dual-gate validation via `bash agent/scripts/psk-validate.sh existing-setup` — both bash critic and sub-agent critic must pass |
| **When blocked** | Ambiguous stack → ask user before filling `AGENT.md`; dual gate fails → fix and re-run |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Step 0: DETECT PROJECT STATE (automated, once per session) │
│     ├─ Mapped   → ✅ Read context normally — skip scan      │
│     ├─ Partial  → ⚠  Fill gaps only — skip full scan        │
│     └─ New/None → 🔍 No context — proceed with full scan ↓  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 1: ANNOUNCE SCAN (agent)                              │
│     "Spec Kit is understanding your project —               │
│      scanning structure, stack, files, dependencies..."     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 2: SCAN THOROUGHLY (automated)                        │
│     Config files: package.json, requirements.txt,           │
│       pyproject.toml, Dockerfile, go.mod, Cargo.toml, etc.  │
│     Top-level dirs + sample src/ structure                  │
│     Build complete picture before touching anything         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 3: FILL agent/AGENT.md FROM SCAN (agent)              │
│     Stack, tech, dev server port, key scripts               │
│     Env var names (.env.example — names only, never values) │
│     If Python → run Environment Selection flow              │
│     Never leave fields TBD if answer visible in code        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 4: FILL agent/AGENT_CONTEXT.md FROM SCAN (agent)      │
│     Current phase, what appears done, key decisions         │
│     Directory structure and tech choices visible in code    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 5: PRESENT CHECKLIST (agent)                          │
│     "Scan complete. Here's what I found and suggest:"       │
│     [x] Create agent/ (pre-filled from scan)                │
│     [ ] Commit agent/ to git                                │
│     [ ] Create .env.example from .env                       │
│     [ ] Create .github/workflows/ci.yml                     │
│     [ ] Restructure README.md to match template             │
│     "Which changes? All, some, or none."                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 6: APPLY SELECTED CHANGES ONLY (agent)                │
│     agent/ files — always safe to create                    │
│     Everything else — only if user selected it              │
│     Never rename/move/delete without explicit approval      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 7: DUAL-GATE VALIDATION (agent + critic)              │
│     bash agent/scripts/psk-validate.sh existing-setup       │
│     Exit 0 → setup complete                                 │
│     Exit 2 → AWAITING_CRITIC: spawn sub-agent, re-run       │
│     Exit 1/3 → fix issues and re-run                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Rules

- **Guide, don't force** — agent presents a checklist; user decides which changes to apply. Nothing is modified without user selection (except `agent/` files, which are always safe to create).
- **Never overwrite existing files without approval** — `README.md`, `.gitignore`, source code, and config files are read-only during scan; changes require explicit user selection.
- **Scan first, touch nothing** — the full scan (Step 2) completes before any file is written; no partial-state risk.
- **Secrets never read** — `.env` variable names may be read to build `.env.example`; values are never read, displayed, or stored.
- **Ambiguous stack → ask** — if config files give conflicting signals, ask the user before filling `AGENT.md`.
- **Dual-gate mandatory** — setup is not complete until both bash critic and sub-agent critic pass; sub-agent verifies no existing files were destructively modified.

---

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────┐
│  0. DETECT PROJECT STATE (show once at session start)       │
│     Inspect agent/ directory:                               │
│     ├─ Mapped   → ✅ Project mapped — read context normally │
│     ├─ Partial  → ⚠  Partial context — fill gaps, skip scan │
│     └─ New/None → 🔍 No context — proceed with full scan ↓  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  1. ANNOUNCE SCAN                                           │
│     "Spec Kit is understanding your project —               │
│      scanning structure, stack, files, dependencies..."     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. SCAN THOROUGHLY                                         │
│     Config files:                                           │
│       package.json · requirements.txt · pyproject.toml      │
│       Dockerfile · docker-compose.yml · go.mod · Cargo.toml │
│       tsconfig.json · pubspec.yaml · .env.example           │
│     Top-level dirs + sample src/ structure                  │
│     Build complete picture before touching anything         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. FILL agent/AGENT.md FROM SCAN                           │
│     Stack, tech, dev server port, key scripts               │
│     Env var names (.env.example — names only, never values) │
│     If Python project → run Environment Selection flow      │
│     Never leave fields TBD if answer is visible in code     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. FILL agent/AGENT_CONTEXT.md FROM SCAN                   │
│     Current phase, what appears done, key decisions         │
│     Directory structure and tech choices visible in code    │
│     Phase estimate from codebase state                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  5. PRESENT CHECKLIST                                       │
│     "Scan complete. Here's what I found and suggest:"       │
│                                                             │
│     Detected: [stack] · [version] · Port [N]                │
│                                                             │
│     [x] Create agent/ (6 files, pre-filled from scan)       │
│     [x] Create WORKSPACE_CONTEXT.md                         │
│     [ ] Commit agent/ to git (team/OS — AI-powered onboard) │
│     [ ] Create .env.example from .env                       │
│     [ ] Create .github/workflows/ci.yml                     │
│     [ ] Restructure README.md to match template             │
│                                                             │
│     "Which changes? All, some, or none."                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  6. APPLY SELECTED CHANGES ONLY                             │
│     agent/ files — always safe to create                    │
│     Everything else — only if user selected it              │
│     Never rename / move / delete without explicit approval  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  7. CONTINUE NORMALLY                                       │
│     Project is now spec kit managed                         │
│     Proceed to user's task — no more setup prompts          │
└─────────────────────────────────────────────────────────────┘
```

## Scan Edge Cases

| Condition | Action |
|-----------|--------|
| No recognizable stack | Ask: "What stack is this project using?" |
| Multiple stacks (monorepo) | Ask which subdirectory first; handle each separately |
| Conflicting signals | Flag to user before filling AGENT.md |
| `.env` present | Read variable names only — never values |
| Existing README.md | Read to supplement findings; never overwrite without approval |
| Large project (100+ files) | Scan config + top-level dirs; sample src/ only |
| Team project with existing agent/ | Read and use existing context, don't overwrite |
| Team / open-source project | Recommend committing agent/ — enables AI-powered onboarding for contributors |
| agent/ already in .gitignore | Warn: "agent/ is gitignored — contributors won't be briefed on clone. Remove for team projects?" |

## Kit Status States (Step 0)

| State | Condition | Action |
|-------|-----------|--------|
| **Mapped** | `agent/AGENT_CONTEXT.md` exists with real content | Read agent/ files, continue normally |
| **Partial** | `agent/` exists but files mostly TBD | Fill missing fields only |
| **New** | `agent/` missing or all template placeholders | Full scan (Steps 1–6 above) |

## Difference from Returning Session

| | Existing Project Setup | Returning Session |
|-|----------------------|------------------|
| **When** | First time kit sees this codebase | Kit already ran before |
| **Agent files** | Don't exist yet | Already exist — reading them |
| **Scan** | Full scan of all source files | Read agent/ files only |
| **User prompt** | Checklist — user picks what to add | None — loads silently |

## Files Created or Updated
- `agent/AGENT.md` — stack, tech, ports from actual code
- `agent/AGENT_CONTEXT.md` — current phase and state
- `agent/SPECS.md`, `PLANS.md`, `TASKS.md`, `RELEASES.md` — from templates
- `WORKSPACE_CONTEXT.md` — if not already present
- `.github/workflows/ci.yml` — if user selects it (see CI/CD Setup flow)

## Final Validation (MANDATORY — dual gate)

After retroactive fill is complete, agent MUST run the dual-gate validation:

```bash
bash agent/scripts/psk-validate.sh existing-setup
```

Bash critic (psk-sync-check.sh) + sub-agent critic (EXISTING_SETUP template) run in sequence. The sub-agent checks that (a) no existing project files were destructively modified, (b) `agent/*` is populated from the actual codebase (not placeholders), and (c) Stack detection matches `package.json` / `requirements.txt` / `go.mod` / etc.

Both must pass. Exit code `2 = AWAITING_CRITIC` means agent must spawn sub-agent via Task tool, write `critic-result.md`, and re-run.

### Orchestrator (optional ergonomic wrapper)

```bash
bash agent/scripts/psk-existing-setup.sh         # runs preflight + dual gate
```

The orchestrator adds workflow-specific preflight checks before the dual gate. Using it is equivalent to running `psk-validate.sh existing-setup` directly, with extra early-failure protection.
