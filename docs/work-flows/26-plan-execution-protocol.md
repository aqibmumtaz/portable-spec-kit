# Flow 26 — Plan Execution Protocol

Every plan that will be executed via sub-agent spawning conforms to the kit's executable-plan schema. The driver reads the schema, emits a SPAWN signal per phase, pauses on each phase, runs the phase's completion gate, and advances only when the gate passes. There is no path where the agent reads a free-form plan and improvises its execution — the driver refuses, the schema validator refuses, the gate fails.

> **Why this exists:** workflow-fidelity (Flow 25) makes the agent execute *workflows* faithfully — the orchestrator, release, init, reflex. But plans drafted in chat (`/plan`, plan-mode, "draft a plan to do X") sit one level above workflows: they are *user-authored multi-phase work units* the agent then drives. Without a schema, "plan-driven" devolves into "the agent reads the plan and does what it thinks the plan said" — the same failure mode workflow-fidelity exists to prevent, one level up. This flow makes plan execution as faithful as workflow execution.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | `bash agent/scripts/psk-run-plan.sh start <slug>` after the plan has been approved via `psk-plan-save.sh approve <slug>` |
| **Inputs** | An executable plan at `agent/plans/<slug>.md` (or dated form `agent/plans/YYYY-MM-DD-<slug>.md`) with `phases:` frontmatter conforming to `schema_version: 1`; per-phase prompt files at `agent/plans/<slug>/prompts/<id>.md`; per-phase artifact files filled by sub-agents at `agent/plans/<slug>/artifacts/<id>.done.md` |
| **Outputs** | One commit per `commit_required: true` phase; one artifact file per phase; the plan's lifecycle moves draft → approved → executing → done; the workflow state file at `agent/.workflow-state/run-plan-<slug>.state` records exact per-phase progress |
| **Scripts** | `agent/scripts/psk-run-plan.sh` (driver) · `agent/scripts/psk-plan-save.sh` (schema-gated lifecycle) · `agent/scripts/psk-workflow-state.sh` (shared resumable phase state machine, see Flow 25) · `agent/scripts/psk-sync-check.sh` (PSK024 lint) |
| **Gate** | Three structural layers — (a) `approve` validates schema and refuses approval on malformed `phases:`; (b) `start` refuses execution on non-conformant plans (one-shot `compat_mode: true` exception); (c) PSK024 sync-check fires in PostToolUse + PreCommit hooks |
| **When blocked** | Rate limit / context compact / sub-agent failure → `AWAITING_SUBAGENT_RETRY` state; after 3 retries → `AWAITING_HUMAN_ARBITRATION`. Resume re-enters at the exact in-progress phase. Never restart, never skip, never improvise. |
| **Bypass** | `PSK_PLAN_EXEC_DISABLED=1` disables schema validation in `approve`, the `start` refusal, and PSK024 — emergency only. |

---

## Key Rules

