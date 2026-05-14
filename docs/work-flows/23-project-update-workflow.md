# 23 — Project Update Workflow (`--update` mode)

**Added:** v0.6.47 · **Status:** canonical  
**Replaces:** manual cascade pattern (retired in v0.6.47)

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | `bash agent/scripts/psk-orchestrate.sh --update` (or with `PSK_PROJ_ROOT` / `PSK_KIT_ROOT` overrides) |
| **Inputs** | `.portable-spec-kit/config.md` (`kit_source_path`), `agent/SPECS.md` (feature list), existing project source |
| **Outputs** | Scripts refreshed, structural gaps filled (design plans, stubs, ARD, flow docs), version bumped, reflex GRANTED, `HANDOFF.md` written |
| **Script** | `agent/scripts/psk-orchestrate.sh --update` (runs phases U0–U10) |
| **Gate** | U9 reflex autoloop is mandatory — no skip path. U8 full release ceremony (10 steps) must pass before U9. |
| **When blocked** | Kit source unresolvable (`unknown`) → set `PSK_KIT_ROOT` env var and re-run. Reflex DENIED after safety cap → review `reflex/history/` and fix surfaced findings manually. |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  U0: kit-currency (automated)                               │
│     Sync agent/scripts/ from kit source (local or remote)   │
│     resolve_kit_root() reads config.md → kit_source_path    │
│     FAIL → set PSK_KIT_ROOT env var and re-run              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  U1–U2: structure-audit + reflex-install (automated)        │
│     mandate-audit.sh — surface MAJOR structural gaps        │
│     Auto-install reflex/ if missing                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  U3–U6: Gap filling (agent)                                 │
│     U3: design-plans — fill missing agent/design/f{N}-*.md  │
│     U4: feature-stubs — create tests/features/ R→F→T stubs  │
│     U5: ard-flow-docs — generate ARD + ensure ≥3 flow docs  │
│     U6: sync-check-config — write sync-check-config.md      │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────▼──────────────┐
         │  Any [ ] features remain?   │
         ├─ YES → U7: features         │
         └─ NO  → skip to U8           │
         └────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  U8: release-prep (agent + critic)                          │
│     Full 10-step release ceremony (psk-release.sh prepare)  │
│     Version bump · tests pass · dual critic gate            │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  U9: reflex-audit — MANDATORY (automated loop)              │
│     bash reflex/run.sh autoloop until GRANTED               │
│     No skip path — auto-installs reflex if missing          │
│     FAIL after safety cap → review reflex/history/          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  U10: final-handoff (agent)                                 │
│     Generate HANDOFF.md with update summary                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Purpose

Bring any existing kit-managed project to the current kit version, fill structural gaps (design plans, tests/features stubs, ARD docs, flow docs), and run reflex until GRANTED — all in a single orchestrated command.

This is the **only supported path** for updating a project. The manual cascade pattern (committing "cascade kit vX" messages by hand) is retired.

---

## Trigger

```bash
bash agent/scripts/psk-orchestrate.sh --update
# or: target a different project
PSK_PROJ_ROOT=/path/to/project bash agent/scripts/psk-orchestrate.sh --update
# or: set kit source explicitly
PSK_KIT_ROOT=/path/to/portable-spec-kit bash agent/scripts/psk-orchestrate.sh --update
```

---

## Phases (U0–U10)

| Phase | Name | What it does | Output |
|-------|------|-------------|--------|
| U0 | kit-currency | Sync `agent/scripts/` from kit source (local or remote) | Scripts refreshed |
| U1 | structure-audit | Run `mandate-audit.sh` — surface MAJOR gaps | JSON findings |
| U2 | reflex-install | Auto-install `reflex/` if missing | `reflex/run.sh` executable |
| U3 | design-plans | Fill missing `agent/design/f{N}-*.md` for all `[~]`/`[ ]` features | Design plans created |
| U4 | feature-stubs | Create `tests/features/` R→F→T anchor stubs per acceptance criterion | Stub files |
| U5 | ard-flow-docs | Generate `ard/technical-overview.html`; ensure ≥3 flow docs in `docs/work-flows/` | ARD + docs |
| U6 | sync-check-config | Create `.portable-spec-kit/sync-check-config.md` with `mode: project` | Config file |
| U7 | features | Implement remaining `[ ]` features (if any were requested) | Feature commits |
| U8 | release-prep | Full 10-step release ceremony (`psk-release.sh prepare`) | Version bump, tests pass |
| U9 | reflex-audit | **MANDATORY** `bash reflex/run.sh` autoloop until GRANTED | GRANTED verdict |
| U10 | final-handoff | Generate `HANDOFF.md` with update summary | HANDOFF.md |

