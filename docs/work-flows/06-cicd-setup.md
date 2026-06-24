# Flow: CI/CD Setup

> **When:** Agent creates a CI/CD pipeline for a project — during new
> project setup (Step 7.5), existing project onboarding, or when user
> says "add CI" or "set up CI".

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | User says `"add CI"` / `"set up CI"` / `"enable ci"`, or new project setup Step 7.5, or existing project onboarding checklist |
| **Inputs** | `agent/AGENT.md` (Stack table), `.portable-spec-kit/templates/ci/`, `README.md` |
| **Outputs** | `.github/workflows/ci.yml`, updated `README.md` (CI badge added as first badge) |
| **Script** | Template copy: `.portable-spec-kit/templates/ci/ci-{stack}.yml` → `.github/workflows/ci.yml` |
| **Gate** | Pre-push gate (tests must pass before push); CI must be green before merging any PR |
| **When blocked** | Stack undetectable from `agent/AGENT.md`; `.github/` directory inaccessible; user has not confirmed branch protection setup |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: DETECT STACK (automated)                           │
│     Read agent/AGENT.md — Stack table                       │
│     Identify: language, test runner, package manager        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 2: SELECT TEST COMMAND (automated)                    │
│     Node.js + Jest   → npx jest --passWithNoTests           │
│     Node.js + Vitest → npx vitest run                       │
│     Python + pytest  → python -m pytest                     │
│     Go               → go test ./...                        │
│     Unknown          → echo 'Configure test command'        │
│     FAIL → warn user, proceed with generic template         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 3: GENERATE .github/workflows/ci.yml (agent)          │
│     Copy matching template from .portable-spec-kit/         │
│     templates/ci/ci-{stack}.yml                             │
│     Substitute project-specific fields (test cmd, branch)   │
│     Kit gates included: R→F→T + psk-sync-check + bypass-log │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 4: ADD CI BADGE TO README.md (agent)                  │
│     Insert as FIRST badge:                                  │
│     [![CI]({repo}/actions/workflows/ci.yml/badge.svg)]      │
│            ({repo}/actions/workflows/ci.yml)                │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 5: TELL USER: ENABLE BRANCH PROTECTION (agent)        │
│     GitHub Settings → Branches → Add rule                   │
│     Require CI status checks to pass before merging         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 6: VERIFY after first push (config-gated)             │
│     CI badge turns green on GitHub (~2 min)                 │
│     Stack tests pass                                        │
│     R→F→T validator passes (0 done features = OK)           │
└─────────────────────────────────────────────────────────────┘
```

---

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. DETECT STACK                                            │
│     Read agent/AGENT.md — Stack table                       │
│     Identify: language, test runner, package manager        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. SELECT TEST COMMAND (stack-aware)                       │
│     Node.js + Jest      → npx jest --passWithNoTests        │
│     Node.js + Vitest    → npx vitest run                    │
│     Node.js + generic   → npm test                          │
│     Python + pytest     → python -m pytest                  │
│     Go                  → go test ./...                     │
│     Bash scripts only   → (omit Run tests step)             │
│     Unknown             → echo 'Configure test command'     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. GENERATE .github/workflows/ci.yml                       │
│     on: push (main) + pull_request                          │
│     runs-on: ubuntu-latest                                  │
│     steps:                                                  │
│       - actions/checkout@v4                                 │
│       - {SETUP_STEPS} (Node/Python if applicable)           │
│       - run: {TEST_COMMAND}                                 │
│       - run: bash tests/test-release-check.sh agent/SPECS.md│
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. ADD CI BADGE TO README.md                               │
│     Insert as FIRST badge:                                  │
│     [![CI]({repo}/actions/workflows/ci.yml/badge.svg)]      │
│            ({repo}/actions/workflows/ci.yml)                │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  5. TELL USER: ENABLE BRANCH PROTECTION                     │
│     GitHub Settings → Branches → Add rule                   │
│     Require CI status checks to pass before merging         │
│     Prevents pushes with failing tests reaching main        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  6. VERIFY (after first push)                               │
│     CI badge turns green on GitHub (~2 min)                 │
│     Stack tests pass                                        │
│     R→F→T validator passes (0 done features = OK)           │
└─────────────────────────────────────────────────────────────┘
```

## Stack Setup Steps

