# Skill — Plan Execution

Operational guide for drafting, approving, and executing kit-conformant plans via sub-agent spawning. Complements the conceptual [flow doc 26](../../docs/work-flows/26-plan-execution-protocol.md).

## When to load this skill

Triggers (any of):
- User says "execute plan", "run plan", "psk-run-plan", "drive the plan"
- User asks about phases, sub-agent spawning, plan schema, plan-save errors
- User drafts a plan with `## Implementation Order` or `## Phases` body sections
- Agent sees a `phases:` frontmatter in any `agent/plans/*.md` file
- `psk-plan-save.sh approve` returns a PSK024 error
- `psk-run-plan.sh` emits `AWAITING_SUBAGENT` or `AWAITING_HUMAN_ARBITRATION`

## How to draft an executable plan

1. Start from the canonical template:
   ```bash
   cp .portable-spec-kit/templates/plan-executable.md agent/plans/$(date +%F)-<slug>.md
   ```
2. Fill placeholders marked `<!-- REQUIRED — replace before commit -->`. Body sections: Context · Goal · Approach · Decisions · Files · Phases · Risk · Rollback · State · Acceptance.
3. Define every phase in the `phases:` frontmatter array:
   ```yaml
   phases:
     - id: A1
       name: "Short phase title"
       prompt: "agent/plans/<slug>/prompts/A1.md"
       artifact: "agent/plans/<slug>/artifacts/A1.done.md"
       gate: "bash agent/scripts/psk-sync-check.sh --full"
       commit_required: true
       depends_on: []
   ```
4. Save iteratively while drafting — body preserved byte-for-byte:
   ```bash
   bash agent/scripts/psk-plan-save.sh save <slug>
   ```
5. When ready, approve (schema gate fires):
   ```bash
   bash agent/scripts/psk-plan-save.sh approve <slug>
   ```
   PSK024 errors: **N** missing schema_version · **P** missing/empty phases · **F** phase missing required field · **D** depends_on dangling/cycle · **L** prompt/artifact path layout violation.

## How to author a phase prompt file

Path: `agent/plans/<slug>/prompts/<id>.md`. Start from `.portable-spec-kit/templates/plan-prompt.md`. The sub-agent reads ONLY this file — make it self-contained.

Required sections:
- **Goal** — one paragraph stating what this phase produces
- **Files to read** — paths the sub-agent must read first (other plans, framework sections, scripts to mirror)
- **Files to write** — paths the sub-agent creates or modifies
- **Completion criteria** — bash commands the sub-agent must run, exit codes, expected outputs
- **Output artifact spec** — what the sub-agent writes to the artifact file at phase end

Commit subject at phase end MUST be: `<plan-slug>:<phase-id> — <short description>`.

## How to author a phase artifact file

Path: `agent/plans/<slug>/artifacts/<id>.done.md`. Written by the sub-agent at phase end (BEFORE returning to the orchestrator). Start from `.portable-spec-kit/templates/plan-artifact.md`.

Required sections:
- **Commit SHA** — single SHA produced by this phase
- **Files changed** — list of paths touched
- **Tests run** — gate commands and outputs
- **Notes** — non-obvious decisions, edge cases discovered

The orchestrator reads the artifact to verify completion. Replays and audits read it to inspect exactly what the phase did.

## Driving execution

```bash
# 1. Start (driver reads phases:, validates schema, emits first SPAWN)
bash agent/scripts/psk-run-plan.sh start <slug>
# Output:
#   SPAWN: phase=A1 prompt=agent/plans/<slug>/prompts/A1.md ...
#   AWAITING_SUBAGENT (exit 0)

# 2. Agent (you) spawns sub-agent via Task tool with the prompt file as the brief.
#    Sub-agent reads prompt → does the work → commits → writes artifact → returns SHA.

# 3. Advance (gate runs, phase marked done, next SPAWN emitted)
bash agent/scripts/psk-run-plan.sh next

# 4. Repeat 2-3 until driver emits COMPLETE.
```

## Handling AWAITING states

| State | Meaning | Forward action |
|---|---|---|
| `AWAITING_SUBAGENT` | Driver emitted SPAWN; main agent must spawn sub-agent | Spawn via Task tool with prompt file as brief |
| `AWAITING_SUBAGENT_RETRY:<id>` | Sub-agent failed or rate-limited | `psk-run-plan.sh retry` — re-emits same SPAWN, increments counter |
| `AWAITING_HUMAN_ARBITRATION` | 3 retries exhausted | Stop; show user the gate output + retry log; user decides: fix prompt, fix gate, or abort |
| `GATE_FAILED:<id>` | Sub-agent returned but `gate:` command failed | Read gate stderr/stdout; fix the artifact (or the gate definition if buggy); `psk-run-plan.sh next` re-runs gate |

**Critical:** never do a sub-agent's work yourself. The driver has no inline-fallback branch by design (§Workflow Fidelity). Inline shortcuts are the v5-skeletal-UI failure pattern. The only forward command is spawn / retry / abort.

