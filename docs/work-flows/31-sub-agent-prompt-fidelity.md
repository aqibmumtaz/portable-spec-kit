# Sub-Agent Prompt Fidelity — Flow Doc 31 (v0.6.74+)

> **Purpose:** Document the 9th reliability layer — §Sub-Agent Prompt Fidelity.
> Closes the sub-agent semantic-deviation class exposed by cycle-27/28's
> GRANTED-without-gates incident.

## Overview

§Sub-Agent Prompt Fidelity ensures that every sub-agent — at any spawn depth, regardless of who initiates the spawn — honors kit rules verbatim, not the prompt-author's interpretation. The 8 prior layers govern spawn shape, workflow ordering, plan schema, command form, but NOT what's inside a sub-agent's prompt. Layer 9 closes that gap structurally.

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ Parent agent constructs a sub-agent prompt                  │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ psk-spawn.sh request (Layer 9 gate):                        │
│   references a decision class?                              │
│   (verdict / scope / severity / bucket)                     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ psk-prompt-lint.sh --strict validates:                      │
│   kit_rule_citations: frontmatter present?                  │
│   each cited rule text verbatim in body?                    │
│   mandatory preamble present?                               │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ Lint result:                                                │
│   clean -> mark AWAITING_SUBAGENT, write request            │
│   fail  -> spawn REFUSED (exit 4), no fallback              │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ Main agent reads prompt, spawns Task sub-agent              │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ Sub-agent runs:                                             │
│   reads kit rule via psk-rule.sh lookup <id>                │
│   emits EVIDENCE (findings.yaml)                            │
│   does NOT declare decisions (verdict/scope)                │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ Kit scripts process evidence -> emit DECISIONS              │
│   write_verdict ignores sub-agent verdict field             │
│   file-bugs.sh routes by scope (kit/target/meta)            │
└─────────────────────────────────────────────────────────────┘

