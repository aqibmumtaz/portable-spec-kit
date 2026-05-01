# 18 — Professional Project Generation (v0.6.14+)

> **What:** Turn raw user requirements (one sentence to a paragraph) into a polished, secure, working application via 8 fully-automated phases. The kit drives research, requirement expansion, UI design, security scaffolding, feature implementation, and reflex audit — end to end.
>
> **When to use:** any new project where you want the kit to do the heavy lifting (not just scaffold empty files). Also works for retrofitting existing projects (skips Phase 1-5, runs Phases 6-8 against existing code).
>
> **Orchestrator:** `bash agent/scripts/psk-orchestrate.sh "<your raw requirement>"` (or `--reqs-file path`)
>
> **Companion skills:** `project-orchestration.md` (orchestrator) · `requirement-research.md` (Phase 2-3) · `ui-design-system.md` (Phase 5) · `security-baseline.md` (Phase 6)

## Why this flow exists

The default `project-setup.md` flow scaffolds the agent/ directory and a chosen source-structure template — empty files that the user (with the agent) then fills in feature-by-feature.

That's fine for prototypes and small experiments. It's **not** how you build a polished, secure, professional app. Polished apps need:

- **Domain research** before specs — what does best-in-class look like in this category?
- **Expanded requirements** that cover non-functional, security, accessibility, compliance — not just the user's verbatim wishlist
- **A real design system** — color tokens, type scale, components — not "I made it up as I went"
- **Security baked in from day one** — auth, validation, rate limit, secrets — not "we'll add it later"
- **Adversarial verification** — reflex audits the result so what ships is what was promised

This flow does all of that, with confirm-with-user gates between phases so the user redirects when needed but doesn't have to drive every step.

## The 10 phases (overview)

The orchestrator drives ten phases sequentially. Each phase has a primary deliverable and a confirm-with-user gate; the user can redirect between phases but does not have to drive every step.

| # | Phase | What | Primary output | Time |
|---:|---|---|---|---|
| 1 | **capture** | Capture raw user req + 3 multi-choice clarifying questions (user / scale / constraints) | `agent/REQS.md` `## Raw Input` | <2 min |
| 2 | **research** | 7-dimension domain + tech research (domain · competitors · user journey · stack · OWASP · WCAG · compliance) — every claim cited | `agent/research/domain-and-tech-{date}.md` | 5-15 min |
| 3 | **expand-reqs** | Expand to R1-R30+ professional requirements across Functional / Non-functional / Security / UX-UI / Operational categories | `agent/REQS.md` `## Requirements` | 3-5 min |
| 4 | **specs-plans** | Generate SPECS (R→F mapping with acceptance criteria) + PLANS (Stack + Data Model + API + ADL) | `agent/SPECS.md` + `agent/PLANS.md` | 3-5 min |
| 5 | **ui-system** | Polished design system: 8-color palette × 2 modes, 8-step type scale, 4/8 spacing grid, 12 component primitives, motion presets, breakpoints, a11y tokens | `agent/design/ui-system.md` + stack-specific export (Tailwind / SwiftUI / Material) | 3-5 min |
| 6 | **scaffold** | Source tree + auth scaffolding + middleware stack + input validation + secret hygiene + CI workflow + health endpoint + API versioning | `src/` + `tests/` + `.env.example` + `README.md` | 5-10 min |
| 7 | **features** | Feature-by-feature loop: design plan → tests (red) → implement (green) → run gates → commit (one feature = one commit) → mark `[x]` | `agent/design/f{N}.md` per feature + commits + tests | 30-90 min |
| 8 | **release-prep** | Run kit standard release ceremony — `bash agent/scripts/psk-release.sh prepare` then iterate `next` through 10 steps with critic spawns at Step 4 + Step 9 | Version bump + RELEASES + CHANGELOG entries + dual-gate validation | 10-15 min |
| 9 | **reflex-audit** | Reflex autoloop until convergence (GRANTED / REGRESSION / plateau / fix-rate drop) — QA-Agent + Dev-Agent peer-exchange across 24 dimensions | `reflex/history/cycle-NN/pass-NNN/` | 30-60 min |
| 10 | **final-handoff** | Verify R→F→T coverage, polish README runtime instructions, generate one-page `HANDOFF.md`, final commit, summary to user | `README.md` + `HANDOFF.md` | 5 min |

