# Skill — Professional Project Generation (v0.6.14+)

> **When loaded:** user requests "create my project" / "build me an X" / project setup runs in **professional mode** (any non-trivial requirement).
> **What it does:** orchestrates a kit-driven flow that turns loose requirements into a polished, secure, working application via 8 phases.
> **Companion skills:** `requirement-research.md` · `ui-design-system.md` · `security-baseline.md` · `source-structures.md` · `project-setup.md`

The kit does not just scaffold files — when given requirements (formal or informal, small or large), it researches the domain, expands the requirements professionally, designs a polished UI system, applies security baselines, scaffolds with auth + middleware in place, implements feature-by-feature with tests, and then runs reflex on the result.

## When this skill fires

The `professional mode` branch in `project-setup.md` triggers this skill when:

1. User explicitly says: *"create a new project"*, *"build me a [thing]"*, *"set up a professional project"*, *"generate the app"*
2. New project setup detects the user provided **any actual requirement** (not just "set up React"). One sentence triggers the full flow.
3. User asks for *"polished"*, *"professional"*, *"secure"*, or *"production-ready"* explicitly.

If the user wants the lightweight `scaffold-only mode` (just create empty agent/ files, no generation), they say so — *"just scaffold"*, *"empty setup"*, *"don't generate code"*.

## The 8-phase flow

Each phase has a deliverable and a confirm-with-user gate. **Never skip a gate** — the user redirects between phases, not after.

### Phase 1 — Capture loose requirements

Read what the user wrote (formal/informal, single-sentence to multi-paragraph). Don't expand yet. Write verbatim to `agent/REQS.md` under a `## Raw Input` section. Then ask **at most 3 clarifying questions**, each multi-choice:

```
1. Who is the primary user? (a) end consumer (b) internal team (c) developer/integrator
2. What scale? (a) personal use / prototype (b) small team (10-100 users) (c) public / scalable
3. Hard constraints — pick all that apply: (a) mobile-first (b) offline-capable (c) i18n (d) GDPR/privacy (e) accessibility AA (f) none
```

If the user already covered these in their loose req, skip the question. Don't ask more than 3.

**Gate:** confirm captured intent before research. *"I'm going to research [domain] for a [user-type] [scale] product with [constraints]. ~3-5 min. Proceed?"*

### Phase 2 — Domain + tech research

Spawn `requirement-research.md` skill. Output: `agent/research/domain-and-tech-{date}.md` covering 7 dimensions:

| Dimension | What |
|---|---|
| **Domain** | What is this kind of app? Top 3 reference products. Common features. Anti-patterns. |
| **Competitors** | 2-3 best-in-class examples + what makes them good. |
| **User journey** | Primary flow (1) + 2-3 supporting flows. |
| **Tech stack** | Best-fit stack for the constraints (frontend / backend / db / auth / hosting). Why each choice. |
| **Security threats** | OWASP Top 10 mapped to this app's surface (which are most relevant). |
| **Accessibility** | WCAG 2.1 AA baseline + any domain-specific (e.g., screen reader for content app). |
| **Compliance** | GDPR / CCPA / HIPAA / PCI / etc. — only the ones that apply. |

Use WebFetch / WebSearch tools for current best practices. Cite sources.

**Gate:** show research summary. *"Research done. Stack proposed: [X]. Key risks: [Y]. Approve to expand REQS?"*

### Phase 3 — Expand REQS.md

Take loose req + research → write **R1-R20+ professional requirements** in `agent/REQS.md`. Categorize:

- **R1-R10: Functional** — core features + edge cases derived from user journey
- **R11-R15: Non-functional** — perf budgets (TTI, LCP, API p95), uptime, scalability
- **R12-R18: Security + compliance** — auth, authz, data protection, audit, privacy
- **R19-R22: UX + accessibility** — responsive breakpoints, dark mode, motion, WCAG AA
- **R23-R25: Operational** — logging, monitoring, error handling, observability

Each R has: **id · category · statement · acceptance · source** (research citation if research-driven, "user-stated" if from raw input).

**Gate:** show expanded REQS table. *"Expanded N requirements. Want to add/remove/redirect any?"*

### Phase 4 — Generate SPECS + PLANS

From REQS → SPECS (R→F mapping) and PLANS (architecture + ADL).

- **SPECS.md** — `### F1` to `### F{N}` blocks, each with **Req** column (R-ref), **acceptance criteria** (3-5 testable bullets per `## Feature Acceptance Criteria` section).
- **PLANS.md** — Stack table with **Why** column citing research; Data Model; API Endpoints (all `/api/v1/...`); Build Phases; ADL (newest-first, supersede chain).

**Gate:** *"Architecture decided: [stack summary]. ~N features in N phases. Approve to generate UI design system?"*

### Phase 5 — Generate UI design system

Spawn `ui-design-system.md` skill. Output: `agent/design/ui-system.md` containing:

- **Color tokens** (8-color palette, light + dark mode, semantic — primary/accent/success/warn/error/info/surface/text)
- **Typography scale** (xs/sm/base/lg/xl/2xl/3xl/4xl, font pairings — heading + body)
- **Spacing grid** (4/8/12/16/24/32/48/64 — 4-8px base)
- **Component primitives** (button × 3 variants, input, select, card, modal, toast, table, navbar, sidebar, breadcrumb, tabs)
- **Motion presets** (instant 100ms / quick 200ms / smooth 400ms — easing curves)
- **Breakpoints** (sm 640 / md 768 / lg 1024 / xl 1280)
- **Accessibility tokens** (focus ring, contrast minimums, motion-reduce)

