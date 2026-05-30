# Flow 22 — Project-to-Kit Feedback Loop (PKFL)

**Version:** v0.6.41  
**Status:** Active  
**Trigger:** Automatic when `file-bugs.sh` routes one or more `scope:kit` findings to `agent/tasks/Gxx-*.md`

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | `file-bugs.sh` routes ≥1 `scope:kit` findings to `agent/tasks/Gxx-*.md` (auto) or `bash reflex/lib/kit-evolution.sh --kit-root … --source-project … --auto-update` (manual) |
| **Inputs** | `findings.yaml` (with `scope:kit` + `genericity_proof`), `reflex/config.yml` (`kit_evolution.auto`), `agent/tasks/Gxx-*.md` |
| **Outputs** | Kit commit(s) with generic fix, updated kit version, project updated via `psk-orchestrate.sh build`, post-update reflex GRANTED verdict |
| **Script** | `reflex/lib/kit-evolution.sh` (6-phase orchestrator), `reflex/lib/file-bugs.sh` (G4 gate), `reflex/lib/gates.sh` (G1–G2 on kit branch) |
| **Gate** | 6 KGG gates (G1: file scope · G2: vocabulary · G3: disposition deadline · G4: genericity_proof · G5: kit test suite · G6: smoke install) |
| **When blocked** | G4: `genericity_proof` absent → finding downgraded to `target-project`. G5: kit test suite fails → fix before merge. G6: smoke-test-examples fails → fix install path. |

---

## Purpose

Every project that runs reflex is also stress-testing the kit. When QA-Agent surfaces a finding that belongs in the kit (not in the project), PKFL converts that finding into a verified kit improvement — automatically, generically, and safely — then runs `psk-orchestrate.sh build` in the triggering project to bring it current.

This is how the kit evolves empirically: real-world projects surface real gaps; PKFL closes them at the root.

---

## What PKFL Is Not

- Not a project-fix path — project-scope findings go through normal reflex flow
- Not an autonomous AI trainer — agents are stateless; PKFL is orchestration, not learning
- Not a replacement for the kit's own reflex cycle — both run independently

---

## The 6 KGG Gates (Kit Genericity Guard)

Every kit-evolution commit must pass all 6 gates before it reaches the kit's main branch:

| Gate | Where enforced | What it checks |
|------|---------------|----------------|
| G1   | `gates.sh` (gate 10, on `REFLEX_KIT_EVOLUTION=1`) | Changed files belong only to kit paths — no project-shaped files in a kit commit |
| G2   | `gates.sh` (gate 11, via `check-kit-genericity.sh`) | No project-specific vocabulary (domain nouns, hardcoded routes, real secrets) in kit code |
| G3   | `kit-evolution.sh` Phase 2 | Every Gxx task has a Disposition (`fix \| reject \| defer`) within 7 days |
| G4   | `file-bugs.sh` AWK emit block | `genericity_proof` field present in `findings.yaml` before routing to kit — absent = downgraded to `target-project` |
| G5   | `kit-evolution.sh` Phase 4 | Full kit test suite passes (`test-spec-kit.sh` + `test-spd-benchmarking.sh`) |
| G6   | `kit-evolution.sh` Phase 5, via `smoke-test-examples.sh` | Kit installs cleanly into every `examples/` project after the fix |

---

## Flow Diagram

```
Project reflex run
       │
       └──────────────────────────────────────────────────────────────┐
                                                                      │
QA-Agent files findings with scope: kit                               │
       │                                                              │
       └──────────────────────────────────────────────────────────────┐
                                                                      │
file-bugs.sh PKFL G4 check:
  genericity_proof present? ──NO──► downgrade to target-project
       │ YES
       └──────────────────────────────────────────────────────────────┐
                                                                      │
agent/tasks/Gxx-<slug>.md created in kit repo
       │
       └── (if kit_evolution.auto: true) → kit-evolution.sh orchestrator
                 │
                 ├─ Phase 1: Discover pending Gxx tasks
                 ├─ Phase 2: G3 no-dead-letter check
                 ├─ Phase 3: Kit Dev-Agent pass (REFLEX_KIT_EVOLUTION=1)
                 │             ├─ G1 file-scope gate (gates.sh)
                 │             └─ G2 genericity-proof gate (check-kit-genericity.sh)
                 ├─ Phase 4: G5 full kit test suite
                 ├─ Phase 5: G6 multi-project smoke test
                 └─ Phase 6: Cascade → source project (install.sh --yes --from)
                                   │
                                   └── Project runs reflex again (verifies gaps closed)
```

