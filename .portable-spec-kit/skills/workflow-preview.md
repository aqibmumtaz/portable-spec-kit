<!-- TEMPLATE-KIND: skill · GENERICITY: passing · LAST-AUDITED: 2026-05-19 -->

# Skill — Workflow Preview

Operational guide for inspecting any kit workflow or executable plan via `agent/scripts/psk-preview.sh`. Complements the conceptual [flow doc 29](../../docs/work-flows/29-unified-workflow-declarations.md) and the schema sibling [flow doc 26](../../docs/work-flows/26-plan-execution-protocol.md).

> **Loaded when:** the user says "preview workflow", "preview plan", "psk-preview", "show phases of <workflow>", asks how a workflow will run before running it, asks what phases a plan has, wants to render a dependency graph for any workflow, or wants to emit JSON about a workflow declaration for tooling.

> **Cross-links:** §Workflow Declaration Schema in `portable-spec-kit.md` (7th reliability layer) · §Plan Execution Protocol (5th reliability layer) · `.portable-spec-kit/skills/plan-execution.md` (companion skill for the plan side of the same schema family).

---

## When to use this skill

- Operator wants to see what a workflow will do **before** invoking it (cost / time forecasting, dependency review, gate inspection).
- An agent is about to run a workflow and wants to confirm the declared phases match expectation (the workflow may have been retrofitted between sessions).
- Someone is drilling into one phase to understand its prompt, gate, or artifact spec without reading the full declaration.
- CI / tooling needs a JSON representation of a workflow or plan declaration.
- The user types `/preview` or any phrase containing "preview workflow", "preview plan", or asks about the phases / structure of any declaration under `.portable-spec-kit/workflows/` or `agent/plans/`.

---

## The CLI surface (3 sentences)

`psk-preview.sh` is a universal inspector — same tool for both workflow declarations (`.portable-spec-kit/workflows/<name>/phases.yml`) and executable plans (`agent/plans/<slug>.md`). It reads the declaration, validates the schema, and renders the phases either as a human-readable preview, a dependency graph, or JSON for tooling. Zero side effects — invoking the preview never modifies state, never dispatches sub-agents, never advances workflows.

---

## Subcommand reference

| Command | Purpose | Output |
|---|---|---|
| `psk-preview.sh <workflow>` | Render full preview for a workflow declaration | Human-readable; includes description, phases, dependency graph, per-phase gates and prompt paths |
| `psk-preview.sh plan <slug>` | Render preview for an executable plan (Flow 26 schema) | Human-readable; same shape as workflow preview |
| `psk-preview.sh <target> --phase <id>` | Drill into one phase only | Phase-only view — goal, prompt, artifact, gate, deps |
| `psk-preview.sh <target> --graph` | Render dependency graph | ASCII DAG showing depends_on edges |
| `psk-preview.sh <target> --json` | Emit JSON for tooling | Machine-readable; same data, structured |
| `psk-preview.sh --list-workflows` | List discovered workflows | One workflow id per line |
| `psk-preview.sh --list-plans` | List executable plans | slug · status · phase-count |
| `psk-preview.sh --help` / `-h` | Print usage summary | Stdout |

**Exit codes**

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | User error — bad CLI args (unknown subcommand, missing required arg) |
| `2` | Data error — declaration file missing or malformed |

---

## Examples

### Inspect the release workflow

```bash
$ bash agent/scripts/psk-preview.sh release
schema_version: 1
workflow: release
description: 10-step release ceremony — tests, code review, scope check,
             flow docs, counts, version bump, PDFs, RELEASES, CHANGELOG,
             validation (dual critic). No commit, no push.

phases (10):
  step-1-tests              [mechanical]   gate: bash tests/test-spec-kit.sh && bash tests/test-release-check.sh
  step-2-code-review        [mechanical]   gate: bash agent/scripts/psk-code-review.sh
  step-3-scope-check        [mechanical]   gate: bash agent/scripts/psk-scope-check.sh
  step-4-flow-docs          [sub-agent]    prompt: .portable-spec-kit/workflows/release/phases/step-4-flow-docs.md
  ...
  step-9-validation         [sub-agent]    gate: bash agent/scripts/psk-validate.sh release
  step-10-summary           [mechanical]   gate: test -f agent/.release-state/summary.md
```

### Render the autoloop dependency graph