| Stack | Setup Steps (insert before "Run tests") |
|-------|----------------------------------------|
| Node.js | `uses: actions/setup-node@v4` + `run: npm ci` |
| Python | `uses: actions/setup-python@v4 (python-version: '3.11')` + `run: pip install -r requirements.txt` |
| Go | (none — Go available on ubuntu-latest) |
| Bash only | (none) |
| Unknown | (none — warn user to configure manually) |

## Pre-Push Gate

Before every push — enforced by the agent:

```
┌─────────────────────────────────────────────────────────────┐
│  User: "push"                                               │
│     Was "prepare release" run this session?                 │
│     ├─ Yes, tests passed → push                             │
│     └─ No → run all test suites first                       │
│           ├─ All pass → push                                │
│           └─ Any fail → show failures, block push           │
└─────────────────────────────────────────────────────────────┘
```

## PR / Community Contribution Gate

```
┌─────────────────────────────────────────────────────────────┐
│  PULL REQUEST RECEIVED                                      │
│     ├─ CI checks passing?                                   │
│     │   ├─ YES → review for portability                     │
│     │   │        ├─ Portable → merge                        │
│     │   │        └─ Project-specific → redirect to AGENT.md │
│     │   └─ NO  → do not merge                               │
│     │            ask contributor to fix CI first            │
│     └─ No CI configured → add ci.yml before reviewing       │
└─────────────────────────────────────────────────────────────┘
```

## When This Flow Runs

| Trigger | Source |
|---------|--------|
| New project setup | Step 7.5 — after stack confirmed |
| Existing project onboarding | Checklist item — if ci.yml missing |
| User says "add CI" / "set up CI" / "enable ci" | On demand |

## CI Templates Shipped With the Kit (v0.5.16+)

The kit installs 4 stack-aware GitHub Actions templates at `.portable-spec-kit/templates/ci/`:

| Template | Stack | What it runs |
|----------|-------|--------------|
| `ci-node.yml` | Node / TypeScript | `npm ci` → lint → typecheck → test → R→F→T → sync-check |
| `ci-python.yml` | Python | `pip install` → ruff → mypy → pytest → R→F→T → sync-check |
| `ci-go.yml` | Go | `go build` → `go vet` → `go test -race` → R→F→T → sync-check |
| `ci-generic.yml` | Other / mixed | Kit gates only (add your own test steps separately) |

**Kit gates run in every template** (ensures server-side enforcement matches local PreCommit hook):
- R→F→T gate (`bash tests/test-release-check.sh agent/SPECS.md`)
- `psk-sync-check.sh --full` — 52 structural checks (PSK001-PSK050) including PSK011 secret scanning (blocks commits of real credentials)
- Bypass-log detector — fails CI if `agent/.bypass-log` is present (any local `PSK_*_DISABLED=1` or `--no-verify` bypass would surface here)

## Installation — agent copies the right template

On `"enable ci"`, the agent:
1. Detects stack from `agent/AGENT.md` Stack table
2. Copies matching template from `.portable-spec-kit/templates/ci/ci-{stack}.yml` → `.github/workflows/ci.yml`
3. Substitutes project-specific fields (test command, branch name)
4. Adds CI badge to README.md

## Files Created
- `.github/workflows/ci.yml` — copied from template matching your stack; runs on every push + PR
- `README.md` — CI badge added as first badge

---

## Key Rules

- **Stack detection is mandatory before template copy.** Agent reads `agent/AGENT.md` Stack table first — never hardcode a stack in the CI file.
- **CI badge is always the first badge in README.md.** Insert before version, test, and license badges so CI status is immediately visible.
- **Kit gates run in every CI template.** R→F→T gate, `psk-sync-check.sh --full`, and bypass-log detector are non-negotiable — they mirror local PreCommit hook enforcement on the server.
- **Branch protection must be enabled separately.** CI alone does not block merges — the user must configure GitHub branch protection rules to require CI to pass.
- **Pre-push gate applies on every push.** If tests have not been run this session, the agent runs the full test suite before pushing — never push without a green signal.
- **CI disabled in config → skip silently.** Config gate: `CI/CD.enabled` in `.portable-spec-kit/config.md`. If disabled, do not create `ci.yml` or badge; remind user how to enable (`"enable ci"`).