- Every executable plan MUST conform to `schema_version: 1` + `phases:` frontmatter (see `.portable-spec-kit/templates/plan-executable.md`). Legacy plans run once under `compat_mode: true`, then MUST convert before next `start`.
- `psk-plan-save.sh save` MUST preserve the markdown body byte-for-byte. `approve` runs schema validation (PSK024 codes N/P/F/D/L) and refuses non-conformant plans.
- `psk-run-plan.sh start` refuses to execute plans missing `phases:` (or without `compat_mode: true`). The driver has **no inline-fallback branch** — the only forward paths are spawn, retry, or abort.
- Each phase produces one commit (when `commit_required: true`) and one artifact file at `agent/plans/<slug>/artifacts/<id>.done.md`. Orchestrator never edits artifacts post-commit.
- Phase completion gate (`gate:` command) MUST exit 0 before the phase advances. Three retries on gate failure → AWAITING_HUMAN_ARBITRATION.
- `depends_on:` declares phase ordering. A phase becomes actionable only when all its dependencies are `done`. Cycles caught by PSK024-D at sync-check; runtime defends in `_next_actionable_phase`.
- PostToolUse hook fires `psk-sync-check.sh --quick` after every Write/Edit to a plan file; pre-commit hook fires `--full`. Schema drift surfaces immediately, not at execution time.
- Bypass: `PSK_PLAN_EXEC_DISABLED=1` — explicit, per-invocation, removes a structural guarantee.

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Agent drafts plan in conversation                        │
│    Save iteratively via psk-plan-save.sh save <slug>        │
│    status: draft (body preserved byte-for-byte each save)   │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 2. psk-plan-save.sh approve <slug> — SCHEMA GATE (PSK024)   │
│    missing phases / required field → exit 2, stays draft    │
│    schema valid → status: approved                          │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 3. psk-run-plan.sh start <slug> — DRIVER REFUSAL GATE       │
│    non-conformant + no compat_mode → exit 2, no execution   │
│    conformant → init state machine, register per-phase gates│
│    status: executing                                        │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 4. Per phase (depends_on satisfied):                        │
│    a. resolve next actionable phase (deps all done)         │
│    b. emit SPAWN signal — prompt path + artifact + gate     │
│    c. driver pauses (no inline-fallback branch)             │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 5. Main agent reads prompt → Task-tool sub-agent spawn      │
│    Sub-agent does work → commits (if commit_required) →     │
│    writes artifact .done.md → returns to orchestrator       │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 6. psk-run-plan.sh next                                     │
│    artifact missing → exit 1, retry / abort                 │
│    gate FAIL → exit 3, retry / fix artifact                 │
│    gate PASS → mark-done, reset retry, resolve next phase   │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 7. Rate-limit / sub-agent failure                           │
│    psk-run-plan.sh retry → AWAITING_SUBAGENT_RETRY → respawn│
│    After 3 retries → AWAITING_HUMAN_ARBITRATION (exit 4)    │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 8. All phases done → status: done                           │
│    psk-plan-save.sh done <slug> <sha-range> closes plan     │
│    State machine archived; artifacts kept for audit/replay  │
└─────────────────────────────────────────────────────────────┘
```

## The Schema

Every executable plan carries the following frontmatter. `schema_version: 1` is mandatory so the schema can evolve without ambiguity.

```yaml
---
status: draft | approved | executing | done | abandoned
slug: <kebab-case>
created: YYYY-MM-DD
updated: YYYY-MM-DD
schema_version: 1
phases:
  - id: A1
    name: "Short phase title"
    prompt: "agent/plans/<slug>/prompts/A1.md"
    artifact: "agent/plans/<slug>/artifacts/A1.done.md"
    gate: "bash agent/scripts/psk-sync-check.sh --full"
    commit_required: true
    depends_on: []
  - id: A2
    name: "Next phase"
    prompt: "agent/plans/<slug>/prompts/A2.md"
    artifact: "agent/plans/<slug>/artifacts/A2.done.md"
    gate: "bash tests/test-spec-kit.sh"
    commit_required: true
    depends_on: [A1]