---

## KIT_ROOT resolution (K1)

`install.sh` (v0.6.47+) writes three fields to `.portable-spec-kit/config.md` at install time:

```
kit_source_path: /path/to/portable-spec-kit  # or "remote" for curl installs
kit_version: v0.6.47
kit_installed_at: 2026-05-11
```

The orchestrator's `resolve_kit_root()` function reads `kit_source_path` from this config to locate the kit source without requiring user input. Resolution order:

1. `PSK_KIT_ROOT` env var — always wins
2. `.portable-spec-kit/config.md` → `kit_source_path` field (K1 — written by `install.sh` since v0.6.47)
3. Script location heuristic — `orchestrate.sh` parent's parent has `portable-spec-kit.md` as a real file (not symlink) AND has `install.sh` present (v0.6.49+: the `install.sh` check distinguishes a real kit from a user project that has a copied `portable-spec-kit.md`)
4. `remote` — curl-fetch reflex from GitHub (when installed via curl, not `--from`)

If resolution fails (`unknown`), the script prints an error with recovery instructions.

---

## Technical notes (K2–K7)

**K2 — Phase 9 mandatory reflex:** The reflex-audit phase (U9) has NO skip path. If `reflex/run.sh` is absent, the orchestrator auto-installs it via `resolve_kit_root()` before running. The convergence loop iterates until GRANTED.

**K3 — Design-plan and stub creation (U3/U4):** Phase U3 fills missing `agent/design/f{N}-*.md` for every `[ ]` and `[~]` feature in SPECS.md, even when the feature is already implemented. Phase U4 creates `tests/features/` anchor stubs per acceptance criterion. Both phases run unconditionally — the structural pipeline must be complete before the release ceremony (U8) begins. Stubs and design-plan paths are written to the SPECS.md Tests column and `agent/design/` index respectively.

**K4 — tests/features/ R→F→T stubs:** Phase U4 (feature-stubs) and U7 (features) both create `tests/features/test_f{N}_*.py` anchor stubs per acceptance criterion alongside runnable tests in `backend/tests/` (or stack equivalent). Both stub and runnable paths are written to the SPECS.md Tests column.

**K5 — Polyglot stack detection:** `mandate-audit.sh` detects `backend/`+`frontend/` projects and resolves them as `polyglot-python-node`. Mandates apply to both Python manifest in `backend/` and `package.json` in `frontend/` — no longer silently skipped on polyglot layouts.

**K6 — summary.csv GRANTED path:** `loop.sh`'s GRANTED terminator calls `score.sh` to write the summary row for the completed pass. Previously, self-test runs outside the loop did not produce a summary row. Cross-reference: see also U9 phase row in Phases table above and K2 for the GRANTED termination condition.

**K7 — HANDOFF.md structure (U10):** Phase U10 generates `HANDOFF.md` summarising: kit version cascaded from, phases completed and skipped, features added or updated, reflex pass result (GRANTED/DENIED), and run instructions. The file is overwritten on every `--update` run — it always reflects the latest update state. Cross-reference: `docs/work-flows/18-project-orchestration.md` §Handoff phase for the original-orchestration HANDOFF format; `--update` HANDOFF includes an additional `update_summary:` section.

---

## Why --update replaces cascade

The old pattern required committing "cascade kit vX → project" manually every time the kit updated. This:
- Required human intervention for every kit patch
- Did not fill structural gaps (design plans, stubs, ARD)
- Did not run reflex — projects could accumulate QA debt
- Relied on the user knowing which files changed

`--update` is automated, structural, and reflex-verified. Every update lands with GRANTED.

---

## Key Rules

