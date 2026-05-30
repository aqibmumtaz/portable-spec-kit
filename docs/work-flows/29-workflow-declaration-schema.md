# 29 — Workflow Declaration Schema (7th Reliability Layer)

> **Added in:** v0.6.62 — completes the structural-enforcement stack: §Workflow Fidelity (4th) gates *process*, §Plan Execution Protocol (5th) gates *plan-shape*, §Spawn Fidelity (6th) gates *sub-agent spawns*, and §Workflow Declaration Schema (7th — this doc) gates *workflow-shape*. Plans and workflows now converge on a single canonical declaration shape so the operator who learns one knows the other.

## Overview

| Field | Value |
|---|---|
| **Purpose** | Force every kit workflow to declare its phases as data instead of hardcoding them in a bash loop |
| **Layer** | 7th reliability layer (workflow-shape) |
| **Trigger** | Any script carrying a `# workflow-router:` header |
| **Declaration file** | `.portable-spec-kit/workflows/<name>/phases.yml` |
| **Dispatcher** | `agent/scripts/psk-dispatch.sh` reads `phases.yml` at runtime |
| **Sync-check rules** | PSK034 (router ↔ phases.yml mapping) + PSK035 (schema validation) |
| **Bypass** | `PSK_WORKFLOW_DECL_DISABLED=1` (emergencies only, logged to `agent/.bypass-log`) |

## Flow Diagram

```
+-------------------------------------------------------------+
|  caller script (e.g. psk-release.sh — thin router)          |
|                                                             |
|   |  exec psk-dispatch.sh <workflow> <verb>                 |
|   v                                                         |
|  +-------------------------------------------------------+  |
|  | psk-dispatch.sh                                       |  |
|  |                                                       |  |
|  |  1. read .portable-spec-kit/workflows/<wf>/phases.yml |  |
|  |  2. iterate phases[] in dependency order              |  |
|  |  3. dispatch per spawn_type:                          |  |
|  |                                                       |  |
|  |   sub-agent       -> psk-spawn.sh request <prompt>    |  |
|  |   mechanical      -> bash -c "<command>" + gate check |  |
|  |   manual-checkpoint -> pause for operator confirm     |  |
|  +-------------------------------------------------------+  |
|                                                             |
|  PSK034 lints router presence + reads phases.yml at runtime |
|  PSK035 lints phases.yml schema + per-phase prompt template |
+-------------------------------------------------------------+
```

## Key Rules

- Every script with a `# workflow-router:` header MUST have a matching `.portable-spec-kit/workflows/<name>/phases.yml` declaration (PSK034)
- `phases.yml` MUST carry `schema_version: 1`, top-level `workflow` + `description`, and a `phases` array (PSK035)
- Each phase requires `id`, `name`, `goal`, `spawn_type`, `gate`, `commit_required` — plus `prompt`+`artifact` for sub-agent phases OR `command` for mechanical phases
- Per-phase prompt files at `.portable-spec-kit/workflows/<wf>/phases/<phase-id>.md` reuse the **Goal · Files to read · Files to write · Completion criteria · Output artifact spec** schema (same as `plan-prompt.md`)
- Sub-agent phases route through `psk-spawn.sh` per §Spawn Fidelity — no direct Task-tool calls from kit scripts
- Mechanical phases declare a `command:` field instead of prompt + artifact — dispatcher shell-execs and checks the gate
- Manual-checkpoint phases pause for explicit operator input before advancing
- Hardcoded phase loops in script bodies without a matching `phases.yml` are a PSK034 MAJOR violation
- `phases.yml` and every `phases/<id>.md` must pass `psk-template-quality.sh` (all 7 Template Quality Bar criteria) — PSK035 MAJOR otherwise
- Bypass `PSK_WORKFLOW_DECL_DISABLED=1` is for emergencies only; each invocation is logged to `agent/.bypass-log` (PSK027) and repeated bypassing surfaces as ERROR

## phases.yml schema (mandatory fields)

```yaml
schema_version: 1
workflow: <kebab-case-name>
description: |
  One paragraph: what this workflow does, when it runs, what it produces.

# Optional — only if a workflow genuinely has more than one mode
mode_variants:
  - mode: quick
    phases: [scan, report]
  - mode: full
    phases: [scan, deep-analysis, report, archive]

phases:
  - id: <phase-id>                # kebab-case unique within workflow
    name: "<short phase title>"
    goal: "<one-line goal>"
    spawn_type: sub-agent          # sub-agent | mechanical | manual-checkpoint
    prompt: ".portable-spec-kit/workflows/<workflow>/phases/<phase-id>.md"
    artifact: "agent/.workflow-artifacts/<workflow>/<phase-id>.done.md"
    # command: "bash agent/scripts/<script>.sh"   # required for mechanical
    gate: "<bash command exiting 0 when phase done>"
    commit_required: true
    depends_on: []
```

