# Skill — Spawn Fidelity

Operational guide for the Standard Spawn Recipe and the Dev-Agent fix protocol for Dim 28 spawn-coverage findings. Codifies the 8-step recipe mandated by §Spawn Fidelity (the 6th reliability layer) so Dev-Agent has a single mechanical procedure to follow, never improvises a spawn flow.

> **Loaded when:** the agent is about to invoke a sub-agent from a kit workflow, the user mentions "spawn" / "sub-agent" / "audit-completeness", a Dim 28 finding lands in `agent/TASKS.md` or `agent/tasks/Gxx-*.md`, the agent encounters an `AWAITING:SUBAGENT_SPAWN` or `AWAITING_SUBAGENT_RETRY` state, or a new spawn site is being added to a kit script.

> **Cross-links:** §Spawn Fidelity in `portable-spec-kit.md` (6th reliability layer) · `agent/PHILOSOPHY.md` P11 — Spawn Fidelity · `.portable-spec-kit/skills/workflow-fidelity.md` (state-machine + watchdog) · `.portable-spec-kit/skills/plan-execution.md` (per-phase spawning via `psk-run-plan.sh`).

## When to use this skill

- Spawning any sub-agent inside any kit workflow (orchestrate, release, reflex, plan-driver, critic).
- Fixing a Dim 28 spawn-coverage finding routed as a kit-evolution PKFL task.
- Auditing an existing workflow for inline AI work that should be sub-agent spawn.
- Onboarding a new contributor who is adding a spawn site to `agent/scripts/` or `reflex/lib/`.
- Triaging a paused phase surfaced by `psk-workflow-watchdog.sh` or `psk-resume-bootstrap.sh`.

## The contract (3 sentences)

Every sub-agent invocation routes through `agent/scripts/psk-spawn.sh`. The wrapper has no inline-fallback branch — the only forward command on spawn failure is retry, persisted in the retry queue. Spawn count is determined by workload size, not by a hardcoded constant.

## Standard Spawn Recipe (8 steps — Dev-Agent applies verbatim to fix any Dim 28 finding)

These eight steps are the canonical fix procedure. Every Dim 28 finding's `recommendation` field in `findings.yaml` references this skill so Dev-Agent has a deterministic path; the steps map 1:1 to the Dev-Agent fix protocol in §Spawn Fidelity.

### Step 1 — Identify the unit of work

Look at the inline AI work the script is currently doing and name the natural granularity. Examples: features (one spawn per `[ ]` row in SPECS.md), UI gaps (one spawn per PSK025 sub-code violation), reflex dimensions (one spawn per dim or one wave of N dims per config), plan phases (one spawn per entry in `phases:`), or root-cause groups in findings (one spawn per group, not per symptom).

If the unit is ambiguous, choose the smallest grain that has its own completion gate. The state machine's gate-per-phase contract makes small grain safe — failure isolates to one unit, not the whole workflow.

### Step 2 — Move the prompt

Extract the inline heredoc or prompt-shaped comment block from the caller script and write it to a per-spawn prompt file. Two canonical locations:

- For plan-driven phases: `agent/plans/<slug>/prompts/<id>.md`
- For reflex spawns: `reflex/prompts/<workflow>-<phase>.md`

Use the canonical prompt template at `.portable-spec-kit/templates/plan-prompt.md`. Same 7 sections every time — see the **Prompt file canonical structure** table below.

### Step 3 — Define the artifact

Specify the artifact the sub-agent writes at phase end:

- For plan-driven phases: `agent/plans/<slug>/artifacts/<id>.done.md`
- For reflex spawns: per the workflow's existing artifact convention (e.g., `findings.yaml`, `signoff.md`, `dev-trace.md`).

Use the canonical artifact template at `.portable-spec-kit/templates/plan-artifact.md`. Same 4 fields every time — see the **Artifact file canonical structure** table below.

### Step 4 — Wire through `psk-spawn.sh`

Replace the inline Task-tool call (or worse, inline synthesis) with the spawn-wrapper invocation. The caller pattern is:

```bash
bash agent/scripts/psk-spawn.sh request <workflow> <phase-id> <prompt-path> <artifact-path>
# Script exits with AWAITING_SUBAGENT (exit code reserved for spawn-pause).
# Main agent reads the SPAWN line, invokes Task tool with the prompt file, waits for artifact.
bash agent/scripts/psk-spawn.sh complete <workflow> <phase-id> <artifact-path>
# Script verifies artifact freshness + non-empty, then advances.
```

There is no third branch. On SDK failure or rate-limit, `psk-spawn.sh` writes `AWAITING_SUBAGENT_RETRY:<phase>` to the workflow state file and adds an entry to `agent/.workflow-state/retry-queue.yml`. The caller script does not synthesize a fallback artifact — it pauses, the queue persists, the next session drains it.

### Step 5 — Make spawn count workload-driven

Iterate over the natural units identified in Step 1. One spawn per unit, or batched per a config dial when the unit is genuinely small.

```bash
# Wrong — hardcoded count is a §Spawn Fidelity violation.
for i in {1..3}; do
  bash agent/scripts/psk-spawn.sh request reflex qa-$i ...
done

# Right — iterate over the workload.
mapfile -t FEATURES < <(grep -E '^- \[ \]' agent/SPECS.md | awk '{print $3}')
for FID in "${FEATURES[@]}"; do
  bash agent/scripts/psk-spawn.sh request orchestrate "feature-$FID" \
    "agent/plans/<slug>/prompts/${FID}.md" \
    "agent/plans/<slug>/artifacts/${FID}.done.md"
done
```

When a config dial controls batch size (e.g. reflex `qa_agent.max_dims_per_spawn`), the loop multiplies units by the dial. The dial NEVER becomes a fixed loop count; it parameterizes the batch.

### Step 6 — Register the phase gate

Every spawn needs a registered completion gate so the workflow state machine can verify done-ness:

```bash
bash agent/scripts/psk-workflow-state.sh register-gate \
  <workflow> <phase-id> \
  "<gate-cmd>"   # e.g. "test -s <artifact> && grep -q 'Commit SHA' <artifact>"
```

The gate runs after `psk-spawn.sh complete`. The phase only advances to `done` on gate pass. On gate fail, the phase stays in `executing` and the operator inspects the artifact. This is the **outer** idempotency safety net — combined with the per-prompt idempotency checks (Step 4 of the phase prompt itself), retry-after-success is structurally safe.

### Step 7 — Add retry-queue integration

No extra work. `psk-spawn.sh` writes the retry-queue entry on failure automatically (HF3 wired this once for every spawn site). The entry carries: workflow id, phase id, prompt path, artifact path, attempt count, next-attempt-at timestamp, exponential backoff (`5min → 15min → 45min → 2h → 6h → AWAITING_HUMAN_ARBITRATION`).

Inspect the queue:

```bash
bash agent/scripts/psk-retry-queue.sh list
bash agent/scripts/psk-retry-queue.sh inspect <entry-id>
bash agent/scripts/psk-retry-queue.sh drain   # processes all due entries
```

### Step 8 — Document the spawn

Two additions land alongside the spawn site itself:

1. **Flow doc update** — the relevant `docs/work-flows/*.md` for this workflow gets a row in its spawn table or a short paragraph explaining the new spawn point.
2. **Regression test** — `tests/sections/<NN>-<workflow>.sh` gets a section that (a) mocks `psk-spawn.sh` to return AWAITING_SUBAGENT, (b) asserts the workflow paused (state file shows AWAITING:SUBAGENT_SPAWN), (c) mocks completion and asserts the state machine advanced. Mirror the pattern from Sections 70-79 in `tests/sections/03-reliability.sh`.

## Prompt file canonical structure

Source template: `.portable-spec-kit/templates/plan-prompt.md`.