- **`--update` is the only supported update path.** The manual cascade pattern (hand-committing "cascade kit vX" messages) is retired as of v0.6.47. Use `psk-orchestrate.sh --update` instead.
- **U9 reflex is mandatory — no skip.** The reflex autoloop runs until GRANTED regardless of whether features were added. An update without GRANTED is not complete.
- **KIT_ROOT resolution is automatic.** `install.sh` v0.6.47+ writes `kit_source_path` to `.portable-spec-kit/config.md`. Override only needed when the saved path is stale or the kit moved.
- **U6 sync-check-config is idempotent.** If `.portable-spec-kit/sync-check-config.md` already exists, U6 skips. Safe to re-run `--update` multiple times.
- **Polyglot stacks are detected automatically.** `mandate-audit.sh` resolves `backend/`+`frontend/` layouts as `polyglot-python-node` and applies mandates to both manifests.
- **Design plans and feature stubs are created even if the feature is not yet implemented.** U3 and U4 fill the structural pipeline so the project is release-ceremony-ready before features are built.
- **Phases run in order — no skipping.** Each phase's output is an input to the next. Kit currency (U0) must complete before structure audit (U1), which informs gap filling (U3–U6).

---

## Edge cases

| Scenario | Behavior |
|---|---|
| `kit_source_path: remote` | reflex installed via curl; script sync skipped (no local kit) |
| `reflex/` already installed | U2 skips with "already installed" |
| All features `[x]` | U7 skips (nothing to implement) |
| `sync-check-config.md` exists | U6 skips (idempotent) |
| GRANTED first try | U9 exits immediately with GRANTED |
| reflex DENIED after safety cap | U9 exits with non-zero; user must review `reflex/history/` |

---

## Related Flows

- [18-project-orchestration.md](18-project-orchestration.md) — original orchestration pipeline (new projects)
- [13-release-workflow.md](13-release-workflow.md) — release ceremony (invoked at U8)
- [17-reflex.md](17-reflex.md) — reflex AVACR loop (invoked at U9)

---

## Changelog feature index (v0.6.47–v0.6.52)

Verbatim CHANGELOG feature keys for documentation coverage tracking.

**K1 — install.sh records kit_source_path:** Written to `.portable-spec-kit/config.md` on every install (v0.6.47).
**K2 — Phase 9 never skips:** Reflex-audit phase is now mandatory; auto-installs reflex if absent (v0.6.47).
**K3 — --update mode added:** New `psk-orchestrate.sh --update` command U0–U10 replaces manual cascade (v0.6.47).
**K4 — Phase 7 writes tests/features/ stubs:** Sub-agent creates R→F→T anchor stubs per acceptance criterion (v0.6.47).
**K5 — Polyglot stack detection in mandate-audit.sh:** backend/+frontend/ → `polyglot-python-node` (v0.6.47).
**K6 — loop.sh GRANTED terminator calls score.sh:** GRANTED path now writes summary.csv row (v0.6.47).
**K7 — docs/work-flows/23-project-update-workflow.md added:** Flow doc for `--update` mode (v0.6.47).
**K1 path-spaces bug fixed:** `resolve_kit_root()` now uses `sed` trailing-strip instead of `tr -d '[:space:]'` (v0.6.49).
**Heuristic false-positive fixed:** Added `install.sh` presence check to kit-root heuristic (v0.6.49).
**Box line alignment (63-char standard):** 80 misaligned lines fixed; enforced by infrastructure tests (v0.6.50).
**README flow count:** `tests/sections/01-infrastructure.sh` updated `"22 step-by-step flow"` → `"23 step-by-step flow"` (v0.6.47).
**doc-23 updated:** `23-project-update-workflow.md` resolution order documents the `install.sh` check requirement (v0.6.48).
**doc-23 K1-K7 coverage:** This doc enriched with KIT_ROOT resolution (K1), mandatory reflex (K2), stubs (K4), polyglot (K5), score.sh GRANTED path (K6) (v0.6.48).
**ARD HTML consistency:** ARD HTML version badges + footers updated to v0.6.48; Guide received v0.6.47 section (v0.6.48).
**Benchmarking fixture:** `tests/test-spd-benchmarking.sh` Kit fixture line updated to v0.6.48 (v0.6.48).
**Example version consistency:** `examples/starter/` and `examples/my-app/` AGENT_CONTEXT.md + RELEASES.md + portable-spec-kit.md updated v0.6.44 → v0.6.48 (v0.6.48).
**Test count consistency sweep:** 8 files updated 2336/2191 → 2337/2192 (v0.6.52).
**Flow doc count corrections:** docs 17/19/21 corrected for framework count and flow numbering (v0.6.52).
**Reflex cycle-10/pass-003 artifacts committed:** findings.yaml + 104-file history directory committed (v0.6.52).
