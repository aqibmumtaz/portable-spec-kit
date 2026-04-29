# Flow: CI/CD Setup

> **When:** Agent creates a CI/CD pipeline for a project — during new
> project setup (Step 7.5), existing project onboarding, or when user
> says "add CI" or "set up CI".

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
- `psk-sync-check.sh --full` — 15 structural checks including PSK011 secret scanning (blocks commits of real credentials)
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
