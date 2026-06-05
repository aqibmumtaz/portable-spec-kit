# Instruction Fidelity — Flow Doc 32 (v0.6.81+, generic; v0.6.79 narrow)

> **Purpose:** Document the 11th reliability layer — §Instruction Fidelity.
> Every agent in the kit (main agent, sub-agent, sub-sub-agent at any spawn depth) executes the user's stated instruction exactly — no expanded scope, no reduced scope, no changed form, no reordered defaults, no substituted preference.

## Overview

| Field | Value |
|---|---|
| Layer number | 11 |
| Generic scope | Every agent-user interaction, at every spawn depth |
| Narrow predecessor | v0.6.79 §Command Invocation Fidelity (KIT-GAP-0059) — generalized to §Instruction Fidelity in v0.6.81 (KIT-GAP-0061) |
| Framework rule | `portable-spec-kit.md` §Instruction Fidelity |
| Primary rule (generic) | `instruction-fidelity-honor-exact-scope` in `.portable-spec-kit/kit-rules.yml` |
| Mechanical sub-rules | `canonical-autoloop-resume` · `in-progress-detection` (more added per surface) |
| Initial mechanical surface | `reflex/run.sh` pre-flight check |
| Future surfaces | Any long-running canonical command earning its own pre-flight per the retrofit guide below |
| Driving failure | Every prior fidelity layer gates agent-vs-kit; the missing one was agent-vs-user. The 2026-06-04 cycle-26/27/28 fresh-`--loop` deviation was one specific instance of the broader class. |
| Related layers | §Workflow Fidelity (4th, hybrid mechanical + behavioral, same pattern); §Sub-Agent Prompt Fidelity (9th, enforces rule citation by sub-agents); §Kit Fidelity (8th, gates canonical command form) |

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ User issues an instruction                                  │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ Main agent reads it:                                        │
│   ambiguous?  -> ASK, wait for clarification                │
│   better way? -> PROPOSE, wait for authorization            │
│   clear?      -> execute EXACTLY                            │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ Agent executes (Layer 11 generic principle):                │
│   scope honored? (no expansion / no reduction)              │
│   form honored?  (verb + sequence match)                    │
│   defaults honored? (canonical unless authorized)           │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ Mechanical sub-case (long-running command):                 │
│   per-script pre-flight reads in-progress state             │
│   state present + no continuation flag -> REFUSE 5          │
│   else -> continue                                          │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ Sub-agent spawn (Layer 9 cross-reference):                  │
│   psk-prompt-lint enforces verbatim rule citation           │
│   cited      -> spawn proceeds                              │
│   not cited  -> psk-spawn.sh refuses (exit 4)               │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ Post-facto: PSK044 sync-check audits patterns               │
│   surfaces deviation advisory (configurable)                │
└─────────────────────────────────────────────────────────────┘

