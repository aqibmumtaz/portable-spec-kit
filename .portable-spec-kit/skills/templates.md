<!-- Section Version: v0.6.55 -->
# Agent File Templates — Pointer Index (Skill: Project Setup)

> **Source of truth lives in `.portable-spec-kit/templates/`.** This file is the quick-reference index — open the externalized template files for the actual scaffolding bodies. Editing this skill file does not change the templates the kit ships; edit the externalized files in `.portable-spec-kit/templates/` instead.

## Why the split

Prior to v0.6.54, template bodies were inlined here. The kit now externalizes each template to its own file under `.portable-spec-kit/templates/` so that:

- Each template carries its own self-documenting header (`<!-- TEMPLATE-KIND · GENERICITY · LAST-AUDITED -->`)
- `psk-template-quality.sh` can lint each file against the 7-criterion Quality Bar
- `psk-sync-check.sh` can verify round-trip scaffolding without parsing markdown blocks out of this skill file
- Templates evolve independently of the skill index that references them

When you scaffold or restructure agent files, read the externalized file directly — do not copy from this index.

## Template index

| Template | File | Purpose |
|---|---|---|
| **agent/AGENT.md** | `.portable-spec-kit/templates/agent-AGENT-template.md` | Project-specific AI instructions — stack, rules, brand, Definition of Done, optional Jira config. Rarely changes after setup. |
| **agent/AGENT_CONTEXT.md** | `.portable-spec-kit/templates/agent-AGENT_CONTEXT-template.md` | Living project state — version, phase, what's done, what's next, key decisions, blockers. Updated after every significant work batch. |
| **agent/REQS.md** | `.portable-spec-kit/templates/agent-reqs-template.md` | Business requirements in client language. Raw input + clarifying assumptions + R-row table + per-R detail blocks. First pipeline stage. |
| **agent/SPECS.md** | `.portable-spec-kit/templates/agent-specs-template.md` | Features mapped from requirements (R→F). Feature table + acceptance criteria + scope-change record. Second pipeline stage. |
| **agent/PLANS.md** | `.portable-spec-kit/templates/agent-plans-template.md` | System architecture, tech stack, technical requirements, ADL. Third pipeline stage — HOW the system is built (macro). |
| **agent/RESEARCH.md** | `.portable-spec-kit/templates/agent-research-template.md` | Research overview across all pipeline stages — open/active questions, topic indexes, research principles. Support file. |
| **agent/DESIGN.md** | `.portable-spec-kit/templates/agent-design-template.md` | Design overview + per-feature design index + cross-cutting decisions. Fourth pipeline stage — HOW each feature works (micro). |
| **agent/TASKS.md** | `.portable-spec-kit/templates/agent-tasks-template.md` | Task tracking by release version + QA-finding sections appended by reflex. Fifth pipeline stage — BUILD. |
| **agent/RELEASES.md** | `.portable-spec-kit/templates/agent-releases-template.md` | Published release notes — what shipped, user-facing summary per version. Sixth pipeline stage — RELEASE. |
| **agent/design/f{N}-*.md** | `.portable-spec-kit/templates/agent-design-plan-template.md` | Per-feature design plan (Context → Approach → Decisions → Data Model → Edge Cases → Commands → Files → Tests → Implementation Order → State). Created per F{N} feature. |
| **General plan** | `.portable-spec-kit/templates/plan-template.md` | Non-feature plan scaffold (status frontmatter + 12 sections). Used by `psk-plan-save.sh` for plan-mode persistence. |
| **README.md** | `.portable-spec-kit/templates/project-readme-template.md` | Project root README — overview, tech stack, getting started, env vars, project structure, features, testing, deployment. |
| **Workflow doc** | `.portable-spec-kit/templates/flow-doc-template.md` | `docs/work-flows/NN-name.md` scaffold for documenting executable kit workflows. |

> **Audit machinery:** `bash agent/scripts/psk-template-quality.sh --all` lints every externalized template against the 7-criterion Quality Bar. Per-template audit history at `.portable-spec-kit/templates/.audit-log.yaml`.

---

## ADL Format Details (PLANS.md)

> This reference content is intentionally retained in the skill file — it is metadata about *how to fill in* the ADL section of PLANS.md, not a template body that would belong in `.portable-spec-kit/templates/`.

- **Format:** `| ADR-NNN | YYYY-MM-DD | Decision | Options Considered | Chosen | Why | Impact | Plan Ref |`
- **Plan Ref** — if the decision was made in a feature plan, link to it: `[F63](design/f63-jira-integration.md#decisions)`. This connects the one-line ADR summary to the full rationale in the plan file. Leave `—` if decision has no associated plan.
- **ADR numbering:** Sequential, 3-digit zero-padded (ADR-001, ADR-002, …). First decision = ADR-001.
- **Date:** ISO 8601 (YYYY-MM-DD). Convert relative dates ("last Thursday") to absolute.
- **Impact:** What files, components, or systems are affected.
- **Newest first:** most recent decision at top (prepend, don't append).
- **ADL is immutable history** — never delete or modify past decisions. If a decision is superseded → add a new row: "ADR-005 supersedes ADR-002".
- **When to add:** stack chosen/replaced, database schema changed, API pattern changed, test framework changed, methodology adopted, architecture pattern changed, security approach changed.
- **NOT for:** bug fixes, small implementation choices, variable names, content changes, feature additions with no architecture impact.

---

## Development Flow (pipeline reference)

> Conceptual reference for how the pipeline files relate. Each stage's template body lives in its externalized file (see index above).

**6 pipeline stages:**
```
REQS.md → SPECS.md → PLANS.md → DESIGN.md → TASKS.md → RELEASES.md
require    specify    architect    design      build      release
  │          │          │           │           │          │
reqs/      specs/    plans/      design/     tasks/    releases/
```

**3 support files (feed into all stages):**
```
RESEARCH.md + research/   ← investigation — feeds into ANY stage when decisions need data
AGENT.md                  ← project config, stack, rules, Definition of Done
AGENT_CONTEXT.md          ← living state — what's done, what's next, blockers
```

**Full traceability chain:** `Raw Input (reqs/) → R (REQS.md) → F (SPECS.md) → Research → Design (DESIGN.md + design/) → ADR (PLANS.md) → T (tests/) → Release (RELEASES.md + releases/)`

**Feedback loops:** Pipeline is logical order, not a gate. Iteration expected — design reveals new requirement → back to REQS.md → flow forward. When iterating backwards, update the upstream file FIRST, then cascade changes forward.