## Class taxonomy (informs retrofit scope, never authority)

| Class | Identity | Examples | Status |
|---|---|---|---|
| **Class A** — canonical | Plan-driven via `phases.yml` + the dispatcher | `psk-run-plan.sh`, `psk-spawn.sh`, every migrated workflow below | Dispatcher-driven |
| **Class B** — migrated to dispatcher (v0.6.62+) | Were legacy `# workflow-router:`, now thin routers delegating to `psk-dispatch.sh` + `phases.yml` | `psk-release.sh`, `psk-orchestrate.sh` (single workflow — `build` serves new + existing), `psk-feature-complete.sh`, `psk-init.sh` (folds the retired `reinit`), `psk-new-setup.sh`, `psk-existing-setup.sh` | Retrofit complete |
| **Class B′** — monolithic-by-design | Iterate-until-convergence orchestrators that do NOT fit the dispatcher's linear `phases.yml` model | `reflex/run.sh` (AVACR autoloop — GRANTED/DENIED branching + stateful convergence L1-L6) | Intentionally not dispatcher-migrated |
| **Class B-plan-driver** — exempt | Plan/CLI drivers that read frontmatter/plan files at runtime, not a fixed `phases.yml` | `psk-run-plan.sh`, `psk-validate.sh`, `psk-resume-bootstrap.sh` | Carry `# workflow-decl-exempt:` |
| **Class C** — helpers / CLIs / mechanical | No phases concept | ~28 scripts marked `# mechanical-script:` | EXEMPT from PSK034 |

## Operator inspection

```bash
# Preview any workflow's declared shape
bash agent/scripts/psk-preview.sh <workflow-name>

# Validate every phases.yml against schema + Template Quality Bar
bash agent/scripts/psk-template-quality.sh --all --strict

# Drive a workflow through its declared phases
bash agent/scripts/psk-dispatch.sh <workflow> start
bash agent/scripts/psk-dispatch.sh <workflow> next
bash agent/scripts/psk-dispatch.sh <workflow> status
```

## Edge Cases

- **Class B′ exemption:** Reflex's iterate-until-convergence control flow (GRANTED/DENIED branching with stateful L1-L6 convergence discipline) does not fit the linear `phases.yml` model. It is intentionally NOT dispatcher-migrated. Already §Spawn-Fidelity-compliant via `spawn-qa.sh` / `spawn-dev.sh` routing through `psk-spawn.sh`. See plan `2026-05-22-reflex-restore-and-rebuild.md` §STAGE 4 RESOLUTION.
- **Plan-driver exemption:** Scripts that drive plans (reading frontmatter at runtime, not a fixed `phases.yml`) carry `# workflow-decl-exempt:` markers. Examples: `psk-run-plan.sh` (delegates to `psk-dispatch.sh --plan`), `psk-validate.sh`, `psk-resume-bootstrap.sh`. PSK034 honors the exemption.
- **Mechanical-script exemption:** Single-purpose CLI helpers with no phases concept (e.g. `psk-sync-check.sh`, `psk-env.sh`, `psk-template-quality.sh`) are marked `# mechanical-script:` and are entirely outside PSK034's scope.
- **Mode variants:** A workflow with multiple modes declares `mode_variants:` listing phase id subsets per mode. `orchestrate` is single-mode (`build` runs the full set for both new and existing projects — each phase is idempotent create-or-update), so it has no `mode_variants` entry.

## Related Flows

- [25-workflow-fidelity.md](25-workflow-fidelity.md) — 4th reliability layer (process gate)
- [26-plan-execution-protocol.md](26-plan-execution-protocol.md) — 5th reliability layer (plan-shape gate)
- [28-spawn-fidelity.md](28-spawn-fidelity.md) — 6th reliability layer (sub-agent spawn gate)
- [13-release-workflow.md](13-release-workflow.md) — release workflow (Class B, dispatcher-driven)

## Bypass

`PSK_WORKFLOW_DECL_DISABLED=1` skips PSK034's enforcement on a given invocation. For genuine emergencies only — each bypass is an explicit operator decision to ship a workflow without its data declaration, and the bypass is logged to `agent/.bypass-log` per PSK027. Repeated bypassing surfaces as an ERROR in sync-check.

<!-- HINT: this flow doc documents the 7th reliability layer added in v0.6.62.
     Sibling 4th/5th/6th layers each have their own flow doc (25, 26, 28).
     PSK034 and PSK035 are the structural enforcement; the Class taxonomy
     explains which scripts are in scope. Update this doc whenever Class B
     gains a new migrated workflow or a new exemption is added. -->
