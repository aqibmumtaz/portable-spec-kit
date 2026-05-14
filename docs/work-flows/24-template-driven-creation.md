# Flow 24 — Template-Driven Creation

Every non-code file the kit produces in a project (agent pipeline files, flow docs, plans, findings, research, ADRs, handoffs, ARDs, README, src subdirs) is scaffolded from a template that passes the 7-criterion Template Quality Bar.

> **Plan-Save Protocol cross-ref (v0.6.53+):** plan-shaped conversations auto-save to `agent/plans/YYYY-MM-DD-<slug>.md` via the `plan-template.md` scaffold. See flow 16 for feature plans (`agent/design/f{N}-*.md`).

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | Any kit operation that creates a non-code file — `psk-new-setup.sh`, `psk-orchestrate.sh`, `psk-plan-save.sh`, `psk-feature-complete.sh`, manual `psk-init.sh` |
| **Inputs** | `.portable-spec-kit/templates/*.md` and `*.sh` and `*.html` — the 23 source-of-truth templates |
| **Outputs** | Project files scaffolded from templates with placeholders preserved until first edit |
| **Script** | `bash agent/scripts/psk-template-quality.sh --all` (lint) · `bash agent/scripts/psk-scaffold-src.sh <project-root>` (src layout) |
| **Gate** | PSK023 (template quality) + PSK022a (template choice) + PSK022b (src subdir layout) sync-check rules |
| **When blocked** | Template fails 7-criterion bar OR project's physical layout doesn't match Stack-derived expectation |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Kit operation creates a non-code file                      │
│                                                             │
│  pipeline · flow-doc · plan · ARD HTML · finding · research │
│                          │                                  │
│                          ▼                                  │
│  .portable-spec-kit/templates/<kind>-template.<ext>         │
│  • passes 7-criterion Quality Bar (psk-template-quality.sh) │
│  • <!-- TEMPLATE-KIND · GENERICITY · LAST-AUDITED --> hdr   │
│  • <!-- REQUIRED --> placeholders block premature commit    │
│                          │                                  │
│                          ▼                                  │
│  Project file scaffolded with audit header preserved        │
│  Lifecycle: scaffolded → drafted → committed                │
│                                                             │
│  Source layout (Template 1):                                │
│    src/core,shared (always) + ui,api,integrations,platform  │
│    (opt-in per Stack table — PSK022b enforces)              │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Rules

- **Every kit-shipped template lives in `.portable-spec-kit/templates/`** — the externalized files are the source of truth. The inline-in-skill copy at `.portable-spec-kit/skills/templates.md` is a pointer index, not source.
- **Every template passes the 7-criterion Quality Bar.** Verified by `bash agent/scripts/psk-template-quality.sh --all --strict`. PSK023 fires in `psk-sync-check.sh --full`.
- **Scaffolded files mark REQUIRED placeholders with grep-detectable text.** `<!-- REQUIRED — replace before commit -->` lines block premature commits via pre-commit hook.
- **Source layout is Stack-driven.** `psk-orchestrate.sh` reads `agent/PLANS.md` Stack table → derives Template 1/3/4/5/6 + opt-in src subdirs → invokes `psk-scaffold-src.sh` to populate.
- **Opt-in subdirs only.** `core/` + `shared/` always present in Template 1. `ui/` `api/` `integrations/` `platform/` enabled per Stack declaration. **No empty mandatory dirs.**
- **Audit log is committed.** `.portable-spec-kit/templates/.audit-log.yaml` records every template's audit history. Per-template `LAST-AUDITED:` header lives in the file itself.

---

## Edge Cases

| Case | Handling |
|---|---|
| Template fails one criterion | `psk-template-quality.sh --strict` exits non-zero; PSK023 blocks at sync-check |
| Project has no `src/` (Template 3, 5, or 6) | `psk-scaffold-src.sh` is not invoked; PSK022b skips |
| Stack table missing | `psk-scaffold-src.sh` exits 1 with "PLANS.md missing or unparseable" |
| Re-running scaffold on existing project | Idempotent — only creates missing subdirs, never overwrites existing README |
| User edits a template body | Audit header `LAST-AUDITED:` must be refreshed; PSK023 re-lints |

---

## Related Flows

- [Flow 16 — Feature Design Pipeline](16-feature-design.md) — `agent/design/f{N}-*.md` plans use `agent-design-plan-template.md`
- [Flow 13 — Release Workflow](13-release-workflow.md) — Step 9 runs PSK023 via sync-check
- [Flow 17 — Reflex](17-reflex.md) — reflex prompts use `reflex-prompt-template.md`; findings use `kit-finding-template.md`
- [Flow 18 — Project Orchestration](18-project-orchestration.md) — Phase 6 scaffold reads Stack → invokes `psk-scaffold-src.sh`

---

## Bypass

Emergencies only:
- `PSK_SYNC_CHECK_DISABLED=1` — bypass PSK023 (template quality) at sync-check
- `psk-template-quality.sh --all` (without `--strict`) — non-blocking audit

Each bypass breaks a gate and should be explicit.
