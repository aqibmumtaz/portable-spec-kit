# 19 — Kit Evolution Gauntlet

> **Workflow doc** for the Self-Evolution Regression Gauntlet shipped in kit v0.6.22 (Phase 6 of the self-evolving plan, per ADR-033).
>
> Audience: kit maintainer evolving the kit. Not a user-project workflow.

---

## Purpose

Every proposed kit rule, principle mutation, ADR, or skill change must clear a 6-gate gauntlet before merging. The gauntlet is the structural enforcement layer that prevents kit-evolution drift — it stops new rules from contradicting old rules, violating principles, or breaking existing functionality.

This workflow is **only** triggered when the kit itself is being evolved. Routine project work (features, bug fixes, doc updates) does NOT pass through the gauntlet.

---

## When to use

Trigger the gauntlet for any of these kit-level changes:

| Change type | Example | Gauntlet required? |
|---|---|---|
| New MANDATORY rule in `portable-spec-kit.md` | "agent MUST emit breadcrumb on every reply" | **Yes** |
| New / retired principle in `agent/PHILOSOPHY.md` | Add P9 / retire P3 | **Yes** |
| New skill or major skill rewrite | New `.portable-spec-kit/skills/foo.md` | **Yes** |
| New ADR shifting kit philosophy or stack | ADR-035 mandates a different test framework | **Yes** |
| New `psk-*.sh` script that other workflows depend on | New release-step helper | **Yes** |
| Bug fix in existing script (no behavior change) | Fix awk parsing in `psk-sync-check.sh` | No (regression test in `tests/sections/` is enough) |
| Doc-only change (README, RELEASES, CHANGELOG) | Version bump notes | No |

When in doubt, run the gauntlet. It is fast (<2min in `--quick` mode) and the cost of a regression is much higher than the cost of running the gates.

---

## The 6 gates (A–F)

```
Proposed rule (in agent/tasks/proposed/<Pxx|Gxx>-name.md)
  │
  ├─► Gate A — Test suite green
  │   `bash tests/test-spec-kit.sh && bash tests/test-spd-benchmarking.sh`
  │   All 1836 tests still pass after the proposed change?
  │
  ├─► Gate B — No new rule conflicts
  │   `bash agent/scripts/psk-rule-conflicts.sh --json`
  │   conflict_count must not increase from baseline.
  │
  ├─► Gate C — Philosophy consistency
  │   Cross-check the change against PHILOSOPHY.md.
  │   No active principle is violated. If P-mutation, gauntlet logs the
  │   mutation in the file's "Mutation history" section.
  │
  ├─► Gate D — Reflex fixture still GRANTED (heavy)
  │   Run `bash reflex/run.sh single` against a known-good fixture
  │   project. Verdict must remain GRANTED. Skippable in `--quick`
  │   mode for iterations; final landing requires Gate D pass.
  │
  ├─► Gate E — /optimize health stays green or yellow
  │   `bash agent/scripts/psk-optimize.sh --health`
  │   Status must not regress to 🔴 stale. Cat 10/11/12 counts must
  │   not increase relative to baseline.
  │
  └─► Gate F — Manual author approval (NEVER auto-passable)
      Kit author reads the proposal + gauntlet report and types
      `APPROVED` to land. The non-interactive flag DEFERS this gate
      rather than passing it — Gate F is the human-in-the-loop
      safeguard that prevents fully-automated rule landing.
```

---

## End-to-end flow

