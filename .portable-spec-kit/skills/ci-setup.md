# Skill: CI/CD Setup
> Loaded when: User says `enable ci`, project setup Step 7.5, or CI-related questions.

---

## CI Status Badge Rule

Every public GitHub repo using the kit should show a CI badge in README.md reflecting the main branch test status. Badge format:
`[![CI](https://github.com/{owner}/{repo}/actions/workflows/ci.yml/badge.svg)](https://github.com/{owner}/{repo}/actions/workflows/ci.yml)`

## Branch Protection Guidance

Enable branch protection on `main` (GitHub Settings → Branches → Add rule). Require status checks to pass before merging — select the CI workflow. Prevents pushes with failing tests reaching main.

## PR Workflow Rule

**PR workflow rule:** When a contributor opens a PR, do not merge until all CI checks are green. Review for portability (any project / any language / any agent?) before merging.

## Contribution Validation Rule

Before merging any PR — from any contributor including yourself — CI must be green. Green CI is the minimum bar; code review is additional, not a substitute.

## ci.yml Template for User Projects

When setting up CI for a project, generate `.github/workflows/ci.yml` using this template. Fill in `{TEST_COMMAND}` and `{SETUP_STEPS}` based on the detected stack from `agent/AGENT.md`. Always include `test-release-check.sh agent/SPECS.md` as the final step — this enforces the R→F→T gate in CI.

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      {SETUP_STEPS}
      - name: Run tests
        run: {TEST_COMMAND}
      - name: R→F→T validator
        run: bash tests/test-release-check.sh agent/SPECS.md
```

## Stack-Aware Test Command Detection

Fill `{TEST_COMMAND}` and `{SETUP_STEPS}` from `agent/AGENT.md` Stack table:

| Stack | `{TEST_COMMAND}` | `{SETUP_STEPS}` |
|-------|-----------------|----------------|
| Node.js + Jest | `npx jest --passWithNoTests` | `uses: actions/setup-node@v4` + `run: npm ci` |
| Node.js + Vitest | `npx vitest run` | same as Jest |
| Node.js + generic | `npm test` | same as Jest |
| Python + pytest | `python -m pytest` | `uses: actions/setup-python@v4` + `run: pip install -r requirements.txt` |
| Go | `go test ./...` | (none) |
| Bash scripts only | (omit Run tests step — test-release-check.sh covers it) | (none) |
| Unknown / not detected | `echo "Configure test command in ci.yml"` + warn user | (none) |

## New Project Setup Step 7.5 — CI Workflow (Config-Aware)

After stack is confirmed (Step 7), check `.portable-spec-kit/config.md` → `CI/CD.Enabled`. If `true` → create `.github/workflows/ci.yml` using the template above, add CI badge to README.md. If `false` (default) → skip CI workflow creation. Tell user: "CI/CD is disabled by default. Enable anytime: say `enable ci`".

## Existing Project CI Setup

During existing project onboarding (scan checklist), include:
`[ ] Enable CI/CD (disabled by default — say `enable ci` when ready)`
Agent fills in the test command from the detected stack. Always includes `bash tests/test-release-check.sh agent/SPECS.md`.

## Existing Project Onboarding — agent/ Commit Check

During existing project scan, if project is team/open-source, check if `agent/` is in `.gitignore`. If yes → suggest: `[ ] Remove agent/ from .gitignore (enables AI-powered onboarding for contributors)`.