revision: N
---
```

| Field | Required | Meaning |
|---|---|---|
| `status` | yes | Lifecycle marker — `draft | approved | executing | done | abandoned`. Driven by `psk-plan-save.sh`. |
| `slug` | yes | Kebab-case identifier; uniquely names the plan; also names the prompts/artifacts subdirectories. |
| `created` / `updated` | yes | ISO dates. `updated` is refreshed on every `save` / `approve` / `start` / `done`. |
| `schema_version` | yes | Integer. Currently `1`. PSK024-V fails if absent or non-integer. |
| `phases` | yes (unless `compat_mode: true`) | Ordered array of phase records. PSK024-P fails if absent or empty. |
| `phases[].id` | yes | Phase identifier — kebab/alphanumeric, unique within the plan. Used in state file as `PHASE_<id>=...`. |
| `phases[].name` | yes | Short human-readable title. PSK024-N fails if absent. |
| `phases[].prompt` | yes | Path to per-phase prompt file. Canonical layout: `agent/plans/<slug>/prompts/<id>.md`. PSK024-R fails on missing or off-layout. |
| `phases[].artifact` | yes | Path to per-phase artifact file. Canonical layout: `agent/plans/<slug>/artifacts/<id>.done.md`. PSK024-A fails on missing or off-layout. |
| `phases[].gate` | yes | Shell command that must exit 0 for the phase to be marked done. PSK024-G fails if absent. |
| `phases[].commit_required` | yes | Boolean. PSK024-C fails if absent or non-boolean. When `true`, the phase artifact must record a non-empty `commit_sha:`. |
| `phases[].depends_on` | yes (may be `[]`) | Array of phase ids that must reach `done` before this phase becomes actionable. PSK024-D fails on dangling references or cycles. |
| `revision` | optional | Monotonic integer. Useful when a plan is rewritten mid-execution; revision change is recorded in `revision_history`. |
| `compat_mode` | optional | Boolean. When `true` and `phases:` is absent, the driver runs the plan once as a single synthetic phase; the next `start` requires conversion (see Compat-mode below). |

The narrative body of the plan (Context, Goal, Approach, Decisions, Files, Phases narrative, Risk, Rollback, State, Acceptance) is independent of the frontmatter contract — humans read the body, the driver reads the frontmatter. Both must agree, but only the frontmatter is machine-enforced.

---

## Command Surface

Every subcommand of `bash agent/scripts/psk-run-plan.sh` and the expected output shape.

### `start <slug>`

Validates schema, initializes the workflow state machine, registers per-phase gates, emits SPAWN for the first actionable phase.

```bash
$ bash agent/scripts/psk-run-plan.sh start workflow-fidelity
SPAWN: phase=A1 prompt=agent/plans/workflow-fidelity/prompts/A1.md \
       artifact=agent/plans/workflow-fidelity/artifacts/A1.done.md \
       gate=bash agent/scripts/psk-sync-check.sh --full

  AWAITING_SUBAGENT — plan 'workflow-fidelity' paused at phase 'A1'

  MAIN AGENT PROTOCOL (mandatory — no inline alternative):
  1. Read prompt: agent/plans/workflow-fidelity/prompts/A1.md
  2. Spawn sub-agent (Task tool) with that exact prompt
  3. Sub-agent writes its artifact to: agent/plans/workflow-fidelity/artifacts/A1.done.md
  4. Then call: psk-run-plan.sh next
  5. On sub-agent failure / rate-limit: psk-run-plan.sh retry
```

Refuses on schema failure (`exit 2`) or if the plan is already executing (`exit 1`).

### `next [<slug>]`

Verifies the artifact for the current phase exists and is non-empty, runs the phase's registered gate, advances to the next actionable phase. With no slug and only one in-flight plan, slug is auto-resolved; with multiple in-flight plans, slug is mandatory.

```bash
$ bash agent/scripts/psk-run-plan.sh next
SPAWN: phase=A2 prompt=... artifact=... gate=...
  AWAITING_SUBAGENT — plan 'workflow-fidelity' paused at phase 'A2'
```

Exit codes: `0` on advance or COMPLETE; `1` artifact missing; `3` gate failed; `2` schema or usage error.

### `status [<slug>]`

With a slug, prints the per-plan run-state + workflow-state. Without a slug, lists all in-flight plans one per line.

### `resume <slug>`

Re-emits the SPAWN signal for the current in-progress phase. Used after a context compact, a machine switch, or any external interruption that did not change the state file. Idempotent.

### `retry [<slug>]`

Increments the retry counter for the current phase and re-emits SPAWN. After 3 retries on the same phase, exits `4` (AWAITING_HUMAN_ARBITRATION) — the only forward path is operator intervention or `abort`.

### `--convert <slug>`

Emits a single SPAWN with a conversion prompt that tells a sub-agent to convert a legacy (compat-mode) plan to schema-conformant form. The gate command for the conversion phase is `bash agent/scripts/psk-run-plan.sh --validate <slug>` — conversion is itself executed as a sub-agent phase, with its own artifact and validation gate.

### `--validate <slug>`

One-shot schema validation. No side effects, no state change. Exits `0` on valid schema, `2` on schema violation.

### `--health`

One-liner across all in-flight plans — useful in scripts, CI, or as a quick sanity check.

```bash
$ bash agent/scripts/psk-run-plan.sh --health
  workflow-fidelity              phase=B0.6         status=AWAITING:SUBAGENT_SPAWN  retries=0