| Required section | Purpose |
|---|---|
| Goal | One paragraph: what this phase produces |
| Files to read | Paths the sub-agent must read FIRST (framework sections, prior artifacts, source files) |
| Files to write | Paths the sub-agent creates or modifies |
| Completion criteria | Bash commands the sub-agent runs to verify done-ness; exit codes; expected outputs |
| Output artifact spec | Schema of the `<phase>.done.md` file the sub-agent writes at phase end |
| Constraints | Hard limits (don't touch X, must use Y, gate must pass) |
| Commit | Subject format: `<plan-slug>:<phase-id> — <short>`; single commit per phase |

**Worked example:** `agent/plans/spawn-fidelity-hardening/prompts/hf3-retry-queue.md` — the prompt that produced the persistent retry queue. Read it side-by-side with this skill to see all 7 sections filled with concrete content.

## Artifact file canonical structure

Source template: `.portable-spec-kit/templates/plan-artifact.md`.

| Required field | Purpose |
|---|---|
| Commit SHA | Single SHA produced by this phase |
| Files changed | Paths touched |
| Tests run | Gate commands + outputs |
| Notes | Non-obvious decisions, edge cases discovered |

**Worked example:** `agent/plans/spawn-fidelity-hardening/artifacts/hf3-retry-queue.done.md` — the artifact returned by the HF3 sub-agent. Shows the structure the gate verifies.

## Workload-driven spawn count

The number of sub-agents spawned per workflow phase is determined by the workload size, not a hardcoded constant. Reference table from §Spawn Fidelity:

| Phase | Spawn count rule | Why workload-driven |
|---|---|---|
| Orchestrate Phase 6 (feature impl) | N spawns where N = number of `[ ]` features in SPECS.md | Some projects have 5 features, some have 80 |
| Orchestrate `--update` U7 features | Same N spawns | Same |
| Orchestrate `--update` U6.5 UI backfill | M spawns where M = number of PSK025 sub-code violations × backfill-scope | v5 had 9 violations — should have been ~9 backfill spawns, not 1 batch |
| Reflex QA orchestrator | `ceil(active_dims / max_dims_per_spawn)` waves of `max_parallel_agents` per wave | Config dials parameterize batch; not a fixed loop |
| Reflex Dev-Agent fix loop | K spawns where K = number of unique root-cause groups in findings.yaml | Symptom findings auto-close when root is fixed |
| psk-run-plan.sh per phase | Determined by the plan's `phases:` array length | Plan author defines workload |
| Per-feature within a feature spawn (if feature is large) | Recursive: feature-scoped plan with its own `phases:` array | Heuristic: ≥5 acceptance criteria OR ≥3 files = use psk-run-plan |

**Config dials.** Every workflow exposes `max_<unit>_per_spawn` and `max_parallel_<unit>_spawns` config keys in `reflex/config.yml` or `.portable-spec-kit/config.md` so the operator can tune throughput vs cost without changing kit code. Defaults err on the side of one-spawn-per-unit; raise the batch size only when the unit is genuinely small (e.g. reflex dims at 10 dims/spawn).

**Hardcoded counts are §Spawn Fidelity violations.** Dim 28 detects them — it grep-scans for numeric loop limits like `for i in {1..N}` in proximity to spawn calls. If your script needs a fixed count, the spawn count is wrong; find the real workload.

## Failure handling — what happens when a spawn fails

The chain is automatic. Dev-Agent does not need to remember any of these steps individually; just route through `psk-spawn.sh` and the machinery does the rest.

1. **SDK timeout or rate-limit hits.** `psk-spawn.sh` catches the failure exit code from the Task-tool invocation.
2. **State file updated.** `agent/.workflow-state/<workflow>.state` flips the current phase from `executing` to `AWAITING_SUBAGENT_RETRY:<phase>`. Persisted to disk.
3. **Retry queue entry written.** `agent/.workflow-state/retry-queue.yml` gets a new entry with workflow id, phase id, prompt path, artifact path, attempt count, exponential-backoff `next_attempt_at` timestamp.
4. **Session ends or compacts.** No matter — state is durable on disk.
5. **Next session starts.** `agent/scripts/psk-resume-bootstrap.sh` runs as the first action (mandated by §Resume-on-Session-Start). It drains all due retry-queue entries, re-emits SPAWN signals for paused phases, and writes the resume audit marker.
6. **Main agent re-spawns.** The Task tool is invoked with the persisted prompt file. Sub-agent does the work, writes the artifact, returns. Gate runs, phase advances.
7. **Watchdog catches missed retries.** `agent/scripts/psk-workflow-watchdog.sh` (also run by `psk-resume-bootstrap.sh` Step 4) detects any phase older than the WARN threshold (15 min default) and surfaces it; phases older than HUNG (60 min default) are auto-enqueued.

Cite: HF1, HF1b, HF2 (retrofit sites) · HF3 (retry queue) · HF4 (resume-on-start) · HF4b (watchdog + phase idempotency).

## Common Dim 28 patterns and their fixes

These are the four recurring smell-shapes Dim 28 grep-detects. Each gets the Standard Spawn Recipe applied.

### Pattern 1 — Heredoc prompt ≥1000 chars without spawn

**Symptom:** kit script has a `<<EOF ... EOF` block whose body is agent-directive content (sentences telling the agent what to read, what to write, what to verify); no `psk-spawn.sh request` call follows.

**Fix:** extract the heredoc body into `agent/plans/<slug>/prompts/<phase>.md` (or `reflex/prompts/<workflow>-<phase>.md`). Caller invokes `bash agent/scripts/psk-spawn.sh request <workflow> <phase> <prompt-path> <artifact-path>` and exits AWAITING_SUBAGENT.

### Pattern 2 — Agent-directive comment outside prompt path

**Symptom:** comment block like `# agent: parse this file, extract findings, produce a YAML report` or `# the agent should validate that ...` sitting in a kit script with no spawn invocation.

**Fix:** decide whether the work is sub-agent or mechanical. If sub-agent → route through `psk-spawn.sh` per the Standard Spawn Recipe. If mechanical → refactor into a deterministic script under `agent/scripts/` with a clear top-of-file doc-string declaring it mechanical, and add it to the Dim 28 mechanical-scripts allowlist in `reflex/prompts/qa-agent.md`.

### Pattern 3 — Function reads ≥5 files + writes ≥2 files outside allowlist

**Symptom:** a kit-script function opens many files, transforms them, writes outputs that are not simple grep summaries or YAML edits. Looks like AI-shaped work without a spawn wrapper.

**Fix:** apply the Standard Spawn Recipe verbatim. The 5+2 heuristic is a smell, not a diagnosis — confirm by reading the function's intent first. If it's genuinely mechanical (templated file generation, fixed-shape transforms), document it as mechanical and add to the allowlist. If the function makes judgment calls about content, it's AI work — externalize as a spawn.

### Pattern 4 — New script not declared mechanical, not routing through spawn

**Symptom:** fresh file under `agent/scripts/` or `reflex/lib/` that's invoked by a workflow but has no clear top-of-file doc-string declaring it mechanical (pure deterministic) and doesn't call `psk-spawn.sh`.

**Fix:** either (a) document the script as mechanical in its top-of-file doc-string AND add it to the Dim 28 allowlist in `reflex/prompts/qa-agent.md`, or (b) refactor through `psk-spawn.sh` following the Standard Spawn Recipe. The default for ambiguous cases is (b) — externalize as a spawn; safe-and-slow beats fast-and-silent-synthesis.

## Supervision machinery (HF3-HF4b)

The retry queue and resume-bootstrap make failure recovery automatic. Operator surfaces:

- **`psk-retry-queue.sh`** — inspect in-flight retries: `bash agent/scripts/psk-retry-queue.sh list`
- **`psk-resume-bootstrap.sh`** — runs on session start; drains the queue, surfaces paused phases, runs watchdog probe
- **`psk-workflow-watchdog.sh`** — operator probes for hung phases out-of-band: `bash agent/scripts/psk-workflow-watchdog.sh scan`

## Operator commands quick reference

| Need to... | Command |
|---|---|
| List paused workflow phases | `bash agent/scripts/psk-workflow-state.sh list-paused` |
| List due retry-queue entries | `bash agent/scripts/psk-retry-queue.sh list` |
| Force-resume a paused phase | `bash agent/scripts/psk-workflow-watchdog.sh kick <workflow> <phase>` |
| Manually retry a failed spawn | `bash agent/scripts/psk-spawn.sh retry <workflow> <phase>` |
| Override backoff (force immediate retry) | `PSK_RETRY_FORCE=1 bash agent/scripts/psk-spawn.sh retry <workflow> <phase>` |
| Drain all due retries | `bash agent/scripts/psk-retry-queue.sh drain` |
| Probe a pass for synthesis | `bash reflex/lib/check-audit-completeness.sh <pass-dir> --json` |
| Inspect a single retry entry | `bash agent/scripts/psk-retry-queue.sh inspect <entry-id>` |
| Run session-start resume manually | `bash agent/scripts/psk-resume-bootstrap.sh` |
| Bypass spawn fidelity (emergency) | `PSK_SPAWN_FIDELITY_DISABLED=1 ...` |
| Inspect bypass log (last 7 days) | `bash agent/scripts/psk-bypass-log.sh list` |
| Count bypasses in last 24h (PSK027 surface) | `bash agent/scripts/psk-bypass-log.sh count` |
| Provide justification with a bypass | `PSK_BYPASS_REASON='reason' PSK_<NAME>_DISABLED=1 ...` |

## Anti-patterns (what NOT to do)

These are the structural §Spawn Fidelity violations. Each fails Dim 28 audit, blocks at gate 13 if it slips through, and surfaces as a `scope: kit` MAJOR finding routed to PKFL.

1. ❌ **Inline Task-tool invocation from a kit script.** Bypassing the wrapper bypasses the retry queue + state machine. Always route through `psk-spawn.sh`.
2. ❌ **Hardcoded spawn count.** Patterns like `for i in {1..3}; do spawn; done` are §Spawn Fidelity violations. The count must derive from a workload (features, dims, findings, phases).
3. ❌ **Synthesis on SDK failure.** If a spawn hits an SDK error, do NOT write the artifact yourself from inline context. Pause via `psk-spawn.sh`'s failure path and let the retry queue handle it.
4. ❌ **Skipping the gate after spawn.** Every phase has a registered completion gate. The driver verifies it before advancing. Removing the gate to "speed things up" is a §Workflow Fidelity + §Spawn Fidelity double-violation.
5. ❌ **Forgetting the prompt file.** Inline prompts in kit scripts make Dim 28 fire on every audit. Always externalize the prompt to a file under `agent/plans/<slug>/prompts/` or `reflex/prompts/`.
6. ❌ **Mixing mechanical and AI work in one script without declaring intent.** A script that's half-deterministic, half-AI is unauditable. Split it: mechanical half stays in `agent/scripts/`, AI half routes through `psk-spawn.sh`.

## Self-test (apply to any spawn site you add)

Before committing a new spawn site, verify all seven boxes are checked:

1. [ ] Caller script invokes `psk-spawn.sh request` (not Task tool directly)
2. [ ] Prompt is in a file under `agent/plans/<slug>/prompts/` or `reflex/prompts/`
3. [ ] Artifact is in a file under `agent/plans/<slug>/artifacts/` or per the workflow's existing artifact contract
4. [ ] Completion gate is registered with `psk-workflow-state.sh register-gate`
5. [ ] Spawn count is workload-driven (no hardcoded constant)
6. [ ] Regression test added in `tests/sections/` covering the pause-and-advance protocol
7. [ ] No heredoc prompts ≥1000 chars in the caller script (run `grep -c '<<EOF' <script>` locally as a quick Dim 28 sanity check)

If any box is unchecked, the spawn site will fail Dim 28 audit and block at gate 13 (`audit-completeness`). Fix before committing — easier to land it right the first time than to chase a PKFL kit-evolution task later.

## Emergency bypass

`PSK_SPAWN_FIDELITY_DISABLED=1` allows inline fallback (existing from HF4). Each invocation logs to `agent/.bypass-log` per PSK027 sync-check rule (HF9 deliverable) — repeated bypassing surfaces as an ERROR in sync-check. The bypass is for genuine emergencies only — each use removes a structural guarantee and must be explicit. Re-enabling the gate is the default; the bypass does not persist across sessions. Provide a justification via `PSK_BYPASS_REASON='<reason>'` to record context with the entry.
