# Flow 28 — Spawn Fidelity

Every sub-agent invocation, anywhere in the kit, routes through `agent/scripts/psk-spawn.sh`. The wrapper has no inline-fallback branch. Synthesis-as-shortcut is structurally blocked. Failed spawns persist to a retry queue, resume on next session, and are monitored by a watchdog for hung phases.

> **Why this exists:** the prior reflex incident where SDK stream-idle-timeouts caused the orchestrator to skip real adversarial QA-Agent spawns and write findings inline. The kit's "structural" enforcement was actually trust-based — the agent could quietly substitute synthesis for adversarial audit when external infrastructure failed. §Spawn Fidelity (6th reliability layer) closes that hole with 9 structural mechanisms. See `agent/PHILOSOPHY.md` P11.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | Any kit script that needs to invoke a sub-agent (reflex/lib/spawn-qa.sh, reflex/lib/spawn-dev.sh, agent/scripts/psk-critic-spawn.sh, agent/scripts/psk-orchestrate.sh, agent/scripts/psk-run-plan.sh, reflex/lib/file-bugs.sh) |
| **Inputs** | Workflow id, phase id, prompt file path, artifact file path |
| **Outputs** | SPAWN signal emitted to main agent (which spawns sub-agent via Task tool); on sub-agent return artifact path + commit SHA; on failure AWAITING_SUBAGENT_RETRY state + retry-queue entry |
| **Scripts** | `psk-spawn.sh` (the wrapper) · `psk-retry-queue.sh` (persistent retry queue) · `psk-resume-bootstrap.sh` (session-start auto-resume) · `psk-workflow-watchdog.sh` (hung-phase detector) · `psk-bypass-log.sh` (bypass tamper-detection) |
| **Gates** | Gate 13 `audit-completeness` in `reflex/lib/gates.sh` · PSK026 sync-check (critic-result.md completeness) · PSK027 sync-check (bypass-tamper-detection) · PSK029 sync-check (resume-bootstrap currency) |
| **When blocked** | Rate limit / SDK timeout / sub-agent failure → caller script writes AWAITING_SUBAGENT_RETRY:<phase> to workflow state + retry-queue entry + pauses. Resume re-emits SPAWN. No inline-fallback branch. |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Caller script needs sub-agent work                       │
│    Example: reflex/lib/spawn-qa.sh                          │
└─────────────────────────────┬───────────────────────────────┘
┌─────────────────────────────┴───────────────────────────────┐
│ 2. Caller writes prompt file (canonical 7-section template) │
│    agent/plans/<slug>/prompts/<phase>.md                    │
│      · Goal                                                 │
│      · Files to read                                        │
│      · Files to write                                       │
│      · Completion criteria                                  │
│      · Output artifact spec                                 │
│      · Constraints                                          │
│      · Commit                                               │
└─────────────────────────────┬───────────────────────────────┘
┌─────────────────────────────┴───────────────────────────────┐
│ 3. Caller invokes psk-spawn.sh request <workflow> <phase>   │
│      <prompt-file> <artifact-file>                          │
│   psk-spawn.sh:                                             │
│      · check workflow gate state (idempotency outer net)    │
│      · writes AWAITING_SUBAGENT:<phase> to workflow state   │
│      · emits SPAWN signal to main agent                     │
│      · NO inline-fallback branch — only forward path is     │
│        retry-spawn via resume                               │
└─────────────────────────────┬───────────────────────────────┘
┌─────────────────────────────┴───────────────────────────────┐
│ 4. Main agent reads prompt file, spawns sub-agent via Task  │
│    tool. Sub-agent runs with NO inherited context.          │
└─────────────────────────────┬───────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ 5. Two paths based on sub-agent outcome:                    │
│                                                             │
│   success → Sub-agent writes artifact + commits             │
│           → psk-spawn.sh complete <workflow> <phase>        │
│           → Gate runs; GATE_PASSED_<phase>=<ts> recorded    │
│                                                             │
│   failure → Rate limit / SDK timeout / spawn fail           │
│           → psk-spawn.sh writes AWAITING_SUBAGENT_RETRY     │
│           → psk-retry-queue.sh add (exponential backoff)    │
└─────────────────────────────┬───────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────────────┐
│ 8b. Session ends / context compacts                         │
│   Workflow state file persists AWAITING_SUBAGENT_RETRY      │
│   Retry queue YAML persists in agent/.workflow-state/       │
└─────────────────────────────┬───────────────────────────────┘
┌─────────────────────────────┴───────────────────────────────┐
│ 9b. Next session start                                      │
│   FIRST agent action: bash psk-resume-bootstrap.sh          │
│      · drains due retry-queue entries (re-emits SPAWN)      │
│      · lists paused workflow phases                         │
│      · logs to agent/.workflow-state/session-audit.log      │
│   psk-workflow-watchdog.sh detects hung phases              │
└─────────────────────────────────────────────────────────────┘
```

---

## Inputs

- Caller script that needs sub-agent work (must be registered in §Covered surfaces below)
- Prompt file at `agent/plans/<slug>/prompts/<phase>.md` (canonical 7-section template)
- Artifact spec at `agent/plans/<slug>/artifacts/<phase>.done.md` (canonical 4-field template)

## Outputs

- SPAWN signal emitted to main agent on success path
- Artifact file written by sub-agent (Commit SHA · Files changed · Test results · Notes)
- `GATE_PASSED_<phase>=<ts>` recorded in workflow state on gate pass
- Retry-queue entry on failure path with exponential backoff
- Session-audit log marker on every session-start resume-bootstrap

## Gates

| Gate | Layer | What it checks |
|---|---|---|
| Gate 13 `audit-completeness` | `reflex/lib/gates.sh` mechanical gate | Reflex pass dirs — synthesis-detection probe verdict ≠ synthesis-confirmed |
| PSK026 | `psk-sync-check.sh` rule | critic-result.md files have completeness signatures (file:line citations, citable_quote, fresh mtime) |
| PSK027 | `psk-sync-check.sh` rule | `agent/.bypass-log` content: WARNING at 1-2 bypasses / ERROR at 3+ in 24h |
| PSK029 | `psk-sync-check.sh` rule | `session-audit.log` has a `session-start-resume-check ran` marker fresher than the most-recent commit touching agent/ or src/ |

## Covered surfaces (as of v0.6.60)

- `reflex/lib/spawn-qa.sh` — reflex QA-Agent dispatch (HF1)
- `reflex/lib/spawn-dev.sh` — reflex Dev-Agent dispatch (HF1)
- `agent/scripts/psk-critic-spawn.sh` — 5 critic templates STEP_9_VALIDATION, FEATURE_COMPLETE, INIT, NEW_SETUP, EXISTING_SETUP (HF2; REINIT folded into INIT — v0.6.62)
- `agent/scripts/psk-orchestrate.sh` `build` — the unified `orchestrate` workflow's per-phase spawns (new + existing; `--update` removed v0.6.62)
- `agent/scripts/psk-run-plan.sh` per-phase spawns
- `reflex/lib/file-bugs.sh` PKFL kit-evolution trigger (G3)
- Any new spawn site added after v0.6.60 must follow the Standard Spawn Recipe in `.portable-spec-kit/skills/spawn-fidelity.md`.

## Workload-driven spawn count

The number of sub-agents per phase is determined by workload size, not a hardcoded constant. Examples:

| Phase | Spawn count rule | Why workload-driven |
|---|---|---|
| Orchestrate Phase 6 (feature impl) | N spawns where N = number of `[ ]` features in SPECS.md | Some projects have 5 features, some have 80 |
| Orchestrate `build` features phase | Same N spawns | Same |
| Orchestrate `build` UI-completeness backfill | M spawns where M = number of PSK025 sub-code violations | Workload follows the audit, not a fixed batch |
| Reflex QA orchestrator | `ceil(active_dims / max_dims_per_spawn)` waves of `max_parallel_agents` per wave | Scales from 26 dims today to 50+ tomorrow |
| Reflex Dev-Agent fix loop | K spawns where K = number of unique root-cause groups | Symptom findings auto-close when root is fixed |
| psk-run-plan.sh per phase | Determined by plan's `phases:` array length | Plan author defines workload |

Hardcoded counts are §Spawn Fidelity violations. Dim 28 detects them (grep for numeric loop limits like `for i in {1..N}` around spawn calls).

## Bypass

| Env var | Effect | Logged to bypass-log |
|---|---|---|
| `PSK_SPAWN_FIDELITY_DISABLED=1` | Allows inline fallback in psk-spawn.sh | Yes (PSK027 tracks) |
| `AUDIT_COMPLETENESS_GATE_DISABLED=1` | Skips gate 13 | Yes |
| `PSK_RESUME_BOOTSTRAP_DISABLED=1` | Skips session-start resume check | Yes |
| `PSK_IDEMPOTENCY_DISABLED=1` | Bypasses outer gate-check safety net | Yes |

Each bypass is for genuine emergencies only — each removes a structural guarantee and must be explicit. Repeated bypassing surfaces as PSK027 ERROR in sync-check.

## Key Rules

- **No inline-fallback branch.** `psk-spawn.sh` has no path where the agent does the sub-agent's work itself as a shortcut. The only forward command on spawn failure is retry-spawn via `resume`.
- **All sub-agent invocations route through `psk-spawn.sh`.** Direct Task-tool invocations from kit scripts are §Spawn Fidelity violations. Dim 28 detects them.
- **Workload-driven spawn count.** N features → N spawns. N dims → ceil(N/max_dims_per_spawn) waves. Hardcoded counts (`for i in {1..N}` around spawn calls) are violations.
- **Canonical prompt + artifact templates.** Every spawn uses `.portable-spec-kit/templates/plan-prompt.md` (7 sections) for the brief and `.portable-spec-kit/templates/plan-artifact.md` (4 fields) for the completion artifact.
- **First action on every session entry is `psk-resume-bootstrap.sh`.** It drains the retry queue and lists paused workflow phases before the agent responds to the user.
- **Phase idempotency is mandatory.** Every phase's gate command + artifact write + commit must be safely re-runnable. Retry-after-success cannot corrupt prior progress.
- **Synthesis is structurally blocked.** Gate 13 (`audit-completeness`) in `reflex/lib/gates.sh` fails any pass whose `findings.yaml` looks synthesized. PSK026 mirrors the same check for `critic-result.md` files in non-reflex workflows.
- **Bypasses are tamper-detected.** Every `PSK_*_DISABLED=1` invocation logs to `agent/.bypass-log`. PSK027 fires WARNING at 1-2 bypasses / ERROR at 3+ in 24h.

## Edge Cases

- **Rate limit during sub-agent spawn** → AWAITING_SUBAGENT_RETRY:<phase> written to workflow state, retry-queue entry appended with `next_attempt_at` per exponential backoff schedule. Session can end safely.
- **Session ends mid-spawn** → state persists. On next session, `psk-resume-bootstrap.sh` drains the retry queue and re-emits the SPAWN signal for the paused phase.
- **Sub-agent succeeds but agent doesn't write artifact** → caller script's gate check fails on the missing artifact; phase stays AWAITING_SUBAGENT until a re-spawn produces the artifact. Idempotency contract guarantees the re-spawn is safe even if some side effects already landed.
- **Watchdog detects HUNG phase (1h+)** → auto-enqueues into retry queue. Because phase idempotency holds, the retry is a no-op if the phase actually finished in the meantime.
- **Retry queue reaches AWAITING_HUMAN_ARBITRATION** (>5 attempts) → entry marked for operator review. Agent does NOT silently downgrade to inline work. Operator decides: extend backoff, escalate to different model, or abandon phase.
- **Synthesis detected in cycle-N findings.yaml** → cycle-(N+1) Dim 27 flags it as recursive guard. The cycle-N pass is annotated as suspect; its findings do not count toward convergence.
- **Spawn-coverage regression** (a kit script does inline AI work without `psk-spawn.sh`) → Dim 28 grep-detects on next reflex pass; filed as `scope:kit` finding with `genericity_proof` routed through PKFL.

## Related Flows

- `portable-spec-kit.md` §Spawn Fidelity — the mandatory rule (6th reliability layer)
- `agent/PHILOSOPHY.md` P11 — Spawn Fidelity principle
- `.portable-spec-kit/skills/spawn-fidelity.md` — Standard Spawn Recipe (8-step Dev-Agent fix protocol for Dim 28 findings)
- `docs/work-flows/25-workflow-fidelity.md` — Flow 25 (parent reliability layer)
- `docs/work-flows/26-plan-execution-protocol.md` — Flow 26 (sibling reliability layer)