psk-run-plan: 1 in-flight (1 awaiting subagent, 0 with retries, 0 running)
```

### `abort <slug>`

Marks the workflow aborted, moves state aside for forensics (`*.aborted.<epoch>`), removes the gate file, and calls `psk-plan-save.sh abandon <slug>` to flip the plan's lifecycle. Artifacts already on disk are kept — only the live execution state is torn down.

---

## Lifecycle States

### Plan-level (frontmatter `status:`)

| State | Entered by | Exit |
|---|---|---|
| `draft` | `psk-plan-save.sh save <slug>` | `approve` (schema gate passes) → `approved` |
| `approved` | `psk-plan-save.sh approve <slug>` | `start` → `executing` |
| `executing` | `psk-run-plan.sh start <slug>` (calls `psk-plan-save.sh start <slug>` internally) | All phases done → `done`; `abort` → `abandoned` |
| `done` | Driver advances past final phase, calls `psk-plan-save.sh done <slug>` | terminal |
| `abandoned` | `psk-run-plan.sh abort <slug>` or manual `psk-plan-save.sh abandon <slug>` | terminal (re-approval is a new revision) |

### Phase-level (workflow state machine `PHASE_<id>=...` in state file)

| State | Entered by | Exit |
|---|---|---|
| `pending` | `init` registers the phase | `mark-awaiting` → AWAITING |
| `AWAITING:SUBAGENT_SPAWN` | First entry into the phase | Sub-agent returns + artifact present + gate passes → `done` |
| `AWAITING:SUBAGENT_RETRY` | `retry` after a sub-agent failure | Same exit as SPAWN; after 3 retries → AWAITING_HUMAN_ARBITRATION |
| `in_progress` | Set by the state machine while the gate is being evaluated | Gate result determines next state |
| `done` | Gate exited `0` after artifact verified | Driver resolves next actionable phase |
| `gate-failed` (transient) | Gate exited non-zero | Driver exits `3`; operator fixes artifact or gate and re-runs `next` |
| `AWAITING_HUMAN_ARBITRATION` | Retry counter exceeds `RETRY_CAP=3` | Operator decision required — abort, redraft, or `PSK_PLAN_EXEC_DISABLED=1` bypass |

---

## Gate Semantics

Each phase declares a `gate:` shell command. The state machine treats the gate as the only definition of "phase complete" — the sub-agent does not declare a phase done, the gate does.

**Invocation.** `next` calls the state machine's `mark-done <workflow> <phase>` which re-runs the registered gate. If the gate exits `0`, the phase moves to `done` and the retry counter resets. If the gate exits non-zero, the phase stays `in_progress` and `next` exits `3`.

**Gate shape.** Any shell command. Common shapes:

| Gate command | When to use |
|---|---|
| `test -f agent/plans/<slug>/artifacts/<id>.done.md` | Default minimum — just check the artifact exists. Suitable for narrative or documentation phases. |
| `bash agent/scripts/psk-sync-check.sh --full` | Validation phases that must leave the kit's structural invariants clean. |
| `bash tests/test-spec-kit.sh && bash tests/test-release-check.sh agent/SPECS.md` | Test-running phases — every relevant suite must pass before advancing. |
| `grep -q "feature_flag_x:" .portable-spec-kit/config.md` | Surgical phases — check the exact change is present without running the world. |
| `bash scripts/build.sh && test -f dist/output.tar.gz` | Build phases — gate on a build script plus an output artifact presence. |

**Retry behavior.** A gate failure does not increment the retry counter — retries are for sub-agent failures (rate-limit, crash, missing artifact). When the gate fails, the artifact exists but does not satisfy the assertion; the operator inspects, fixes the artifact (or the gate definition itself), and re-runs `next`. The retry counter only advances on `psk-run-plan.sh retry` invocations.

**Three retries then arbitration.** After 3 retries on the same phase, the driver refuses to spawn again. The intent is to surface persistent failure modes — usually a prompt that is unclear, a gate that is stricter than the phase scope, or a dependency outside the kit's reach. Resolution requires operator inspection, not another retry.

---

## Dependency Resolution

Each phase declares `depends_on: [<id>, ...]`. A phase is **actionable** when:

1. Its state is `pending` (or `AWAITING_SUBAGENT_*` for the current phase)
2. Every id in `depends_on` has reached state `done`

The driver's `_next_actionable_phase` walks the parsed phases in declaration order and returns the first that satisfies both predicates. Ties are broken by declaration order — there is no parallel execution today; phases that *could* run in parallel run sequentially in id-sort order.

**Cycle detection.** PSK024-D in the sync-check runs a depth-first walk over the dependency graph and emits an error on any back-edge. Cycles make a plan structurally non-executable — the driver would never find an actionable phase and would exit with "no actionable phase found — schema may be malformed (cyclic depends_on?)".

**Dangling references.** Any `depends_on` id that is not a declared phase id is flagged by PSK024-D with the message `phase '<X>' depends_on '<Y>' which is not a declared phase id`. Typos surface at lint time, not at runtime.

---

## Compat-mode + Conversion

Plans authored before the schema (or plans intentionally drafted as narrative) execute once under `compat_mode: true`. The driver derives a single synthetic phase, hands the entire plan body to a sub-agent as the prompt, and writes the artifact to `agent/.workflow-state/run-plan-<slug>.compat.done.md`.

**When triggered.** Frontmatter declares `compat_mode: true` and lacks a `phases:` array.

**Single one-shot run.** The compat-mode phase id is the literal string `compat`. Gate is `test -f <artifact>` — minimum acceptable. The sub-agent does whatever the plan body asks, returns, and `next` advances the plan to COMPLETE.

**Conversion required for the next run.** On COMPLETE, the driver emits:

```text
COMPLETE — compat-mode plan '<slug>' executed (one-shot).
  Next start of this plan requires conversion: psk-run-plan.sh --convert <slug>
