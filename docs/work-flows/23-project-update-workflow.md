# 23 — Project Update (folded into `orchestrate build` + `init`, v0.6.62+)

> **Status:** REDIRECT. The standalone `--update` workflow was removed in v0.6.62. Updating an existing project now uses the same two commands as everything else: `init` (conform structure) + `orchestrate build` (regenerate content). This page is kept as a redirect so existing links resolve; the canonical content lives in the two docs linked below.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | "update / extend this project" · `bash agent/scripts/psk-orchestrate.sh build` on an existing project |
| **Inputs** | Existing project source + `agent/*.md` pipeline + `.portable-spec-kit/config.md` (`kit_source_path`) |
| **Outputs** | Structure conformed to current kit standards (`init`) + content regenerated/extended + reflex GRANTED + `HANDOFF.md` |
| **Script** | `bash agent/scripts/psk-init.sh` (structure) then `bash agent/scripts/psk-orchestrate.sh build` (content) |
| **Gate** | `init` dual-gate validation; `build` reflex GRANTED before final handoff |
| **When blocked** | Kit source unresolvable → set `PSK_KIT_ROOT` and re-run `install` (see KIT_ROOT resolution below) |

---

## Why this doc is now a redirect

The kit collapsed to a clean idempotent command model (v0.6.62+):

- **`install`** — pull kit machinery from source (local `--from` or GitHub curl), idempotent, then chains to `init`.
- **`init`** — conform the project's **structure** to current installed-kit standards (registry-driven, idempotent CREATE-or-REFRESH, content-loss-protected). Folds the retired `reinit`. → [05-project-init.md](05-project-init.md)
- **`orchestrate build`** — run the full 10-phase lifecycle to regenerate/extend **content** (reqs → research → specs → design → scaffold → features → release → reflex → handoff). One command for new AND existing projects; each phase is idempotent (create-or-update). → [18-project-orchestration.md](18-project-orchestration.md)

The old `--update` flag bundled both axes (structure + content) into one phase loop (U0–U10). That is replaced by the cleaner two-axis division: `init` owns structure, `build` owns content. The legacy `--update` and `--retrofit` flags now print a removal notice and exit.

**Division of labour (no overlap):** `init` = STRUCTURAL conformance (does each artifact exist + match kit shape/standards — registry-driven). `build` = CONTENT regeneration (re-derive reqs → … → ship, idempotent per phase). Run `init` first, then `build`.

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Updating an existing kit-managed project                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  1. install  (idempotent) — pull latest kit machinery       │
│       bash <kit>/install.sh --yes --from <kit>  (or curl)   │
│       chains to → init                                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. init  — conform STRUCTURE (registry-driven conformance) │
│       bash agent/scripts/psk-init.sh complete               │
│       → see 05-project-init.md                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. orchestrate build — regenerate/extend CONTENT           │
│       bash agent/scripts/psk-orchestrate.sh build "<req>"   │
│       10 idempotent phases · reflex GRANTED · HANDOFF.md    │
│       → see 18-project-orchestration.md                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Rules

- **No standalone `--update`.** Updating = `init` (structure) + `orchestrate build` (content). The `--update` / `--retrofit` flags were removed (v0.6.62+) and now print a removal notice + exit.
- **Two axes, run in order.** `init` first (conform structure, content-loss-protected), then `build` (regenerate content, idempotent per phase).
- **Reflex GRANTED is still mandatory.** `build`'s reflex-audit phase (Phase 9) runs the autoloop until GRANTED before final handoff — no skip path.
- **`build` is idempotent on existing projects.** Each phase updates the artifact it finds and creates what's missing — there is no separate "existing-project" code path or flag.
- **Conformance is advisory in `build`.** `build` surfaces standards drift (`psk-conformance.sh --check`) on entry and points you at `init`; it never gates on conformance.

---

## KIT_ROOT resolution (for `install` / `init`)

`install.sh` writes three fields to `.portable-spec-kit/config.md` so the kit source can be relocated automatically:

```
kit_source_path: /path/to/portable-spec-kit  # or "remote" for curl installs
kit_version: v0.6.62
kit_installed_at: 2026-05-26
```

Resolution order (used by install / init when they need the kit source):

1. `PSK_KIT_ROOT` env var — always wins.
2. `.portable-spec-kit/config.md` → `kit_source_path` field.
3. Script-location heuristic — parent dir has `portable-spec-kit.md` as a real file (not symlink) AND `install.sh` present (distinguishes a real kit from a user project that copied `portable-spec-kit.md`).
4. `remote` — curl-fetch from GitHub (curl installs).

If resolution fails (`unknown`), set `PSK_KIT_ROOT` explicitly and re-run.

---

## Related Flows

- [05-project-init.md](05-project-init.md) — `init` registry-driven structural conformance (folds reinit)
- [18-project-orchestration.md](18-project-orchestration.md) — `orchestrate build` full lifecycle (new + existing)
- [13-release-workflow.md](13-release-workflow.md) — release ceremony (invoked at build Phase 8)
- [17-reflex.md](17-reflex.md) — reflex AVACR loop (invoked at build Phase 9)