```

## Key Rules

- **Generic principle is universal.** Layer 11's contract applies to every agent-user interaction at every spawn depth, regardless of surface, command type, or interaction shape. Any deviation from the user's exact instruction is a Layer 11 violation regardless of how it was rationalized. The principle is stated once, generically, in the kit-rules manifest as `instruction-fidelity-honor-exact-scope`.
- **Ambiguity is resolved by asking, not by guessing.** When the user's instruction is ambiguous, the agent asks for clarification before executing. The agent does not infer scope, form, or sequence from context — it asks.
- **Disagreement is resolved by proposing, not by silently substituting.** When the agent believes a different approach is better, the agent proposes the alternative and waits for the user's authorization. The agent does not silently execute the alternative.
- **Mechanical sub-cases ship per-surface.** Where a deviation pattern can be detected mechanically (e.g. fresh `--loop` while `.active-cycle` pin exists), the kit ships a pre-flight check at the script entry that refuses the deviating invocation. Sub-cases are implementations of the generic principle, not the principle itself.
- **Sub-agent prompts cite the rule verbatim.** Every sub-agent prompt that interprets user intent MUST cite `instruction-fidelity-honor-exact-scope` via `kit_rule_citations:` frontmatter with verbatim body text. Layer 9's PSK042 sync-check enforces verbatim citation; psk-spawn.sh refuses spawns with non-compliant prompts.
- **Bypass requires explicit user authorization, not agent inference.** Mechanical pre-flights bypass via documented env var (e.g. `REFLEX_FORCE_NEW_CYCLE=1`) — logged to `agent/.bypass-log` per PSK027. Behavioral bypass requires the user to explicitly authorize the scope expansion, form change, or default override in conversation. The agent never infers authorization from silence or context.

## Behavioral sub-case (the generic principle)

The behavioral sub-case is what makes Layer 11 generic. Every interaction where the agent reads a user instruction and decides how to execute is gated by `instruction-fidelity-honor-exact-scope`. The rule body is the contract; verbatim citation in sub-agent prompts ensures every agent at every depth sees the contract before deciding.

Common deviation patterns the behavioral sub-case closes (illustrative, not exhaustive):

- **Scope expansion.** Agent does more than the user asked. Examples include fixing nearby issues, refactoring unrelated code, adding "improvements" the user did not request.
- **Scope reduction.** Agent does less than the user asked. Examples include skipping steps the user explicitly listed, running a subset when the user said "all", marking incomplete work as done.
- **Form change.** Agent executes a different verb than the user used. Examples include committing-and-pushing when the user said "commit", rewriting a file when the user said "edit one line", implementing when the user said "verify" or "plan".
- **Default reordering.** Agent picks a non-canonical default. Examples include picking `single` mode when autoloop is the canonical default, picking `refresh` when `prepare` is canonical, picking partial subset when the canonical execution runs all suites.
- **Preference substitution.** Agent silently uses its own preference over the user's stated choice. Examples include swapping a tool, library, file path, or approach without asking.

Each pattern is the same generic violation: the agent executed something other than the user's exact instruction. The kit catches mechanical instances at the script entry; behavioral instances are caught by the rule-citation contract enforced via Layer 9.

## Mechanical sub-case (currently covered surfaces)

### `reflex/run.sh` autoloop pre-flight (v0.6.79+)

Detects `agent/.workflow-state/.active-cycle` pin or `agent/.release-state/loop-state.yml` at startup. If `--loop` (or alias forms) is invoked without `--resume` AND in-progress state exists, refuses with actionable banner + exit 5.

| Knob | Default | What it does |
|---|---|---|
| `REFLEX_FORCE_NEW_CYCLE=1` | (env var) | Bypass pre-flight; explicit operator intent for genuine new cycle |
| `PSK_PSK044_TOLERANCE=<n>` | 2 | Sync-check tolerance for cycles with only pass-001 across last 5 |
| `PSK_PSK044_DISABLED=1` | (env var) | Bypass PSK044 sync-check |

Verbatim rule citation: `canonical-autoloop-resume` + `in-progress-detection` — both are mechanical sub-cases of `instruction-fidelity-honor-exact-scope`.

### Adding a new mechanical sub-case (retrofit guide)

When adding a Layer 11 pre-flight to a new long-running canonical command:

1. **Identify the in-progress state file(s).** Each long-running command has at least one — the file that tells the command "you're in the middle of something, resume don't restart." Examples include `agent/.workflow-state/.active-cycle` for reflex, `agent/.release-state/release.state` for releases.

2. **Add a pre-flight check at the top of the script** (after argument parsing, before any side effects). Pattern:

   ```bash
   IN_PROGRESS_FILE="$PROJ_ROOT/<path-to-state-file>"
   if [ "$MODE" = "<canonical-invocation>" ] \
      && [ "${<BYPASS_ENV_VAR>:-0}" != "1" ] \
      && [ -f "$IN_PROGRESS_FILE" ]; then
     echo "✗ §Instruction Fidelity — refusing fresh <command> with in-progress state" >&2
     echo "  In-progress state file: $IN_PROGRESS_FILE" >&2
     echo "  Canonical continuation: bash <command> <continuation-flag>" >&2
     echo "  Bypass for genuine new run: <BYPASS_ENV_VAR>=1" >&2
     exit 5
   fi
   ```

3. **Document the bypass env var** in the command's `--help` output and ensure it's logged to `agent/.bypass-log` per PSK027.

4. **Add a kit-rules.yml entry** as a mechanical sub-case of `instruction-fidelity-honor-exact-scope`. Sub-agent prompts that reference the command cite the sub-case rule.

5. **Add a PSK rule to sync-check** if there's a detectable post-facto pattern (like PSK044's "cycle-N pass-001 only" for reflex).

6. **Add a regression test** in `tests/sections/96-instruction-fidelity.sh` covering the new pre-flight.

## Cross-references

- `portable-spec-kit.md` §Instruction Fidelity (framework rule)
- `.portable-spec-kit/kit-rules.yml` rule `instruction-fidelity-honor-exact-scope` (generic principle) + sub-cases `canonical-autoloop-resume` + `in-progress-detection` (mechanical implementations)
- `agent/scripts/psk-sync-check.sh` `check_psk044_command_invocation_fidelity()` (post-facto pattern detection — first mechanical surface)
- `reflex/run.sh` pre-flight check insertion (first mechanical implementation)
- §Sub-Agent Prompt Fidelity (Layer 9) enforces verbatim citation of the generic principle by all sub-agent prompts
- `agent/.kit-gap-log` KIT-GAP-0059 (narrow Layer 11 v0.6.79) + KIT-GAP-0061 (generic Layer 11 v0.6.81)
- `tests/sections/96-instruction-fidelity.sh` (regression suite)
- `agent/plans/2026-06-04-instruction-fidelity-generalization.md` (executable plan that shipped v0.6.81)

## Bypass log discipline

Every bypass — mechanical (`REFLEX_FORCE_NEW_CYCLE=1`, `PSK_PSK044_DISABLED=1`) or behavioral (`PSK_PROMPT_FIDELITY_DISABLED=1`) — is logged to `agent/.bypass-log` per PSK027. WARNING at 1-2 bypasses in 24h, ERROR at 3+ in 24h, stronger ERROR at 10+ in 7d. If the operator finds themselves bypassing repeatedly, the friction is the spec — per §Kit Fidelity, file a `KIT-GAP-*` entry and either fix the underlying issue or escalate, rather than continuing to bypass.

## Why Layer 11 is generic (and Layer 8 §Kit Fidelity is not)

| Layer | What it gates |
|---|---|
| §Kit Fidelity (8th) | Choice of flag form for kit commands (canonical `prepare` vs non-canonical `refresh`, etc.). Operator-vs-kit. |
| §Instruction Fidelity (11th) | Whether the agent executes the user's exact instruction at all, in any form, at any depth. Agent-vs-user. |

The two layers compose. §Kit Fidelity ensures the agent picks the right canonical form when invoking a kit command. §Instruction Fidelity ensures the agent invokes only what the user asked for in the first place, with the right scope and form. Together with §Sub-Agent Prompt Fidelity (Layer 9), the kit catches deviation at three boundaries: flag choice (Layer 8), prompt content (Layer 9), and execution scope/form (Layer 11).
