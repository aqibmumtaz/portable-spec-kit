# Flow: Existing Project Setup

> **When:** User installs the spec kit on a project that already has
> code — first-time onboarding, not returning. Agent has never seen
> this codebase before.

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