```bash
$ bash agent/scripts/psk-preview.sh reflex-autoloop --graph
reflex-autoloop dependency DAG:

   precheck → prep-release → qa-pass → dev-pass → gates → verdict-write → iterate
                                                                            ↓
                                                                      converge-check
                                                                            ↓
                                                                       (loop or stop)
```

### Drill into one phase

```bash
$ bash agent/scripts/psk-preview.sh release --phase step-9-validation
phase: step-9-validation
  name: Step 9 — Validation (dual critic)
  goal: Run bash + sub-agent critics; pass both before marking release complete.
  spawn_type: sub-agent
  prompt: .portable-spec-kit/workflows/release/phases/step-9-validation.md
  artifact: agent/.workflow-artifacts/release/step-9-validation.done.md
  gate: bash agent/scripts/psk-validate.sh release
  depends_on: [step-1-tests, step-2-code-review, step-3-scope-check, step-4-flow-docs,
               step-5-counts, step-6-version-bump, step-7-pdfs, step-8-changelog]
  commit_required: true
```

### Preview an executable plan

```bash
$ bash agent/scripts/psk-preview.sh plan unified-workflow-declarations
slug: unified-workflow-declarations
status: executing
schema_version: 1
phases (10):
  A1                       [done]         workflow-router taxonomy
  A2                       [done]         build phases.yml authoring tooling
  ...
  A9                       [executing]    docs (this very phase)
  A10                      [pending]      v0.6.62 release ceremony
```

### Emit JSON for tooling

```bash
$ bash agent/scripts/psk-preview.sh feature-complete --json
{
  "schema_version": 1,
  "workflow": "feature-complete",
  "phases": [
    {
      "id": "...",
      "name": "...",
      "spawn_type": "...",
      ...
    }
  ]
}
```

### List everything

```bash
$ bash agent/scripts/psk-preview.sh --list-workflows
existing-setup
feature-complete
init
new-setup
orchestrate
reflex-autoloop
reflex-single-pass
release

$ bash agent/scripts/psk-preview.sh --list-plans
unified-workflow-declarations  executing  10
workflow-fidelity              done       7
plan-execution-protocol        done       8
```

---

## Common use cases

### "How will the release ceremony run?"

Operator wants forecast before invoking `prepare release`. Run `psk-preview.sh release` — see all 10 steps, their gates, which need sub-agents, which are mechanical. No state change.

### "Why is the autoloop spawning sub-agents twice for one cycle?"

Render the DAG with `--graph`. Verify whether qa-pass and dev-pass are sequential (expected) or parallel (would be a regression). The graph makes spawn-count visible at a glance.

### "What does step-9-validation actually do?"

Drill with `--phase step-9-validation`. The phase view shows the prompt path — open that file to see the canonical 5-section brief the sub-agent receives. No hunting through script bodies.

### "I need to wire psk-preview output into our CI dashboard."

`--json` emits machine-readable output. Pipe into `jq`, parse the phases array, render workflow status in CI. Same JSON shape for workflows and plans.

### "Is this plan even runnable?"

`psk-preview.sh plan <slug>` parses the plan's frontmatter, runs schema validation (same checks as `psk-run-plan.sh --validate`), and shows the phase array. If the plan is malformed, exit code 2 with a specific error pointing to the broken field.

---

## Triggers that load this skill

| User says | Skill action |
|---|---|
| `"preview workflow"` / `"preview <workflow-name>"` | Run `psk-preview.sh <workflow>` and explain output |
| `"preview plan"` / `"preview plan <slug>"` | Run `psk-preview.sh plan <slug>` and explain output |
| `"show me the phases of release"` (or any workflow) | Run `psk-preview.sh <workflow>` |
| `"render the dependency graph"` / `"show DAG"` | Run with `--graph` |
| `"list all workflows"` / `"what workflows exist"` | `psk-preview.sh --list-workflows` |
| `"list all plans"` / `"what plans are running"` | `psk-preview.sh --list-plans` |
| `"emit JSON for <workflow>"` / `"machine-readable preview"` | Run with `--json` |
| `"what does phase X do"` | Drill with `--phase <id>` |
| `/preview` slash-command | Show usage summary; ask for target workflow or plan |

---

## Limits