**Sequence:** raw-req → capture → research → expand-reqs → specs-plans → ui-system → scaffold → features → release-prep → reflex-audit → final-handoff → polished, secure, working, audited project

**Total wall-clock:** 80-180 min for a typical mid-sized project (5-10 features). Smaller projects finish in <90 min; larger may iterate reflex 2-3 times.

## How to invoke — natural language (preferred)

The kit listens for trigger phrases in any AI agent session. Just say what you want and the kit drives the whole flow. **You do not have to know the script name.**

| What you type to the agent | What kicks off |
|---|---|
| *"create a project for X"* / *"build me an app that does Y"* | Full 10-phase orchestration |
| *"create a full project"* / *"make it a full working project"* | Full 10-phase orchestration |
| *"generate the app from these requirements"* | Full 10-phase orchestration (uses pasted reqs as raw input) |
| *"make this professional"* / *"make this production-ready"* | Force professional mode (vs scaffold-only) |
| *"polished"* / *"secure"* / *"research-based"* | Force professional mode |
| *"redo design system"* | Re-run Phase 5 only |
| *"audit my project"* | Skip ahead to Phase 9 (reflex on existing code) |
| *"continue project generation"* / *"resume orchestration"* | Resume a paused orchestration (--resume) |
| *"abort generation"* / *"stop orchestration"* | Archive state, stop |
| *"just scaffold"* / *"empty setup"* / *"don't generate code"* | Fall back to legacy scaffold-only mode |

Behind the scenes, the agent auto-invokes `bash agent/scripts/psk-orchestrate.sh ...` with the right flags. You never have to memorize commands.

**Example conversation:**

> *You:* "Create a full working project for a recipe-sharing app where users can save favorites, add notes, and share recipes via WhatsApp."
>
> *Agent:* "I'll orchestrate this end-to-end. Phase 1: capturing your raw requirement now. Three quick clarifications:
> - Primary user: (a) home cooks (b) professional chefs (c) both
> - Scale: (a) personal use (b) public/community (c) commercial product
> - Hard constraints (pick all): (a) mobile-first (b) offline-capable (c) GDPR (d) WCAG AA
> Reply with picks and I'll continue research."

After your answers, the kit drives all 10 phases without you having to type more commands — except confirm-with-user gates between phases (which you can also redirect via natural language: *"redirect on stack — use Vue not React"*, *"add a 4th feature: meal planning"*, etc.).

## How to invoke — script (power users / CI)

### Brand-new project

```bash
mkdir my-recipe-app && cd my-recipe-app

# Install kit (one of the standard install paths)
curl -fsSL https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/install.sh | bash

# Kick off the generation
bash agent/scripts/psk-orchestrate.sh "I want a recipe app where users can save favorites and add notes"
```

The orchestrator drives all 8 phases. Each phase exits `AWAITING_X` for the AI agent (Claude Code / Cursor / etc.) to spawn the appropriate sub-agent, then re-run `psk-orchestrate.sh --resume` to advance.

### From a requirements file

```bash
bash agent/scripts/psk-orchestrate.sh --reqs-file requirements.txt
```

Useful when the requirement is multi-paragraph or has been pre-written by a stakeholder.

### Retrofitting an existing project

```bash
# In an existing project with code already written
bash agent/scripts/psk-orchestrate.sh --retrofit
```

