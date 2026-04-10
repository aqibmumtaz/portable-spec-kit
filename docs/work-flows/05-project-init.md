# Flow: Project Init & Reinit

> **When:** User says "init" or "reinit". Agent runs the
> appropriate scan flow — never auto-triggers either command.

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────┐
│  User says "init" or "reinit"                               │
│     Agent checks current kit status                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
          ┌────────────▼────────────┐
          │  "init"                 │
          │  New / Partial / Mapped │
          └────────────┬────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Confirm project directory                                  │
│     List dirs → ask user to confirm (Enter = current)       │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Deep scan                                                  │
│     Read config files: package.json, requirements.txt,      │
│       pyproject.toml, Dockerfile, tsconfig.json, go.mod,    │
│       Cargo.toml, build.gradle, pubspec.yaml, README.md     │
│     Read top-level dirs + sample src/ files                 │
│     Build complete picture before touching anything         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Create / update agent/ files                               │
│     Create agent/ dir + all 6 files if missing              │
│     Fill every field from scan — never leave TBD            │
│     Create README.md, .gitignore, .env.example if missing   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Present optional changes checklist                         │
│     Scan complete. Detected: <stack> · Port <X>             │
│                                                             │
│     [x] agent/ — 6 files created/updated (from scan)        │
│     [ ] .github/workflows/ci.yml  — CI on push/PR           │
│     [ ] .env.example              — env var template        │
│     [ ] README.md                 — restructure to template │
│                                                             │
│     Which optional changes? (all / none / list numbers)     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Apply selected changes → show init summary                 │
│     ✅ Init complete — <project-name>                       │
│     Stack:  <detected>                                      │
│     Files:  X created · Y updated                           │
│     Status: ✅ Mapped                                       │
└─────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────┐
│  User says "reinit"                                         │
│     Already Mapped — re-scan to sync stale agent files      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Read baseline                                              │
│     agent/AGENT.md + agent/AGENT_CONTEXT.md as-is           │
│     Announce: "Re-scanning — syncing agent files..."        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Deep scan (same scope as init)                             │
│     Source files, config files, directory structure         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Update AGENT.md                                            │
│     Update only fields that changed — stack versions,       │
│     new tools, port, conda env. Note what changed.          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Rebuild AGENT_CONTEXT.md from current codebase             │
│     Phase    — inferred from TASKS.md + codebase state      │
│     Done     — [x] tasks + visible completed code           │
│     Next     — [ ] tasks                                    │
│     Blockers — TODO/FIXME in source, missing deps           │
│     Structure — current directory tree                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  SPECS.md staleness check                                   │
│     Count [x] tasks in TASKS.md vs features in SPECS.md     │
│     If completed tasks missing from SPECS:                  │
│       "3 completed tasks not in SPECS.md — add? (y/n)"      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  PLANS.md vs code check                                     │
│     If architecture in code differs from PLANS.md:          │
│       "PLANS.md may be stale — <field> shows <X> in code    │
│        but <Y> in PLANS. Update? (y/n)"                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Show reinit summary                                        │
│     ✅ Reinit complete — <project-name>                     │
│     AGENT.md:      <fields updated / no changes>            │
│     AGENT_CONTEXT: rebuilt — phase: <X> · <Y> pending       │
│     SPECS.md:      <N stale features> / current ✅          │
│     PLANS.md:      <stale fields flagged> / current ✅      │
└─────────────────────────────────────────────────────────────┘
```

## Trigger Signals

| Signal | What it does |
|--------|-------------|
| `init` | Full project scan — New, Partial, or Mapped. Creates agent/ files, presents optional changes checklist |
| `reinit` | Re-scan only — assumes already Mapped. Syncs stale agent files, checks SPECS/PLANS, reports delta |

**Agent never auto-triggers either command.** Wait for explicit user signal.

## init vs reinit

| | `init` | `reinit` |
|-|--------|---------|
| When | First setup, or force re-initialize | Agent files are stale after code changes |
| Creates missing files | Yes | No — only updates existing files |
| Optional changes checklist | Yes | No |
| SPECS/PLANS staleness check | No | Yes |
| Shows delta of what changed | No | Yes |
| Works on already-Mapped project | Yes (warns, then proceeds) | Yes (primary use case) |

## Edge Cases

| Condition | Behaviour |
|-----------|-----------|
| `init` on already-Mapped project | Show "already initialized (vX.X.X) — running re-scan to refresh" then proceed |
| No recognizable stack | Ask: "What stack is this project using?" before continuing scan |
| Monorepo (multiple stacks) | Ask which subdirectory to init first — handle each separately |
| Very large project (100+ files) | Scan config files + top-level dirs + sample src/ — don't read every file |
| `.env` present during scan | Read variable names only — never read or expose values |
| `reinit` on New/Partial project | Redirect: "agent/ files not fully set up — run `init` instead" |
| AGENT.md already accurate | Note "no changes needed" in summary — never overwrite accurate content |
| SPECS.md empty after 3+ [x] tasks | Flag in reinit: "SPECS.md is empty but TASKS.md has X completed tasks — fill it? (y/n)" |