```

**Conversion as a sub-agent task.** `--convert <slug>` writes a conversion prompt to `agent/.workflow-state/run-plan-<slug>.convert.prompt.md` and emits a SPAWN. The sub-agent reads the legacy plan, infers phases from the `## Implementation Order` (or `## Phases` narrative section), writes the `phases:` frontmatter, scaffolds per-phase prompt and artifact files, and commits. The conversion gate is `bash psk-run-plan.sh --validate <slug>` — the conversion phase only marks done when the resulting plan passes schema validation.

**Net effect.** Every plan eventually converges on the schema. No plan stays in compat mode forever — the next `start` after a compat run refuses without conversion.

---

## Edge Cases

| Case | Handling |
|---|---|
| Frontmatter delimiter inside phase fields contains a tab or whitespace | The parser uses ASCII Unit Separator (`\x1f`, U+001F) as the inter-field delimiter on every row it emits, NOT tab. Bash `IFS` set to a whitespace character would collapse adjacent separators and break rows with empty intermediate fields (e.g. `name=""`). US is non-whitespace; `IFS=$'\x1f'` keeps every field positional even when some are empty. |
| `--validate` vs PSK024 semantics | The driver's `--validate` is fast structural validation against the live frontmatter — same checks PSK024 runs but with a single plan in scope and no advisory escalation. PSK024 (sync-check) lints every `agent/plans/*.md` that looks executable and routes findings through the hook layer. Use `--validate` for tight loops during plan authoring; rely on PSK024 for repo-wide consistency. |
| Multiple plans in flight | `next` / `retry` auto-resolve the slug only when exactly one plan is in flight (single `run-plan-*.run` file in `agent/.workflow-state/`). With ≥2 in flight, the slug is mandatory — the driver refuses ambiguous commands. `--health` and `status` always list all in-flight plans so the operator can see which slugs to disambiguate. |
| Retry counter reset on abort | `RETRIES=0` is initialized by `start` and reset to `0` whenever a phase advances (`mark-done` succeeds). It is NOT reset by `retry` — that increments. After `abort <slug>`, the run-state file is moved to `*.aborted.*`; a subsequent `start <slug>` re-initializes a fresh run-state with `RETRIES=0`. This is the escape hatch: an exhausted-retries phase can be re-attempted by aborting + redrafting + restarting. |
| Cycle in `depends_on` | PSK024-D catches cycles at lint time. Runtime guard: `_next_actionable_phase` returns empty when no phase has all its deps done; if no phase is in `done` state and the function returns empty, the driver exits `2` with "no actionable phase found — schema may be malformed (cyclic depends_on?)". |
| Interrupted sub-agent (rate limit, context compact, host-agent crash) | The workflow state file remains at `AWAITING:SUBAGENT_SPAWN` or `AWAITING:SUBAGENT_RETRY` for the current phase. The artifact file is missing or empty. The operator re-enters via `resume <slug>` (re-emits SPAWN, no state change) or `retry <slug>` (increments counter, re-emits SPAWN). The state machine never advances past an un-gated phase, so no progress is lost. |
| Artifact present but malformed (e.g. missing `commit_sha:` for `commit_required: true`) | The default gate is artifact-existence (`test -f`). For stricter assertions, the plan author writes a gate that parses the frontmatter — for example `grep -q '^commit_sha: [a-f0-9]\+' <artifact>`. The kit ships the artifact template with the required fields but does not enforce them by default — gates are per-plan. |
| Plan body lost on re-save | `psk-plan-save.sh save` preserves the markdown body byte-for-byte. Only the `updated:` frontmatter field is refreshed on re-save; every other key (multi-line values, arrays, `revision_history`) round-trips intact. If a plan was authored, saved, and the body subsequently truncated, the cause is upstream of the script — recover from git history. |
| `start` invoked on a plan already executing | The driver refuses with `plan '<slug>' is already executing — use 'resume <slug>' or 'abort <slug>'` and prints the workflow status. There is no implicit "restart from scratch" — the operator must abort first. |

