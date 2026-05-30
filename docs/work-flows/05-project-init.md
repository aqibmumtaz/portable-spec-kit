# Flow: Project Init (idempotent — conform project to kit standards)

> **When:** User says "init". Agent conforms the project to the current
> installed-kit standards — never auto-triggers.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | User explicitly says `"init"` — never auto-triggered |
| **Inputs** | Source files, config files, existing `agent/*.md` pipeline files (REFRESH mode), kit conformance registries |
| **Outputs** | `agent/*.md` pipeline created (CREATE) or conformed to kit standards in place (REFRESH); per-dimension fixes recorded |
| **Script** | `bash agent/scripts/psk-init.sh` (dispatcher-driven via `psk-dispatch.sh` + `init/phases.yml`) |
| **Engine** | `bash agent/scripts/psk-conformance.sh` — registry-driven, dimension-agnostic conformance loop |
| **Gate** | Dual-gate validation via `bash agent/scripts/psk-validate.sh init` — both critics must pass |
| **When blocked** | No recognizable stack → ask user before proceeding; CREATE on empty project scaffolds from templates first |

> **`reinit` is folded into `init` (v0.6.62+).** There is no separate re-sync command. The idempotent `init` CREATEs an empty project's pipeline and REFRESHes an existing one (content-loss-protected). `psk-reinit.sh` is a thin redirect alias that prints a removal notice and forwards to `psk-init.sh`. One critic template (`INIT`) covers both states.

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  User says "init"                                           │
│     psk-init.sh preflight → bootstrap-check + state detect  │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────▼──────────────┐
         │  STATE DETECT (idempotent) │
         │  ≥1 substantive agent/*.md │
         │  OR src/ has content?      │
         ├─ no  → CREATE mode ↓      │
         └─ yes → REFRESH mode ↓     │
         └────────────────────────────┘
```

**CREATE mode (empty project):**

```
┌─────────────────────────────────────────────────────────────┐
│  1. Scaffold agent/*.md pipeline from kit templates         │
│       (REQS, SPECS, PLANS, DESIGN, RESEARCH, TASKS,         │
│        RELEASES, AGENT, AGENT_CONTEXT)                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. Run conformance engine (psk-conformance.sh --conform)   │
│       iterate registry → detect → fix → re-detect           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. Dual-gate validation (psk-validate.sh init)             │
└─────────────────────────────────────────────────────────────┘
```

**REFRESH mode (existing kit-managed project):**

```
┌─────────────────────────────────────────────────────────────┐
│  1. Snapshot agent/*.md byte counts → agent/.init-snapshot/ │
│       (content-loss guard — REFRESH never wipes)            │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. Run conformance engine (psk-conformance.sh --conform)   │
│       For each registered check (sync-check drift,          │
│       mandate-gaps, ui-completeness[frontend], src-layout,  │
│       design-plans, R→F→T stubs, ARD+flow-docs,             │
│       sync-check-config, reflex-install, kit-version-align) │
│       → detect → if drift, dispatch fix (mechanical run OR  │
│         workload-driven sub-agent spawn per §Spawn Fidelity)│
│       → re-detect → record. Conformant project = no-op.     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. Content-loss check — flag any agent/*.md that shrank    │
│       >20% vs snapshot before completing                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. Dual-gate validation (psk-validate.sh init)             │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Rules

- **Never auto-trigger** — `init` fires only on an explicit user signal.
- **Idempotent, state-detected** — `init` CREATEs on an empty project and REFRESHes an existing one. Re-running on a conformant project is a fast no-op (every detect exits 0). No create-vs-resync split for the user to choose.
- **Registry-driven, dimension-agnostic** — the conformance engine iterates a declarative registry (`.portable-spec-kit/conformance/registry.yml` + the kit's existing PSK sync-check rules, mandate-audit dimensions, ui-completeness categories). Adding a future kit standard = add a registry entry (DATA), never edit init's code. init AUTOMATICALLY covers new standards because it reads the registries at runtime.
- **REFRESH only updates, never deletes** — no `[x]` tasks, ADL rows, or existing content is removed during conform; the snapshot + content-loss check (>20% shrink flags a warning) enforces this.
- **CREATE fills every field from the scan** — scaffolded `agent/*.md` files are conformed and populated from source/config; never leave `TBD` when the answer is visible.
- **Single dual-gate** — the `INIT` critic template covers both CREATE and REFRESH; both bash + sub-agent critics must pass before init is complete.
- **Secrets never read** — `.env` variable names may inform `.env.example` creation; values are never read, echoed, or stored at any step.
- **Structure vs content** — `init` is STRUCTURAL conformance (does each artifact exist + match kit shape/standards). Regenerating artifact CONTENT from requirements is the lifecycle's job (`orchestrate build` — see [18-project-orchestration.md](18-project-orchestration.md)).

---

## Subcommands

```bash
bash agent/scripts/psk-init.sh preflight   # bootstrap-check + CREATE/REFRESH detect;
                                           #   CREATE → scaffold agent/*.md from templates;
                                           #   REFRESH → snapshot byte counts;
                                           #   advisory conformance --check (never fails preflight)
bash agent/scripts/psk-init.sh complete    # run conformance --conform (the actual conform)
                                           #   + content-loss check (REFRESH) + dual gate
```

`psk-init.sh` is dispatcher-driven: `psk-dispatch.sh` is the executor, reading `init/phases.yml`. The script keeps the preflight + conform logic; the dispatcher drives the phases.

## Edge Cases

| Condition | Behaviour |
|-----------|-----------|
| `init` on already-conformant project | Fast no-op — every registry detect exits 0; summary shows "0 drift" |
| Partial pipeline (some agent/*.md present) | Treated as REFRESH — backfill missing files, never wipe existing |
| No recognizable stack | Ask: "What stack is this project using?" before continuing |
| Monorepo (multiple stacks) | Ask which subdirectory to init first — handle each separately |
| Very large project (100+ files) | Scan config files + top-level dirs + sample src/ — don't read every file |
| `.env` present during scan | Read variable names only — never read or expose values |
| `reinit` typed (muscle memory) | `psk-reinit.sh` prints removal notice and forwards to `psk-init.sh` |
| agent/*.md already accurate | Note "no changes needed" in summary — never overwrite accurate content |

## Final Validation (MANDATORY — dual gate)

At the end of `init` (CREATE or REFRESH), agent MUST run the dual-gate validation:

```bash
bash agent/scripts/psk-validate.sh init
```

Exit 0 → init complete. Exit 2 → `AWAITING_CRITIC`: agent reads `agent/.release-state/critic-task.md`, spawns a fresh sub-agent via Task tool with that exact prompt, writes the response to `critic-result.md`, re-runs validate.

**Init critic** verifies all `agent/*.md` pipeline files exist, are populated from the codebase (not empty templates), Stack matches repo facts, features retroactively mapped from commits, AND (REFRESH) no content was lost during conform (no `[x]` tasks deleted, no ADL rows dropped). Both bash + sub-agent critics must pass before init is complete.