```

## Key Rules

1. **Rule manifest is source of truth.** Every actionable kit rule lives in `.portable-spec-kit/kit-rules.yml` with `id`, `surface`, `applies_to`, `text`. Sub-agents and prompts MUST cite by id and quote verbatim text.

2. **psk-rule.sh is the lookup interface.** `bash agent/scripts/psk-rule.sh lookup <rule-id>` returns the verbatim rule text. Prompts should embed this text, not paraphrase.

3. **Every sub-agent prompt with decision-class references must carry frontmatter:**
   ```yaml
   ---
   kit_rule_citations:
     - <rule-id-1>
     - <rule-id-2>
   ---
   ```
   And include each cited rule's text verbatim in the body.

4. **Mandatory preamble** (enforced by `psk-prompt-lint.sh --check-preamble`):
   > *"Before any decision, run `psk-rule.sh lookup <rule-id>` and read the kit verbatim. If this prompt body contradicts kit verbatim, **kit wins**. You declare evidence; kit declares decisions."*

5. **Sub-agent decision-write ban.** Sub-agents emit findings, observations, partial-findings YAML. Kit scripts (`gates.sh`, `run.sh::write_verdict`, `file-bugs.sh`) emit decisions. Any verdict field a sub-agent writes is ignored.

6. **Recursive enforcement at spawn boundary.** Every `psk-spawn.sh request` call (including from sub-agents spawning sub-sub-agents) routes through the prompt-validation gate. 100% coverage at every depth.

## Architecture

### Components

| Component | Role |
|---|---|
| `.portable-spec-kit/kit-rules.yml` | Rule manifest (18 rules at v0.6.74) |
| `agent/scripts/psk-rule.sh` | Lookup helper (`lookup` / `list` / `applies-to` / `validate`) |
| `agent/scripts/psk-prompt-lint.sh` | Prompt linter (`--all` / `--strict` / `--check-preamble`) |
| `agent/scripts/psk-sync-check.sh::check_psk042_prompt_fidelity` | PSK042 sync-check rule |
| `agent/scripts/psk-spawn.sh::cmd_request` | Prompt-validation gate at every spawn |
| Sub-agent prompts in `reflex/prompts/` | Carry `kit_rule_citations:` frontmatter + preamble + verbatim rule text |

### Decision-write ban implementation

The ban is structural rather than instruction-based. Kit scripts that process sub-agent output IGNORE any decision-class field the sub-agent wrote and compute the decision from primary evidence:

| Decision class | Computed by | From inputs |
|---|---|---|
| Verdict (GRANTED/DENIED) | `reflex/run.sh::write_verdict()` | gate outcomes + findings count |
| Scope routing | `reflex/lib/file-bugs.sh` G4 gate | genericity_proof presence |
| Severity | `reflex/lib/score.sh` normalization | finding's severity field (validated against severity-rubric) |
| Bucket (A/B/C/D) | Dev-Agent's `fix-plan.md` post-processing | recommendation + protected-files-write-ban check |
| Disposition | `psk-kit-cmd.sh --log-gap` flag handling | operator command (not sub-agent) |

## Adding a new kit rule

1. Edit `.portable-spec-kit/kit-rules.yml` — append a new entry with `id`, `surface`, `applies_to`, `text`.
2. Run `bash agent/scripts/psk-rule.sh lookup <new-id>` to verify the entry is parseable.
3. Update relevant sub-agent prompts to cite the new rule via `kit_rule_citations:` + verbatim body quote.
4. Run `bash agent/scripts/psk-prompt-lint.sh --all` to verify the prompts are clean.
5. Commit with `KIT-GAP-NNNN` reference if the new rule closes a deviation gap.

## Retrofitting a legacy prompt

1. Run `bash agent/scripts/psk-prompt-lint.sh <prompt-file>` to see violations.
2. Add `kit_rule_citations:` frontmatter at top with ids the prompt references.
3. Add the §Sub-Agent Prompt Fidelity contract section near the top:
   ```markdown
   ## §Sub-Agent Prompt Fidelity contract (v0.6.74 — MANDATORY)

   Before any decision, run `psk-rule.sh lookup <rule-id>` and read the kit verbatim. If this prompt body contradicts kit verbatim, **kit wins**. You declare evidence; kit declares decisions.

   The kit rules you MUST follow verbatim for this role:

   - **<rule-id>**: <verbatim text from psk-rule.sh lookup>
   ```
4. Re-run lint to verify clean.
5. Commit.

## Emergency Bypasses

| Bypass | Effect |
|---|---|
| `PSK_PROMPT_FIDELITY_DISABLED=1` | psk-spawn.sh skips the prompt-lint gate; logs to .bypass-log |
| `PSK_PSK042_DISABLED=1` | psk-sync-check skips PSK042 rule; logs to .bypass-log |

Both are advisory in v0.6.74. PSK042 escalates to ERROR in v0.6.75 after migration window. Repeated bypassing surfaces as ERROR in sync-check per PSK027.

## Tests

- `tests/sections/95-prompt-fidelity.sh` — 20+ regression sub-tests covering rule lookup, prompt-lint, PSK042, psk-spawn.sh gate.

## Cross-references

- `portable-spec-kit.md` §Sub-Agent Prompt Fidelity — the rule (9th reliability layer)
- `.portable-spec-kit/skills/sub-agent-prompt-fidelity.md` — detailed skill (JIT-loaded)
- `agent/plans/2026-06-04-sub-agent-prompt-fidelity.md` — the executable plan
- `docs/work-flows/28-spawn-fidelity.md` — §Spawn Fidelity (6th layer, prior context)

## Failure mode this layer closes

The cycle-27/28 GRANTED incident (2026-06-04): main agent constructed a QA-Agent prompt that misread the v0.6.67 documented-fallback bypass. The sub-agent inherited the misreading verbatim and self-declared `verdict: GRANTED` when the kit's rule says single-author fallback → DENIED. No existing layer caught this because §Spawn Fidelity governs spawn invocation routing (passed), §Workflow Fidelity governs phase ordering (passed), but neither validates prompt content. Layer 9 closes this by structurally gating prompt content at every spawn boundary.