---

## Bypass

`PSK_PLAN_EXEC_DISABLED=1` disables three gates simultaneously:

1. Schema validation in `psk-plan-save.sh approve` — `approved` is set without checking `phases:` conformance.
2. Driver refusal in `psk-run-plan.sh start` — non-conformant plans execute under compat-mode semantics.
3. PSK024 sync-check rule — no advisory in PostToolUse, no error in PreCommit hook.

**When to use it.** Genuine emergencies only — for example, fixing a kit bug that has temporarily made every plan unparseable, or recovering from a half-converted plan where the schema gate is itself the obstacle. The bypass does not persist across sessions; the variable must be re-set every time. Re-enabling the gate is the default.

**What it does NOT bypass.** The workflow state machine (`psk-workflow-state.sh`) still enforces gates; `psk-run-plan.sh next` still requires the phase gate to exit `0`. The bypass removes the *schema* gates, not the *execution* gates. A plan executing under the bypass can still fail its per-phase gate and pause normally.

---

## Related Flows

- [Flow 25 — Workflow Fidelity](25-workflow-fidelity.md) — the parent layer. The plan-execution driver is registered as workflow `run-plan-<slug>` on `psk-workflow-state.sh`, so it inherits the resumable phase state machine and the spawn-fidelity protocol. Pausing, resuming, AWAITING semantics are the same across both layers.
- [Flow 16 — Feature Design](16-feature-design.md) — per-feature plans in `agent/design/f{N}-*.md` use the same schema when they need executable phases.
- §Plan-Save Protocol (in `portable-spec-kit.md` → Development Practices → Task Tracking) — the four triggers that persist a plan to `agent/plans/`. v0.6.57 adds the schema gate on `approve` and the body-preservation guarantee on `save`.
- §Template Quality Bar (in `portable-spec-kit.md`) — `plan-executable.md`, `plan-prompt.md`, and `plan-artifact.md` all pass the 7-criterion bar. Edits to the templates land via the same lint that gates every other kit template.