Stack-aware: Tailwind tokens + shadcn variants for React/Next; SwiftUI tokens for iOS; Material 3 for Android; CSS custom properties for vanilla.

**Gate:** *"Design system ready. Want to tweak palette / type / spacing before scaffolding?"*

### Phase 6 — Scaffold with security baseline

Spawn `security-baseline.md` skill + augmented `source-structures.md` template. Outputs:

- Source tree per stack (with auth, middleware, validation, error-handling all wired)
- `.env.example` with placeholders for every secret
- `package.json` / `requirements.txt` / `go.mod` with security-relevant deps pinned
- Middleware stack: auth → CSRF → rate-limit → request-validation → handler → error-formatter
- API versioning: `/api/v1/` mounted
- Health-check endpoint (`/health`)
- Error response format (no stack traces in prod)
- README.md with setup + run + deploy instructions

**Gate:** *"Scaffold landed in `src/` and `tests/`. Run `bash setup.sh` then continue?"*

### Phase 7 — Feature-by-feature implementation

Per feature in SPECS (priority order): write design plan → write tests (red) → implement (green) → mark `[x]` with commit SHA.

Each commit follows kit convention: subject + body (rationale) + `Co-Authored-By:`. Standard 3-layer reliability gates (sync-check, doc-sync, tests) fire on each commit.

UI features always cite the design system (use design tokens, not hard-coded values). API features always validate input + return structured errors.

**Gate:** after each feature, brief progress report. *"F1 done — [test count] tests, all green. F2 next?"*

### Phase 8 — Reflex audit the generated project

Once all features `[x]`, run `bash reflex/run.sh` against the generated project. Reflex (Adversarial Verbal Actor-Critic Refinement Loop) hunts the project across 23 dimensions, files findings, Dev fixes, iterates to convergence (GRANTED).

This is the kit's honesty gate — the same machinery that audits the kit itself audits the project the kit just generated.

**Gate:** *"Reflex GRANTED at iter N. N findings filed, N fixed, 0 regressions. Project ready for review."*

## Anti-patterns (don't do these)

- **Don't expand reqs without research.** Generic R-rows without domain backing produce mediocre apps.
- **Don't skip the design system.** Hard-coded colors / fonts / spacing in components → re-skinning takes weeks.
- **Don't add security as an afterthought.** Auth + validation + rate limit must scaffold in Phase 6, not retrofit in Phase 7.
- **Don't gate-skip.** Each phase's confirm prompt is a redirect opportunity. Skipping them produces work the user must reject.
- **Don't run reflex too early.** Wait until all SPECS features `[x]`. Reflex on incomplete code wastes a cycle.

## Trigger phrases the agent listens for

| Phrase | What kicks off |
|---|---|
| *"create a project for X"* / *"build me an app that does Y"* | Full 8-phase flow |
| *"polished"* / *"professional"* / *"production-ready"* | Force professional mode |
| *"just scaffold"* / *"empty setup"* / *"don't generate"* | Scaffold-only mode (legacy `project-setup.md` flow) |
| *"redo design system"* | Re-run Phase 5 only |
| *"audit my project"* | Skip to Phase 8 (reflex on existing project) |

## Output paths summary

| Path | Phase | Content |
|---|---|---|
| `agent/REQS.md` | 1 + 3 | Raw input + expanded R-rows |
| `agent/research/domain-and-tech-{date}.md` | 2 | 7-dimension research |
| `agent/SPECS.md` | 4 | F1-F{N} + criteria |
| `agent/PLANS.md` | 4 | Stack + Data Model + API + ADL |
| `agent/design/ui-system.md` | 5 | Design tokens + components |
| `src/` + `tests/` + `.env.example` + setup files | 6 | Scaffolded project with security + middleware |
| `agent/design/f{N}.md` | 7 | Per-feature design plans |
| `reflex/history/cycle-NN/pass-NNN/` | 8 | Reflex audit artifacts |

## Cost + time estimate (representative)

| Phase | Wall-clock | Tokens (≈) |
|---|---|---|
| 1 — Capture | <2 min | <1k |
| 2 — Research | 5-15 min | 5-15k |
| 3 — Expand REQS | 3-5 min | 3-5k |
| 4 — SPECS + PLANS | 3-5 min | 3-5k |
| 5 — UI design system | 3-5 min | 2-4k |
| 6 — Scaffold | 5-10 min | 5-10k |
| 7 — Implement features | 30-90 min | 50-200k (depends on N features) |
| 8 — Reflex audit | 30-60 min | 50-100k |
| **Total** | **80-180 min** | **120-340k** |

Smaller projects (3-5 features) finish in <90 min; larger (10+ features) take 3-4 hours and may iterate reflex 2-3 times.

## How this skill self-evolves

Reflex's Dim 18 (philosophy self-audit) runs against generated projects too. If repeated audits surface the same gap class — e.g., "kit-generated apps consistently miss [pattern X]" — promote the gap to a new requirement-research dimension or a new design-system component. The kit improves with usage, same mechanism that grew Dim 23 from cycle-01's trace audit.
