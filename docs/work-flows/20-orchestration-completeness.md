# Workflow 20 — Orchestration Completeness (Phase 6.5)

## Overview

| Field | Value |
|---|---|
| **Trigger** | Automatically fired by `psk-orchestrate.sh` between Phase 6 (scaffold) and Phase 7 (feature loop) · also fires after every Dev-Agent fix during Reflex via the 8th mechanical gate |
| **Inputs** | Scaffolded project tree · `portable-spec-kit.md` mandate list · `reflex/lib/mandate-audit.sh` |
| **Outputs** | Structured JSON findings with severity (MAJOR / MINOR / ADVISORY) · Phase 7 blocked when any MAJOR finding is open · MINOR findings advisory-appended to `agent/TASKS.md` |
| **Script** | `reflex/lib/mandate-audit.sh` (probe) · `reflex/lib/orchestration-phase-6-5.sh` (Phase 6.5 runner) |
| **Gate** | 8th mechanical gate in `reflex/lib/gates.sh` — blocks on MAJOR (configurable via `mandate_compliance_block_severity` in `reflex/config.yml`) |
| **When blocked** | Any MAJOR mandate finding open at Phase 6.5 → Phase 7 cannot start · Any MAJOR finding introduced by a Dev-Agent fix → 8th gate blocks the commit |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  PHASE 6 COMPLETE — Secure scaffold landed                  │
│     src/ · auth · middleware · CI · .env.example            │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  PHASE 6.5: MANDATE-AUDIT PROBE (automated)                 │
│     reflex/lib/mandate-audit.sh runs against project root   │
│     Checks: required dirs · pipeline files · source-layout  │
│     per-feature design plans · ARD docs · README badges     │
│     .env.example hygiene · CI workflow content              │
│     Emits: JSON findings per mandate with severity          │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────▼──────────────┐
         │  DECISION: MAJOR findings?  │
         ├─ YES → block Phase 7       │
         │   agent fixes gaps, reruns  │
         └─ NO  → proceed to Phase 7  │
         └────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  PHASE 7: FEATURE LOOP (agent)                              │
│     Feature implementation begins only with clean mandate   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  REFLEX PASSES — 8th GATE FIRES AFTER EVERY DEV FIX         │
│     gates.sh invokes mandate-audit.sh after each commit     │
│     MAJOR regression from a Dev fix → commit blocked        │
│     Same probe, three trigger points (scaffold · QA · fix)  │
└─────────────────────────────────────────────────────────────┘
```

---

## Why completeness is part of orchestration's contract, not QA's safety net

The kit's project-orchestration pipeline (Phases 1–10, see [doc 18](18-project-orchestration.md)) ends with a Reflex audit (Phase 8) that surfaces gaps. Until Loop-Iter-2, that meant any *structural* gap — a missing `ard/` directory, an absent stack manifest, a feature shipped without a design plan — was caught only after features had already landed. Backfilling those gaps mid-feature-cycle is expensive: every feature commit potentially needs revision, every test revisited, every doc cross-checked.

The completeness contract reframes the mandate set as orchestration's responsibility, not QA's. Phase 6.5 fires *between* the secure scaffold (Phase 6) and the feature loop (Phase 7), so a missing mandate is caught while only the scaffold exists — no features yet to revise. QA still surfaces the same class of gaps via Dim 25, but as a regression detector, not the primary discovery mechanism.

## The mandate-audit probe + 8th gate as the structural mechanism

Two structural pieces realize the contract:

- **`reflex/lib/mandate-audit.sh`** — pure-bash probe that walks the target project against the mandates declared in `portable-spec-kit.md` (required directories, pipeline files, source-layout sanity, per-feature design plans, ARD docs, README badge currency, `.env.example` hygiene, CI workflow content). Emits structured JSON findings with severity (`MAJOR` / `MINOR` / `ADVISORY`).
- **8th mechanical gate in `reflex/lib/gates.sh`** — invokes the same probe after every Dev-Agent fix. Blocks at `MAJOR` by default (configurable via `reflex/config.yml` `mandate_compliance_block_severity`). Prevents regressions: a Dev fix that closes one finding cannot silently introduce a new mandate gap.

Phase 6.5 (orchestration), Dim 25 (QA), and the 8th gate (Reflex post-fix) form a triangle. Same probe, three trigger points, three different lifecycle stages — scaffold-time, audit-time, fix-time. Each catches the same class of regression at a different cost point.

## Loop Iteration 2 as the genesis of this discipline

Loop-Iter-2 (the autoloop pass that produced searchsocialtruth) shipped its first reflex pass with a project that had no `ard/`, no `docs/`, and no `src/` consolidation — gaps the kit's mandates required but no orchestration step actively verified. QA-Agent caught them at cycle-05 — six features in. Phase F of Loop-Iter-2 closed that gap class structurally:

- Phase F1 — `mandate-audit.sh` probe authored
- Phase F2 — Dim 25 registered in `reflex/prompts/qa-agent.md`
- Phase F3 — 8th mechanical gate added to `reflex/lib/gates.sh`
- Phase F4 — regression test `tests/sections/05-mandate-compliance.sh`
- Phase F5 — Dim 25 + 8 gates registered in `portable-spec-kit.md`
- Phase G1–G3 — Phase 6.5 added to orchestration skill, wired into `psk-orchestrate.sh`, this flow doc

After Phase G, no orchestration run can cross from scaffold into feature impl while a `MAJOR` mandate finding stands.

## Key Rules

- **Phase 6.5 is non-optional in orchestration:** the mandate-audit probe fires between scaffold and feature loop on every `psk-orchestrate.sh` run. No flag exists to skip it — Phase 7 cannot start while a MAJOR finding is open.
- **Same probe, three trigger points:** `mandate-audit.sh` runs at scaffold-time (Phase 6.5), audit-time (Reflex Dim 25 via QA-Agent), and fix-time (8th gate after every Dev-Agent commit). Each catches the same class of regression at a different cost point.
- **MAJOR blocks, MINOR advises:** MAJOR findings block Phase 7 and the 8th gate. MINOR findings are appended to `agent/TASKS.md` as advisory items. ADVISORY findings are informational only. Block severity is configurable via `mandate_compliance_block_severity` in `reflex/config.yml`.
- **Backfilling mid-feature-cycle is expensive:** the design intent is to catch structural gaps while only the scaffold exists. A missing `ard/` or absent stack manifest caught at Phase 6.5 requires fixing one file; the same gap caught at cycle-05 (six features in) requires revisiting every feature commit and doc cross-reference.
- **QA Dim 25 is the regression detector, not the primary discovery mechanism:** after Phase 6.5 lands, Dim 25 confirms no regressions crept in during feature implementation. If Dim 25 catches a mandate gap that Phase 6.5 missed, that is a bug in `mandate-audit.sh` — file it as a kit finding.

---

## See also

- [doc 18 — Project Orchestration](18-project-orchestration.md) — full 10-phase pipeline, Phase 6.5 in context
- [doc 19 — Kit ↔ Project Evolution Loop](21-kit-project-evolution-loop.md) — how findings surfaced in user projects flow back into kit improvements
- `portable-spec-kit.md` §Reflex Finding Classification — Dim 25 + 8 gates registration
- `reflex/lib/mandate-audit.sh` — the probe itself (read for the canonical mandate list)