---

## Worked Example — executing `workflow-fidelity` via the driver

The plan that introduced this protocol is `agent/plans/2026-05-13-workflow-fidelity.md`. Its B0.6 phase (this very flow doc + the skill file) was authored under `compat_mode: true` — the plan pre-dates `schema_version: 1`. B7+ phases will be schema-conformant.

**Compat-mode round (B0.6).** The plan declares `compat_mode: true` and has no `phases:` array, so `start` runs a single synthetic phase:

```bash
$ bash agent/scripts/psk-run-plan.sh start workflow-fidelity
── compat_mode: legacy plan executes as a single synthetic phase ──
SPAWN: phase=compat prompt=agent/plans/2026-05-13-workflow-fidelity.md \
       artifact=agent/.workflow-state/run-plan-workflow-fidelity.compat.done.md \
       gate=test -f agent/.workflow-state/run-plan-workflow-fidelity.compat.done.md

  AWAITING_SUBAGENT — plan 'workflow-fidelity' paused at phase 'compat'
  ...
```

The main agent reads the entire plan body, spawns a sub-agent with that as the prompt, the sub-agent does the work (in this round: the flow doc + skill file), writes the synthetic `.compat.done.md` artifact, and returns. Then:

```bash
$ bash agent/scripts/psk-run-plan.sh next
COMPLETE — compat-mode plan 'workflow-fidelity' executed (one-shot).
  Next start of this plan requires conversion: psk-run-plan.sh --convert workflow-fidelity
```

**Conversion round.** Before the next phase batch (B7+, B8, etc.) runs, the plan must be converted:

```bash
$ bash agent/scripts/psk-run-plan.sh --convert workflow-fidelity
── conversion: legacy plan 'workflow-fidelity' → schema_version: 1 ──
SPAWN: phase=convert prompt=agent/.workflow-state/run-plan-workflow-fidelity.convert.prompt.md \
       artifact=agent/.workflow-state/run-plan-workflow-fidelity.convert.done.md \
       gate=bash agent/scripts/psk-run-plan.sh --validate workflow-fidelity
```

A sub-agent reads the legacy plan, derives `phases:` from the existing `## Implementation Order` section (Phase A → A1..A6; Phase B → B0..B7 with current B0.x sub-phases), scaffolds `agent/plans/workflow-fidelity/prompts/<id>.md` and `.../artifacts/<id>.done.md` for each, writes the frontmatter, and commits. The gate (`--validate`) re-runs PSK024 against the patched plan — it must exit `0` for the conversion phase to be marked done.

**Schema-conformant round (B7 onwards).**

```bash
$ bash agent/scripts/psk-run-plan.sh start workflow-fidelity
SPAWN: phase=B7 prompt=agent/plans/workflow-fidelity/prompts/B7.md \
       artifact=agent/plans/workflow-fidelity/artifacts/B7.done.md \
       gate=bash agent/scripts/psk-sync-check.sh --full
  ...
```

`start` walks the dependency graph, finds B7 actionable (depends_on covers every B0.x already done), emits SPAWN. The main agent spawns a sub-agent with the per-phase prompt at `agent/plans/workflow-fidelity/prompts/B7.md` — fully self-contained, no chat context. The sub-agent runs B7's release ceremony, writes the artifact with commit SHA, returns. `next` runs the gate (`psk-sync-check.sh --full`), advances if clean. If the gate fails the operator inspects, fixes, re-runs — no inline-fallback path exists.

**On interruption.** If a context compact hits mid-B7, the state file at `agent/.workflow-state/run-plan-workflow-fidelity.state` records `PHASE_B7=AWAITING:SUBAGENT_SPAWN`. The next session reads `bash agent/scripts/psk-run-plan.sh --health`, sees B7 in flight, runs `resume workflow-fidelity` to re-emit the SPAWN, and continues from the exact phase — no restart, no skip, no improvisation.

This is what plan-fidelity looks like in practice — the same discipline workflow-fidelity (Flow 25) brings to kit workflows, applied one level up to user-drafted plans.