- **Read-only.** `psk-preview.sh` never modifies declarations, never dispatches sub-agents, never advances workflow state. Side-effect-free by design — render-only.
- **Schema-bound.** The tool only renders declarations that conform to `schema_version: 1`. Legacy workflows or plans without `phases:` frontmatter render as `[no declaration found]` with the path to the canonical location.
- **No cost estimation aggregation across phases.** Per-phase `estimated_tokens` and `estimated_wall_clock_min` render in the preview but the tool does not sum or chart them — that is a downstream tooling concern (use `--json` and pipe through your own aggregator).
- **Workflow autodiscovery is path-based.** The tool finds workflows by walking `.portable-spec-kit/workflows/*/phases.yml`. Workflows declared elsewhere (custom paths, project-local overrides) are not discovered automatically — pass the path explicitly via `--from <path>`.
- **Plan autodiscovery walks `agent/plans/*.md`.** Dated and undated variants both supported. Nested plan directories (e.g. `agent/plans/<slug>/prompts/`) are NOT treated as separate plans — only the top-level `.md` files are.

---

## Lifecycle states (the preview tool's own state)

The tool itself is stateless — every invocation reads the declaration fresh. The states below describe what the preview reports about the *target* workflow or plan, not the tool.

| Reported state | Source | Meaning |
|---|---|---|
| `phase: pending` | Workflow state ledger | Phase declared but not yet started |
| `phase: AWAITING:SUBAGENT_SPAWN` | Workflow state ledger | Phase paused waiting for sub-agent dispatch |
| `phase: AWAITING:SUBAGENT_RETRY` | Workflow state ledger | Sub-agent failed; retry queued |
| `phase: in_progress` | Workflow state ledger | Gate evaluation in flight |
| `phase: done` | Workflow state ledger + GATE_PASSED_<id> marker | Gate exited 0; phase complete |
| `phase: gate-failed` | Workflow state ledger | Gate exited non-zero; operator must fix or retry |
| `phase: AWAITING_HUMAN_ARBITRATION` | Workflow state ledger | 3 retries exhausted; operator decision required |
| `plan: draft / approved / executing / done / abandoned` | Plan frontmatter `status:` | Plan lifecycle state per §Plan Execution Protocol |

---

## Common mistakes

| Anti-pattern | Why it fails | Right thing |
|---|---|---|
| Running the workflow to find out what it does | Wastes a full execution to inspect | Run `psk-preview.sh <workflow>` first; zero cost |
| Editing `phases.yml` by hand and not previewing | Schema drift surfaces only at next dispatch | Run `psk-preview.sh <workflow>` after every edit; PSK035 also lints in `--full` mode |
| Drilling into a phase by opening the script | Phase is in the declaration, not the script body | `psk-preview.sh <workflow> --phase <id>` shows the real source |
| Using `psk-preview.sh` to advance a phase | Tool is read-only | Use `psk-run-plan.sh next` (plans) or the workflow's own dispatch script |
| Parsing the human-readable output for tooling | Format may change | Use `--json` for stable machine-readable output |

---

## Quick reference

```bash
# Universal inspector
psk-preview.sh release                       # full preview
psk-preview.sh reflex-autoloop --graph       # dependency DAG
psk-preview.sh feature-complete --json       # machine-readable
psk-preview.sh release --phase step-9-validation   # one phase

# Plan side (Flow 26 schema, same tool)
psk-preview.sh plan unified-workflow-declarations

# Discovery
psk-preview.sh --list-workflows
psk-preview.sh --list-plans
psk-preview.sh --help
```

---

## Cross-references

- Flow doc: [`docs/work-flows/29-unified-workflow-declarations.md`](../../docs/work-flows/29-unified-workflow-declarations.md)
- Schema sibling: [`docs/work-flows/26-plan-execution-protocol.md`](../../docs/work-flows/26-plan-execution-protocol.md)
- Framework rule: `portable-spec-kit.md` §Workflow Declaration Schema (7th reliability layer)
- Companion skill (plan side): [`plan-execution.md`](plan-execution.md)
- Spawn protocol (every sub-agent phase routes through it): [`spawn-fidelity.md`](spawn-fidelity.md)
- Source: `agent/scripts/psk-preview.sh`
- Sync-check rules: PSK034 (workflow-router → phases.yml) · PSK035 (schema + Quality Bar) in `agent/scripts/psk-sync-check.sh`

## Dispatcher Integration

`psk-dispatch.sh` reads the same `phases.yml` data at execution time — preview and dispatch share a single declaration file as their source of truth.