---

## Trigger Conditions

PKFL auto-triggers after `file-bugs.sh` when all three are true:

1. At least one finding has `scope: kit` or `scope: meta`
2. The finding has a `genericity_proof` field (G4 gate)
3. `kit_evolution.auto: true` in `reflex/config.yml`

Manual trigger:

```bash
bash reflex/lib/kit-evolution.sh \
  --kit-root /path/to/portable-spec-kit \
  --source-project /path/to/your-project \
  --auto-update
```

---

## genericity_proof Format (QA-Agent contract)

Every `scope: kit` finding in `findings.yaml` must include:

```yaml
- id: QA-ARCH-07
  scope: kit
  genericity_proof: |
    This gap is generic because: every project using the kit that declares drizzle-orm
    in package.json will have the same missing migration scaffold — the fix is a new
    check in mandate-audit.sh that is parameterized by stack detection, not by any
    property specific to this project's schema, domain, or feature set.
    Counter-check: the recommendation adds a check to a kit script (mandate-audit.sh),
    not to any project-specific file.
```

Without `genericity_proof`, `file-bugs.sh` logs a `[G4-DOWNGRADE]` message and routes the finding to `target-project` instead.

---

## File Map

| File | Role |
|------|------|
| `reflex/lib/kit-evolution.sh` | PKFL orchestrator — 6-phase loop |
| `reflex/lib/check-kit-genericity.sh` | G2 scanner — project vocabulary detection |
| `reflex/lib/smoke-test-examples.sh` | G6 runner — multi-project install smoke |
| `reflex/lib/file-bugs.sh` | G4 gate — genericity_proof check before routing |
| `reflex/lib/gates.sh` | G1 (gate 10) + G2 (gate 11) — on `REFLEX_KIT_EVOLUTION=1` |
| `reflex/config.yml` | `kit_evolution:` config block |
| `reflex/prompts/qa-agent.md` | `genericity_proof` instruction + format |
| `agent/tasks/Gxx-*.md` | Kit task queue (one file per `scope:kit` finding) |
| `agent/tasks/rejected/Gxx-*.md` | Rejected findings with rationale |

---

## Scope Separation Guarantee

The genericity test: "would this exact change be correct for *every* project that installs the kit?"

- **Yes** → kit commit (passes G1-G6)
- **No** → project commit (normal reflex dev-agent flow)
- **Mixed** → split commits: one kit commit (generic root), one project commit (project mitigation)

This guarantee is enforced structurally (G1-G4) and empirically (G5-G6), not by trust.

---

## Key Rules

- **`genericity_proof` is mandatory — no proof, no routing.** G4 gate in `file-bugs.sh` downgrades any `scope:kit` finding that lacks `genericity_proof` to `target-project`. It never silently routes to kit.
- **Genericity test:** "Would this exact change be correct for *every* project that installs the kit?" Yes → kit commit. No → project commit. Mixed → split commits.
- **Structural enforcement beats prompt-level trust.** G1 (file-scope) and G2 (vocabulary) are mechanical gates on the kit branch — they block project-shaped code from entering the kit regardless of agent intent.
- **G3 seven-day disposition deadline.** Every `Gxx-*.md` task must be `fix | reject | defer` within 7 days. Dead-letter Gxx tasks block the PKFL loop.
- **Rejected findings are preserved, not deleted.** `agent/tasks/rejected/Gxx-*.md` provides audit trail for "why not" decisions.
- **Auto-trigger requires all three conditions.** `scope:kit` finding + `genericity_proof` field + `kit_evolution.auto: true` in config — all must be true. Partial conditions fall back to manual trigger only.
- **Cascade propagates back to the source project.** Phase 6 re-runs `install.sh --yes --from` on the triggering project and re-runs reflex to verify the gap is closed at the project level too.

---

## ADL Reference

See `agent/PLANS.md` → ADL entries tagged `PKFL` for all architectural decisions made during PKFL design.

Flow added: 2026-05-10. Kit version: v0.6.41.
