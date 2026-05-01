# Skill — Requirement Research + Expansion (v0.6.14+)

> **When loaded:** Phase 2 of `project-orchestration.md` — kit researches the domain + tech + risks before expanding REQS.
> **What it does:** turns loose requirements (one sentence to a paragraph) into a researched, sourced, comprehensive REQS.md.
> **Output:** `agent/research/domain-and-tech-{date}.md` (research notes) + Phase 3 expanded `agent/REQS.md`.

The kit is the difference between a generic app and a professional one. Generic apps come from reqs the user wrote alone in 5 minutes. Professional apps come from reqs that researched the domain, surveyed competitors, mapped user journeys, mitigated OWASP threats, met WCAG AA, and respected compliance — *before* a single line of code.

## Inputs

1. **Raw user input** — captured in `agent/REQS.md` `## Raw Input` section by Phase 1 of project-orchestration
2. **Clarification answers** — 3 multi-choice questions from Phase 1 (user / scale / constraints)
3. **Existing codebase context** — if retrofitting onto an existing project, scan stack + agent/AGENT_CONTEXT.md

## The 7 research dimensions

For each dimension, produce a section in `agent/research/domain-and-tech-{date}.md` with **citations** (URLs from WebFetch / WebSearch). No citation = unverified claim = not allowed.

### Dimension 1 — Domain landscape

What kind of app is this? Search: *"[domain] best practices 2026"* / *"[domain] core features"*. Identify:

- **Top 3 reference products** in the category (best-in-class)
- **Common features** (table-stakes — must have)
- **Differentiating features** (delight — what separates leaders from laggards)
- **Anti-patterns** (don't-do-these — common mistakes)
- **Industry trends** (2-3 currently-rising patterns relevant to this app)

Output: 80-200 words + 3-5 source URLs.

### Dimension 2 — Competitive analysis

Pick 2-3 best-in-class competitors (from Dim 1). For each:

- **What they do well** (the bar to meet)
- **Where they fall short** (gap to exploit)
- **Their stack** (if visible — wappalyzer-equivalent observation)
- **Their UX patterns** (e.g., "uses bottom sheet for filters", "has skeleton loaders")

Output: table per competitor + 1-2 sentence synthesis ("kit's project should match X but improve Y").

### Dimension 3 — User journey map

Primary user (from Phase 1 clarification) doing the primary task. Map the journey:

```
[entry] → [discover] → [decide] → [act] → [confirm] → [retain]
```

For each step: what does the user think / feel / do? What can go wrong (error states)? What success looks like.

Then 1-2 supporting flows (e.g., onboarding, settings, account management).

Output: simple ASCII diagram + per-step table. Cite UX research if available (NN/g, Baymard, etc.).

### Dimension 4 — Tech stack

Recommend a stack. Each layer has 2-3 options + chosen pick + rationale + 1 citation.

| Layer | Options | Chosen | Why (citation) |
|---|---|---|---|
| Frontend framework | Next.js / Remix / SvelteKit | Next.js 14 App Router | Best ecosystem + RSC perf wins (vercel docs) |
| Backend / API | Next.js API routes / Hono / FastAPI | Next.js + tRPC | Type safety end-to-end (trpc.io) |
| Database | Postgres / SQLite / MongoDB | Postgres + Prisma | ACID + ecosystem (prisma docs) |
| Auth | NextAuth / Clerk / Auth0 / custom | NextAuth + Argon2 | Self-hosted + free + standard |
| Hosting | Vercel / Fly / Railway | Vercel | Native Next.js (vercel docs) |
| ... | | | |

Constraint matching: if user said "offline-capable" → choose stack that supports IndexedDB + service worker (e.g., Next.js + Dexie). If "mobile-first" + "offline" → consider React Native + WatermelonDB instead.

### Dimension 5 — Security threats (OWASP-mapped)

Map app surface to OWASP Top 10 (2021). For each relevant threat:

- **Threat** (e.g., A01 Broken Access Control)
- **App surface affected** (e.g., user-data API endpoints)
- **Mitigation pattern** (e.g., row-level authz check at every query, never trust client-supplied user_id)
- **Test approach** (e.g., adversarial test: log in as user A, request user B's data — must 403)

Skip threats that don't apply (e.g., A09 Logging if app has no business logic; A06 if no third-party deps).

Output: filtered OWASP table, 5-10 rows.

### Dimension 6 — Accessibility baseline

WCAG 2.1 Level AA is the minimum. Check:

- **Perceivable** — color contrast (4.5:1 text / 3:1 UI), alt text, captions for video
- **Operable** — keyboard nav, focus states, no keyboard traps, skip-link
- **Understandable** — clear labels, predictable nav, error identification
- **Robust** — ARIA, semantic HTML, no SR-only hacks where native works

Domain-specific:
- Content app → consider screen-reader-first design + ARIA live regions
- Form-heavy → autocomplete attrs + clear inline errors
- Data viz → text alternatives + keyboard interaction patterns

Output: WCAG checklist + 3-5 domain-specific items.

### Dimension 7 — Compliance

Only if applicable. Check user-data context:

| Regime | When | Implications |
|---|---|---|
| GDPR | EU user data | Right-to-delete, consent banners, DPA, data minimization |
| CCPA | California users | "Do not sell" link, deletion request, transparency report |
| HIPAA | US healthcare data | BAA with hosting, audit logs, encryption-at-rest |
| PCI-DSS | Card payments | Use a tokenizer (Stripe Elements), never store PAN |
| COPPA | Under-13 users | Parental consent flow, no behavioral ads |
| SOC2 | B2B SaaS | Audit logs, change management, vendor management |

Output: applicable regimes table + concrete obligations the app must meet.

## Research → REQS expansion (Phase 3)

After all 7 dimensions are written, generate REQS.md `## Requirements` section. Each R has 5 fields:

```markdown
## Requirements

### R1 — User authentication with email + OAuth
- **Category:** Functional
- **Statement:** End users authenticate via email/password or Google OAuth.
- **Acceptance:** (1) Email signup with verification (2) Login + logout flow (3) Google OAuth via NextAuth (4) Session expires after 30d inactive
- **Source:** Dimension 4 — NextAuth chosen as auth layer
- **Maps to:** F1 (Auth feature)

### R2 — Argon2id password hashing
- **Category:** Security
- **Statement:** Passwords hashed with Argon2id (memory=19MiB, iter=2, parallelism=1).
- **Acceptance:** No plaintext passwords ever touch disk or logs. Hash on signup; verify on login.
- **Source:** Dimension 5 — A02 Cryptographic Failures (OWASP). OWASP password storage cheat sheet.
- **Maps to:** F1 (Auth feature)

...
```

Categories (use these 7 labels — Phase 7 v0.6.23+, P8 Client-Grade Output):

- **Functional** — what the app does (typically 8-12 rows)
- **Non-functional** — perf budgets, scalability, reliability (3-5 rows)
- **Technical** — stack choices, runtime, language, framework version pins (2-4 rows)
- **Non-technical** — legal, privacy, content, branding, business constraints (1-3 rows)
- **UI/UX (MANDATORY MINIMUM 12 rows)** — see breakdown below. Capped at 20 rows to avoid over-spec
- **Operational** — logging, monitoring, error handling, deploy, CI/CD (3-5 rows)
- **Security** — auth, authz, data protection, input validation (4-6 rows)

### UI/UX 12-bullet minimum coverage (P8 — Client-Grade Output by Default)

Every project that ships UI MUST have R-rows covering these 12 areas. The kit's `psk-ui-polish-check.sh` and `check_ui_requirements_coverage` enforce this — projects that skip rows here ship as half-done products. SearchSocialTruth's first cycle missed 7 of the 12 (no onboarding, no skip-link, no aria-live, no confidence bar, no share button, no manual dark-mode toggle, no WhatsApp QR) — that gap is what motivated this rule.

| # | Area | Example R-row |
|---|---|---|
| 1 | Layout / page structure | "Mobile-first responsive layout, breakpoints sm/md/lg/xl" |
| 2 | Component primitives | "12 design-system primitives ship: Button/Card/Input/Modal/Tabs/Toast/Tooltip/Dropdown/Pagination/Spinner/Badge/Banner" |
| 3 | Interactions | "Verdict card click reveals sources panel; Esc closes" |
| 4 | Accessibility (WCAG 2.1 AA) | "Skip-link, aria-live verdicts, focus rings, screen-reader compatibility" |
| 5 | Responsive | "Touch targets ≥44×44px, single column <768px" |
| 6 | Dark mode | "Auto + manual toggle, persisted, respects prefers-color-scheme, contrast 4.5:1 / 3:1" |
| 7 | Animation / motion | "All animations gated by prefers-reduced-motion: reduce" |
| 8 | Loading / empty / error states | "Every async surface has skeleton + empty hint + error boundary" |
| 9 | Onboarding | "First-run 3-step tour with always-visible Skip; persisted" |
| 10 | Brand assets | "Favicon, logo, OG image, theme color in <head>" |
| 11 | Internationalization | "Top-N locales w/ RTL where needed; Intl.DateTimeFormat" |
| 12 | Forms | "Inline validation, aria-describedby on errors, helpful empty-state copy" |

If the user's project genuinely has zero UI surface (CLI tool, library, server-only API), the agent surfaces that with a confirm-with-user gate — `"This appears to be a non-UI project. Skip the UI/UX category? (y/n)"` — and only on `y` does the kit drop the 12-row minimum.

Aim for **25-40 R-rows total** for a typical mid-sized app. Smaller projects can have 18-25; larger may hit 50+. If exceeding 60, group into `## R Group N` sub-sections.

## Honesty rules

- **No placeholder R-rows.** Every R must have a real source — research dimension, OWASP threat, WCAG criterion, or "user-stated" (verbatim from raw input).
- **No vague acceptance.** *"Works correctly"* is not acceptance. *"Returns 200 with valid JWT in <300ms p95"* is.
- **Cite or don't claim.** If a dimension's claim isn't backed by a URL, drop the claim or mark `(unverified)`.
- **Match scale.** A 5-feature MVP doesn't need R31 about distributed tracing — scope to user's actual scale.

## Confirm-with-user gate (end of Phase 3)

Show expanded REQS as a table (id · category · 1-line statement). Ask:

```
Expanded N requirements across 5 categories. Want to:
  (a) Approve all → continue to SPECS
  (b) Add more requirements (specify which)
  (c) Remove some (specify R-ids)
  (d) Redirect on a category (e.g., "less security, this is internal-only")
```

User says (a) → continue. Anything else → revise + re-confirm.

## Anti-patterns

- **Don't research on the user's tab forever.** Cap research at 15 minutes wall-clock + 15k tokens. If unclear after that, ask a 4th question (this is the only time a 4th question is OK).
- **Don't pad REQS to look thorough.** Quality > count. 18 well-sourced R-rows beats 35 generic ones.
- **Don't lock in a stack the user dislikes.** If user says "I hate React," respect that even if research says it's optimal — pick the runner-up.
- **Don't skip the gate.** User redirects between phases, not after.