Skips Phase 1-5 (assumes REQS / SPECS / PLANS / DESIGN already exist), runs Phase 6 (security scaffolding to gap-fill what's missing), Phase 7 (incremental feature implementation for any pending features), Phase 8 (reflex audit).

### Conversational invocation (no script)

The agent listens for trigger phrases and drives the flow without the user invoking the script:

| Phrase | What kicks off |
|---|---|
| *"create a project for X"* / *"build me an app that does Y"* | Full 8-phase flow |
| *"polished"* / *"professional"* / *"production-ready"* | Force professional mode |
| *"just scaffold"* / *"empty setup"* | Skip generation, scaffold only |
| *"redo design system"* | Re-run Phase 5 |
| *"audit my project"* | Skip to Phase 8 |

## Per-phase gates — what the user sees

Each gate is a brief multi-choice prompt. The user redirects between phases, not after.

### Phase 1 gate
```
I'm going to research [recipe app] for [end consumers] [public scale]
with [mobile-first, GDPR] constraints. ~5 min.

Proceed? (y/n/redirect)
```

### Phase 3 gate
```
Expanded 24 requirements:
  Functional (R1-R8): user accounts, save, search, notes, share, ...
  Non-functional (R9-R12): TTI <2s, p95 API <200ms, 99.9% uptime
  Security (R13-R17): Argon2id, JWT, OWASP A01-A07 mitigations
  UX/UI (R18-R21): mobile-first, dark mode, WCAG AA, motion-reduce
  Operational (R22-R24): structured logs, error budget, audit trail

Approve all / add / remove / redirect on category?
```

### Phase 5 gate
```
Design system:
  Palette: primary #F97316 (warm orange — food-domain)
           accent #65A30D (forest green — health-domain)
  Heading: Fraunces (serif, distinctive for recipe headers)
  Body: Inter (highly readable)
  12 components scaffolded: Button × 3, Input, Card, Modal, ...

Approve / tweak palette / different fonts / more components?
```

### Phase 8 gate
```
✓ Reflex GRANTED at iter 2
  - 14 findings filed in pass-001 (1 CRIT, 4 MAJ, 9 MIN)
  - 14 fixes landed by Dev-Agent
  - 0 regressions in pass-002 verification
  - Tests: 247 passing (197 framework + 50 benchmarking)

Project ready. README.md + run instructions in /. Deploy when ready.
```

## What you get at the end

A complete working application with:

- **Source code** — secure backend + polished frontend + working APIs
- **Tests** — happy-path + adversarial per feature; per-stack test runner
- **Design system** — `agent/design/ui-system.md` + stack export (Tailwind config / SwiftUI extension / Material theme / etc.)
- **Documentation** — `README.md` (setup + run + deploy) + `CHANGELOG.md` + agent/RELEASES.md
- **Reflex audit trail** — `reflex/history/cycle-NN/pass-NNN/` with findings.yaml + signoff.md
- **Security baseline** — auth + validation + rate limit + middleware all wired
- **CI/CD** — GitHub Actions workflow runs tests on every push (config-gated)
- **Deploy hints** — stack-appropriate (Vercel for Next.js, Fly for FastAPI, etc.)

## Comparison to alternatives

| Approach | Time | Polish | Security | Audit |
|---|---|---|---|---|
| **Manual coding** | days | depends | depends | none |
| **Vibe coding with AI agent** | hours | inconsistent | weak | none |
| **Generic scaffolder** (create-next-app, etc.) | minutes | template-only | basic | none |
| **Kit's professional generation flow** | 80-180 min | high (design system + tokens) | high (OWASP + adversarial tests) | reflex GRANTED |

## Anti-patterns

- **Don't skip the gates.** Each gate is a redirect opportunity. If you let the kit barrel through and dislike the result, you've wasted 2 hours instead of 10 minutes.
- **Don't run on a frozen / network-disabled environment.** Phase 2 requires WebFetch / WebSearch for research.
- **Don't expect the kit to know your business.** It researches the domain (recipe apps, finance apps, etc.) but not your specific company / users / constraints. Provide those in the raw req or in clarification answers.
- **Don't over-spec.** A 1-paragraph raw req is fine. A 10-page PRD will produce 80+ R-rows the kit then has to slog through. Distill before invoking.

## How this evolves

Reflex Dim 18 (philosophy self-audit) runs against generated projects. If repeated audits across projects surface the same gap class — e.g., "kit-generated apps consistently miss [pattern]" — the gap promotes to a new dimension or a new design-system component. The flow improves with usage, same mechanism that grew Dim 23 from cycle-01's trace audit on the kit itself.
