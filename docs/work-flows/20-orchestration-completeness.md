# Workflow 20 — Orchestration Completeness (Phase 6.5)

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

## See also

- [doc 18 — Project Orchestration](18-project-orchestration.md) — full 10-phase pipeline, Phase 6.5 in context
- [doc 19 — Kit ↔ Project Evolution Loop](21-kit-project-evolution-loop.md) — how findings surfaced in user projects flow back into kit improvements
- `portable-spec-kit.md` §Reflex Finding Classification — Dim 25 + 8 gates registration
- `reflex/lib/mandate-audit.sh` — the probe itself (read for the canonical mandate list)