## Gate failure recovery

1. Read the gate command in the plan's `phases:` array
2. Run it manually to reproduce the failure
3. Diagnose: is the artifact wrong, or is the gate wrong?
   - Artifact wrong → instruct sub-agent (via retry) to fix
   - Gate wrong → edit the plan's `gate:` field; bump plan `revision:`; re-save; re-run `next`
4. After 3 retries → AWAITING_HUMAN_ARBITRATION; escalate to user

## Conversion of legacy plans

Plans authored before v0.6.57 have no `phases:` frontmatter. One-shot compat-mode allowed:

```bash
# Add compat_mode: true to frontmatter (one-line edit)
# Then start (legacy plan runs once as a single SPAWN with whole-plan prompt):
bash agent/scripts/psk-run-plan.sh start <legacy-slug>
```

Before next `start` the plan MUST be converted:

```bash
bash agent/scripts/psk-run-plan.sh --convert <legacy-slug>
# Emits a conversion SPAWN. Sub-agent reads the legacy plan,
# infers phases from ## Implementation Order, scaffolds prompts/
# and artifacts/ stubs, writes phases: frontmatter, commits.
```

After conversion, `--validate <slug>` returns clean and subsequent `start` works normally.

## Common mistakes

| Anti-pattern | Why it fails | Right thing |
|---|---|---|
| Main agent does a phase's work inline | §Workflow Fidelity violation; the v5-skeletal pattern | Always spawn via Task tool |
| Editing an artifact file after commit | Drives sync-check + replay drift | Use a follow-up phase if change needed |
| Skipping `commit_required: true` phases | Breaks audit trail; gate may have no commit to reference | Always commit; even doc-only phases get a commit |
| Adding `compat_mode: true` permanently | Defeats the schema gate | Compat is one-shot; convert before next start |
| Running gates manually then claiming pass | Bypasses the driver's gate-pass marker | Always go through `psk-run-plan.sh next` |
| Multiple plans `executing` simultaneously without explicit slug | `next` auto-resolve fails | Always pass `--slug <name>` when >1 in flight; check `--health` |
| Frontmatter delimiters with tabs | Bash IFS collapses tabs → field shift | Driver uses ASCII 0x1f; do not hand-edit state files |

## Quick reference

| Command | Use when |
|---|---|
| `psk-plan-save.sh save <slug>` | Iterating on draft; preserves body, refreshes `updated:` |
| `psk-plan-save.sh approve <slug>` | Plan is final; schema gate fires (PSK024-N/P/F/D/L) |
| `psk-plan-save.sh --validate-schema <slug>` | One-shot lint; no side effects |
| `psk-run-plan.sh start <slug>` | Begin execution; emits first SPAWN |
| `psk-run-plan.sh next [<slug>]` | Sub-agent returned; advance to next phase |
| `psk-run-plan.sh resume <slug>` | After interruption (rate-limit, machine switch); re-emits current SPAWN |
| `psk-run-plan.sh retry [<slug>]` | Sub-agent failed; same phase, fresh spawn, counter +1 |
| `psk-run-plan.sh status [<slug>]` | Inspect current phase, gate-pass markers, retry count |
| `psk-run-plan.sh --convert <slug>` | Legacy plan → schema-conformant (sub-agent task) |
| `psk-run-plan.sh --validate <slug>` | Schema lint without execution |
| `psk-run-plan.sh --health` | One-liner across all in-flight plans |
| `psk-run-plan.sh abort <slug>` | Abandon execution; marks plan `status: abandoned` |

## Edge cases

- **Multiple plans in flight.** `--health` lists all. Explicit `--slug <name>` required for `next` when >1 executing.
- **Retry counter reset.** `abort + start` resets the retry counter (intentional escape hatch). Document any abuse.
- **Gate references project files.** Gate command can `cd` into project subdirs; just ensure exit code propagates correctly.
- **Plan revision mid-execution.** Bumping `revision:` mid-execution is allowed; new phases append to the array, completed phases keep their gate-pass markers.
- **Schema evolution.** `schema_version: 1` is the current version. Future bumps will document migration path; driver refuses unknown versions.

## Cross-references

- Flow doc: [`docs/work-flows/26-plan-execution-protocol.md`](../../docs/work-flows/26-plan-execution-protocol.md)
- Framework rule: `portable-spec-kit.md` §Plan Execution Protocol (5th reliability layer)
- Parent layer: `portable-spec-kit.md` §Workflow Fidelity (4th reliability layer)
- Template: [`.portable-spec-kit/templates/plan-executable.md`](../templates/plan-executable.md)
- Sync-check rule: PSK024 in `agent/scripts/psk-sync-check.sh`
- Driver source: `agent/scripts/psk-run-plan.sh`
- Save script: `agent/scripts/psk-plan-save.sh`
