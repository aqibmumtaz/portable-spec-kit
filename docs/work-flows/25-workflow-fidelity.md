# Flow 25 — Workflow Fidelity

The agent executes every kit-defined process faithfully and completely. It never substitutes its own judgment for whether to follow a defined workflow, gate, rule, or phase. Rate limits and context limits are handled by pause-and-resume — never by reduce-scope.

> **Why this exists:** searchsocialtruth-v5 shipped a skeletal UI behind a "20/20 features, 110 tests passing" report. Root cause across every symptom — sub-agent rate-limit → inline shortcut, long context → silent scope reduction, no UI gate → agent's own "done" judgment. All one failure: the agent overrode the kit's defined process. See `agent/PHILOSOPHY.md` P10.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | Any executable kit workflow starts (`psk-orchestrate.sh`, `psk-release.sh`, `psk-new-setup.sh`, `psk-existing-setup.sh`, `psk-init.sh` (idempotent — folds the retired `reinit`), `psk-feature-complete.sh`, `reflex/run.sh`) |
| **Inputs** | The workflow's phase sequence; `agent/.workflow-state/<workflow>.state` (resumable phase state); per-phase completion gates |
| **Outputs** | Each phase completed to its registered gate; state file recording exact progress; on interruption a paused state with exact resume point |
| **Script** | `agent/scripts/psk-workflow-state.sh` (phase state machine) · `agent/scripts/psk-spawn.sh` (sub-agent spawn-fidelity protocol) |
| **Gate** | A phase cannot be marked done until its registered completion gate passes. `psk-spawn.sh` has no inline-fallback branch. |
| **When blocked** | Rate limit / context compact / sub-agent failure → workflow pauses with `AWAITING_*` state; `resume` re-enters at the exact phase. Never restart, never skip, never reduce scope. |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Executable workflow starts                               │
│    psk-workflow-state.sh init <workflow> <phase-csv>        │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 2. Per phase: mark-in-progress <phase>                      │
│    Phase needs sub-agent?                                   │
│      yes → psk-spawn.sh request → AWAITING_SUBAGENT         │
│            main agent spawns Task-tool sub-agent            │
│            success  → psk-spawn.sh complete                 │
│            rate-lim → psk-spawn.sh retry → re-spawn         │
│            (NO inline-fallback path)                        │
│      no  → agent does the phase work directly               │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 3. mark-done <phase> → runs registered completion gate      │
│    gate FAIL → phase NOT done, error surfaced               │
│    gate PASS → phase done, state file updated               │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 4. All phases done? no → next phase. yes → workflow complete│
│    Interruption at ANY point (rate-limit / context compact) │
│    state file persists → `resume` re-enters at exact phase  │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Rules

- **The agent executes, never overrides.** When the kit defines a process, the agent follows it. The agent's judgment is for *what the user wants* and *novel problems* — never for *whether to follow a defined kit process*.
- **No phase compression, skipping, or reordering.** The state machine will not advance past an ungated phase.
- **No inline substitution for a sub-agent phase.** `psk-spawn.sh` has no "do it yourself instead" branch. On rate-limit, the only forward command is retry-spawn.
- **No scope reduction under pressure.** Rate limits, context limits, "go fast" instructions — all handled by pause-and-resume. Full delivery is the contract; token/time cost is acceptable.
- **The kit's "done" is the definition of done.** A phase's registered completion gate decides done — not the agent's judgment.
- **Every executable workflow is covered.** All 8 workflow scripts reference §Workflow Fidelity and run on the shared state machine or its discipline.

---

## Edge Cases

| Case | Handling |
|---|---|
| Sub-agent rate-limits mid-phase | `psk-spawn.sh retry` → `AWAITING_SUBAGENT_RETRY` → wait for limit to clear → spawn again. Waiting is acceptable; inline is not. |
| Context compacts mid-workflow | State file persists. After compact, `resume <workflow>` prints the exact phase to re-enter. |
| Completion gate fails | Phase stays not-done. Agent fixes the gate failure, re-runs `mark-done`. No advance. |
| A phase genuinely cannot complete | Mark `AWAITING:<reason>` with a documented reason. This is an explicit, recorded pause — not a silent scope cut. |
| Emergency bypass needed | `PSK_WORKFLOW_STATE_DISABLED=1` / `PSK_SPAWN_FIDELITY_DISABLED=1` — each removes a structural guarantee, must be explicit, genuine emergencies only. |

---

## Related Flows

- [Flow 13 — Release Workflow](13-release-workflow.md) — `psk-release.sh` runs on the state machine
- [Flow 18 — Project Orchestration](18-project-orchestration.md) — `psk-orchestrate.sh` phases gated; `await_subagent` routes through `psk-spawn.sh`
- [Flow 17 — Reflex](17-reflex.md) — reflex convergence discipline (L1-L6) is the reflex-specific instance of Workflow Fidelity
- [Flow 24 — Template-Driven Creation](24-template-driven-creation.md) — template gates are completion gates registered on orchestration phases

---

## Bypass

`PSK_WORKFLOW_STATE_DISABLED=1` skips the phase state machine. `PSK_SPAWN_FIDELITY_DISABLED=1` allows the spawn wrapper to stop blocking (it still never does the work itself). Both are for genuine emergencies only — each removes a structural guarantee that exists because trust-based compliance failed in searchsocialtruth-v5.
