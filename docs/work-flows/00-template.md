# Flow: [Workflow Name] — TEMPLATE

> **Purpose:** One sentence describing what this workflow does and when it runs.
> **Trigger:** What user command, script invocation, or lifecycle event starts this workflow.
> **Enforced by:** Which script / hook / gate runs this flow.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | User says `"..."` / script `bash agent/scripts/foo.sh` / lifecycle event |
| **Inputs** | Files or state consumed (e.g., `agent/SPECS.md`, `agent/TASKS.md`) |
| **Outputs** | Files or state produced (e.g., updated `RELEASES.md`, bumped version) |
| **Script** | `agent/scripts/psk-foo.sh` (if applicable) |
| **Gate** | Sync-check PSKxxx, dual critic, pre-commit hook |
| **When blocked** | Condition that causes this workflow to halt or fail |

---

## Flow Diagram

> **Format rules:** ASCII boxes only — no mermaid, no HTML. Box borders: `┌─`, `└─`, `├─`, `┤`. Vertical connector: `│`. Step connector: `▼` (centered). Decision fork: `├─ YES →` / `└─ NO →`. Inline labels: `(automated)`, `(agent)`, `(config-gated)`. Each box describes one discrete step.

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: FIRST STEP NAME (automated / agent / config-gated) │
│     Brief description of what this step does.               │
│     bash agent/scripts/script-name.sh                       │
│     FAIL → what happens on failure                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 2: SECOND STEP NAME (automated)                       │
│     Description.                                            │
│     FAIL → action or bypass (PSK_XYZ_DISABLED=1)            │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────▼──────────────┐
         │  DECISION: condition?       │
         ├─ YES → proceed to Step 3   │
         └─ NO → exit / skip / warn   │
         └────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 3: FINAL STEP NAME (agent + critic)                   │
│     Description.                                            │
│     Sub-agent critic verifies. Loop until pass.             │
└─────────────────────────────────────────────────────────────┘
```

---

## Steps

| Step | Type | What happens |
|------|------|-------------|
| 1 | Automated | Script runs directly. Agent acts only if failures. |
| 2 | Agent | Agent does work. No critic. |
| 3 | Agent + critic | Agent does work. Sub-agent critic verifies. Loop until pass. |

---

## Key Rules

- **Rule 1:** One-sentence rule that must always hold (e.g., "Never commit without tests passing").
- **Rule 2:** Another invariant or behavioral constraint.
- **Rule 3:** Config gate or bypass rule if applicable.

---

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| Precondition not met | Fail-fast with specific error message before any state changes |
| Partial state from prior run | Detect and resume / refuse and prompt user |
| User bypasses gate | Log to bypass-audit file; surface warning at next release |
| Dry run / no-op | Describe what happens when workflow finds nothing to do |

---

## Related Flows

- [NN-related-workflow.md](NN-related-workflow.md) — one-line description of relation
- [MM-other-workflow.md](MM-other-workflow.md) — one-line description of relation

---

<!-- TEMPLATE USAGE NOTES (remove from actual workflow docs)

SECTIONS REQUIRED BY PSK019:
  ## Overview       — table with Trigger, Inputs, Outputs, Script, Gate, When blocked
  ## Flow Diagram   — ASCII boxed diagram (no mermaid; code-fenced with backticks)
  ## Key Rules      — bullet list of invariants

SECTIONS RECOMMENDED (omit only when genuinely not applicable):
  ## Steps          — step-type table (Automated / Agent / Agent+critic)
  ## Edge Cases     — situation/behavior table
  ## Related Flows  — links to related workflow docs

BOX FORMAT SPECIFICATION:
  ┌─ ... ─┐   top border
  │  ...  │   content lines (indent 2 spaces inside border)
  └─ ... ─┘   bottom border (bottom-left → connector)
  ┌──────────▼──────────┐   connector from prior box (▼ centered)

DECISION FORK FORMAT:
         ┌─────────────▼──────────────┐
         │  DECISION: <condition>?     │
         ├─ YES → <action>            │
         └─ NO →  <action>            │
         └────────────────────────────┘

INLINE STEP LABELS:
  (automated)       script runs with no agent intervention
  (agent)           agent does the work
  (agent + critic)  agent + sub-agent critic loop
  (config-gated)    only runs when config toggle enabled

FAILURE LINES INSIDE BOXES:
  FAIL → <action or bypass>
  Bypass: <env-var or flag>

WIDTH: target 63 chars inside box borders for consistent alignment.

-->
