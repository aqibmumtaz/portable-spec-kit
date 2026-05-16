# Flow 27 — UI Completeness Gate

5th reliability layer's deliverable-bar counterpart. Structurally prevents the v5-skeletal-UI failure: when a project's Stack table declares any frontend framework, the UI layer MUST meet a measurable 10-category completeness bar before workflows can mark the project "done".

## Overview

| Aspect | Detail |
|---|---|
| Rule | PSK025 in `agent/scripts/psk-sync-check.sh` (28th rule) |
| Script | `agent/scripts/psk-ui-completeness.sh` (36th kit script) |
| Reflex dim | Dim 26 wraps the audit (`reflex/lib/workflow-fidelity-audit.sh`) |
| Reflex gate | 12th mechanical gate `workflow-fidelity-completeness` |
| Orchestrator phase | U6.5 in `psk-orchestrate.sh --update` |
| Released | v0.6.57 |

## Key Rules

- Stack-aware: skips projects with no declared frontend (`package.json` deps + `agent/PLANS.md` Stack table).
- 10 sub-codes — every one must pass before the gate clears: **P** primitives · **L** layout · **D** dark-mode · **S** loading/empty/error states · **A** a11y · **T** design-tokens · **F** per-feature pages · **I** input-feedback · **R** responsive · **E** empty-shell anti-skeleton.
- `--check` is advisory (exit 0 always). `--strict` is the gate (exit 1 on any violation).
- `--json` emits machine-readable output consumed by Reflex Dim 26 and Gate 12.
- Bypass: `PSK_UI_COMPLETENESS_DISABLED=1` removes the structural guarantee — explicit, per-invocation, logged.
- Empty-shell detection (sub-code **E**) flags any page file with `<div>Coming soon</div>`, `{/*TODO*/}`, or fewer than 20 LOC of body — the v5 signature pattern.

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Workflow invokes psk-ui-completeness.sh (--strict)       │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 2. Stack-detect: package.json deps + agent/PLANS.md Stack   │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 3. No frontend → skip cleanly (exit 0, advisory)            │
│    Frontend → run 10 sub-checks (P L D S A T F I R E)       │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 4. All sub-codes pass → exit 0; workflow advances           │
│    Any violations → exit 1; state-machine gate blocks       │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 5. --update U6.5 backfill phase invoked by orchestrator     │
│    Sub-agent scaffolds missing primitives, layout, dark-    │
│    mode, states, a11y, tokens, pages, input-feedback,       │
│    responsive; replaces empty shells with full impls        │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────┴──────────────────────────────┐
│ 6. Re-run psk-ui-completeness.sh --strict; gate clears      │
│    Workflow advances to next phase (U7 features → U8 etc)   │
└─────────────────────────────────────────────────────────────┘
```

## Surfaces

| Surface | When it fires | Mode |
|---|---|---|
| `psk-ui-completeness.sh` (CLI) | manual invocation; CI; dev iteration | configurable |
| `psk-sync-check.sh --quick` (PSK025) | PostToolUse hook after every Write/Edit | warn |
| `psk-sync-check.sh --full` (PSK025) | pre-commit hook | error (blocks) |
| `psk-orchestrate.sh` Phase 5 (new mode) | new project scaffold | strict via state-machine gate |
| `psk-orchestrate.sh --update` U6.5 | upgrading existing project | strict via state-machine gate; sub-agent backfills until clean |
| `reflex/lib/workflow-fidelity-audit.sh` Dim 26 | every reflex QA pass | --json parsed; findings filed |
| `reflex/lib/gates.sh` Gate 12 | after every Dev-Agent fix | block at MAJOR (configurable severity) |

## Sub-code reference

| Code | Check | Default threshold |
|---|---|---|
| P | Component primitives present in `src/ui/components/` (or framework-conventional path) | ≥12 of: button, input, textarea, select, checkbox, radio, card, modal, toast, tabs, badge, avatar, dropdown, menu, dialog |
| L | Layout components present | 4-of-5 of: header, nav/navigation, footer, sidebar, container |
| D | Dark-mode signal | any 1 of: `useTheme(`, `data-theme=`, `dark:` Tailwind ≥20 hits, `--bg`/`--fg` CSS vars, `prefers-color-scheme` |
| S | Loading/empty/error state scaffolding | every page file has `<Skeleton`, `<Spinner`, `isLoading`, `<EmptyState`, `<ErrorBoundary`, or `loading.tsx`/`error.tsx` neighbor |
| A | Accessibility hygiene | `aria-label` ≥10, `role=` ≥5, zero native `alert(`/`confirm(`/`prompt(` calls |
| T | Design-token system declared | any 1 of: tailwind.config with `colors:`, `src/ui/tokens.{ts,js}` or `theme.{ts,js}`, CSS with ≥6 `:root` `--*` vars |
| F | Per-feature page presence | every `[x]` SPECS feature with UI keyword (page/view/form/dashboard/admin/list/detail/feed/profile) has a matching page file |
| I | Form input feedback | ≥5 inputs with associated error messaging (`aria-describedby`, `<FormMessage>`, `<HelperText>`, `<FieldError>`, `.error` class) |
| R | Responsive breakpoints | Tailwind `sm:|md:|lg:|xl:` hits ≥10 OR `@media` queries ≥3 OR `Platform.*` branches ≥1 |
| E | Empty-shell anti-skeleton | zero page files with `<div>Coming soon</div>`, `{/*TODO*/}`, or <20 LOC body |

## Edge cases

- **No frontend declared.** PSK025 emits an informational skip line and the gate clears immediately. Bash/Python/CLI projects pass automatically.
- **UI dir not at conventional path.** Detection tries `src/app`, `src/pages`, `src/ui`, `src/components`, `pages`, `app`, `frontend/src` in order. Custom paths surface as PSK025-E "no UI root found".
- **Stack table mentions a framework but the project isn't actually a frontend.** Detection prefers `package.json` deps over `agent/PLANS.md` text scan. If `package.json` has no frontend dependency, the Stack-table scan is bounded to the `## Stack` section only.
- **Macros / generated UI.** If component primitives live in a generated file or are macro-driven, declare them in `tailwind.config.{js,ts}` and a `tokens.ts` so sub-codes T and P find canonical signals.
- **React Native / mobile.** Sub-code R counts `Platform.*` branches; sub-code A is unchanged (RN supports `accessibilityLabel`; PSK025 currently looks for `aria-label` — RN-aware vocabulary slated for a future patch).

## Related Flows

- Flow 25 — Workflow Fidelity (4th reliability layer, the parent process gate)
- Flow 26 — Plan Execution Protocol (5th reliability layer, plan-shape gate; this UI Completeness gate is the deliverable-bar counterpart)
- Flow 18 — Project Orchestration (where U6.5 lives in the `--update` flow)

## Bypass

`PSK_UI_COMPLETENESS_DISABLED=1` short-circuits both `psk-ui-completeness.sh` and the PSK025 sync-check rule. For genuine emergencies only — each invocation removes a structural guarantee.

## Worked example — searchsocialtruth-v5 fix path

1. Pre-v0.6.57: v5 shipped with skeletal admin pages (`<div>Coming soon</div>`) behind a "20 features / 110 tests passing" report. Empty shells passed every existing gate.
2. v0.6.57 lands: `psk-ui-completeness.sh` + PSK025 + U6.5 active.
3. Operator runs `bash agent/scripts/psk-orchestrate.sh --update` on v5 (Phase C of plan `workflow-fidelity`).
4. U0-U6 advance normally (kit-currency sync, mandate audit, reflex install, design plans, feature stubs, ARD, sync-check-config).
5. U6.5 fires: `psk-ui-completeness.sh --json` reports 7 sub-code violations (P/S/D/F/I/T/E).
6. Sub-agent backfills: scaffolds 12 component primitives, adds dark-mode toggle, replaces 9 empty-shell admin pages with full implementations matching their SPECS.md acceptance criteria, wires error states, adds design tokens, adds aria-labels.
7. Re-run `--strict` → exit 0. State-machine gate clears.
8. U7-U10 advance. Release prep, reflex audit until GRANTED, HANDOFF.md regenerated.
9. v5 ships as v0.2.0 with rich professional UI, fully verified.