```
1. Author drafts the proposal — agent/tasks/proposed/<Pxx|Gxx>-name.md.
   Format: title, motivation, the rule text, expected impact, risk
   notes, rollback plan.

2. Run the gauntlet:
   bash agent/scripts/psk-evolution-gauntlet.sh agent/tasks/proposed/Pxx-name.md

3. Gauntlet runs gates A → B → C → D → E in order, halts on first
   failure. Reports per-gate result inline.

4a. ALL GATES PASS → gauntlet pauses at Gate F:
    - Prints proposal summary + gates report
    - Prompts: "APPROVED to land? [y/N]"
    - On y: instructions to commit the proposal-driven kit change
    - On N or non-interactive: Gate F DEFERRED — author lands later

4b. ANY GATE FAILS → proposal moves to agent/tasks/rejected/:
    - Original proposal file moves to rejected/<Pxx|Gxx>-name.md
    - Gauntlet appends a "Gate <X> failed: <reason>" rationale
    - Author can either (i) revise the proposal and re-run the
      gauntlet from step 2, or (ii) leave the rejection as a
      permanent record of "why not"

5. Post-merge soak (v0.6.25+, ADR-035) — 48h after a proposal lands
   the `.github/workflows/postmerge-gauntlet-soak.yml` cron runs daily
   at 09:00 UTC, scans main for `[proposal: ...]` commits in the
   9-to-2-day window, and re-runs `psk-evolution-gauntlet.sh` on each
   via `agent/scripts/psk-soak-schedule.sh --quick`. Failures auto-file
   `revert-<Pxx|Gxx>` tasks under TASKS.md backlog and open a labelled
   GitHub issue. Manual single-proposal soak:
   `gh workflow run postmerge-gauntlet-soak.yml -f proposal=Pxx-name`
   or `bash agent/scripts/psk-soak-schedule.sh --proposal Pxx-name`.
   Bypass `PSK_SOAK_DISABLED=1` for genuine CI emergencies only.
```

---

## Proposal file format

```markdown
# Pxx — <Short rule title>  (or Gxx for kit-finding-driven proposals)

**Status:** proposed
**Author:** <name>
**Date:** YYYY-MM-DD

## Motivation
Why this rule should exist. Cite the gap or incident that prompted it.

## The rule
The exact text that will land in portable-spec-kit.md / a skill / an ADR.
Verbatim — no paraphrasing.

## Expected impact
Which kit surfaces are affected. Which existing rules does this
interact with? Any rule it implicitly supersedes?

## Risk notes
What could go wrong. False-positive class. Performance impact. Side
effects on user projects.

## Rollback plan
How to back this out if the 48h soak surfaces a regression.

## Gauntlet history
(Filled by the gauntlet on each run — date, gates passed/failed, notes.)
```

---

## Bypass / emergency overrides

Per-gate disable env vars exist for genuine CI emergencies — they are NOT routine workflow:

| Env var | Disables |
|---|---|
| `PSK_GAUNTLET_QUICK=1` | Skip Gate D (Reflex fixture — heavy). Recommended during proposal iteration. Final landing must pass Gate D. |
| `PSK_GAUNTLET_GATE_F_DISABLED=1` | Skip Gate F (manual approval). CI-emergency only. Logs a warning. |

The kit philosophy is: **gates exist to be passed, not bypassed.** Frequent bypass = the gate is wrong, not the bypass.

---

## Cross-references

- **ADR-033** in `agent/PLANS.md` — full design rationale for the gauntlet.
- **`agent/scripts/psk-evolution-gauntlet.sh`** — the orchestrator script.
- **`agent/PHILOSOPHY.md`** — the principles Gate C reasons against.
- **`agent/scripts/psk-rule-conflicts.sh`** — Gate B's deterministic backbone.
- **`reflex/run.sh`** — Gate D's fixture audit driver.
- **`tests/sections/04-reflex.sh`** — N78 regression test for the gauntlet itself.

---

## What this is NOT

- Not a code reviewer — Gate A handles tests, but the gauntlet does not lint or critique proposed code style.
- Not a linter — formatting / whitespace / naming is enforced by the existing pre-commit hook, not the gauntlet.
- Not a way to bypass the regression test gate — Gate A IS the test gate.
- Not auto-approval — Gate F never auto-passes. Human in the loop is structural.
