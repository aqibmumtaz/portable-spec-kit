<!-- Section Version: v0.5.5 -->
# Agent File Templates (Skill: Project Setup)

Use these exact templates when creating agent/ files.

**agent/AGENT.md:**
```markdown
# AGENT.md — <Project Name>

> **Purpose:** Project-specific AI instructions — stack, rules, brand, key decisions.
> **Role:** Read at start of every session. Rarely changes after setup.

## Project Location
`<path>`

## On Every Session Start:
1. Read user profile from `.portable-spec-kit/user-profile/` — user preferences
2. Read `agent/AGENT.md` — project config, stack, rules
3. Read `agent/AGENT_CONTEXT.md` — project state
4. Read `agent/REQS.md` — requirements
5. Read `agent/SPECS.md` — features
6. Read `agent/PLANS.md` — architecture
7. Read `agent/RESEARCH.md` — active research questions
8. Read `agent/DESIGN.md` — design overview
9. Read `agent/TASKS.md` — current tasks

## Update AGENT_CONTEXT.md When:
1. After completing a significant batch of work (feature built, tests passing)
2. After committing — commit is a natural checkpoint
3. Before any push — context must be current before code reaches remote

## Stack
| Layer | Technology |
|-------|-----------|
| Frontend | TBD |
| Backend | TBD |
| Database | TBD |
| Hosting | TBD |
| Conda Env | TBD (Python projects only) |

## Brand
- Primary: `#000000`
- Accent: `#000000`
- Fonts: system-ui

## AI Config
- Provider: TBD (OpenAI / Claude / other)
- Models: TBD
- Dev Server Port: TBD (auto-assigned)

## Key Rules
- All secrets in `.env` only — NEVER commit API keys
- Test before deploy — all test cases must pass

## Jira Config (optional)
<!-- Remove this section if not using Jira integration -->
- **JIRA_URL:** https://yourorg.atlassian.net
- **JIRA_PROJECT_KEY:** MYPROJ
- **Default Issue Type:** Task
- **Time tracking idle threshold:** 15 min

### Username → Jira Email Mapping
| @username | Jira Email |
|-----------|-----------|
<!-- | @aqib | aqib@company.com | -->

### Transition Mapping (optional — auto-detects if not set)
| Kit Status | Jira Transition Name |
|-----------|---------------------|
| done      | Done                |

## Deployment
<!-- Added at release time -->
```

**agent/AGENT_CONTEXT.md:**
```markdown
# AGENT_CONTEXT.md — <Project Name>

> **Purpose:** Living project state — what's done, what's next, key decisions, blockers.
> **Role:** Read at session start. Updated after significant work, after commits, and before any push.

## Current Status
- **Version:** v0.1.0
- **Kit:** vX.X.X
- **Phase:** Setup
- **Status:** Initializing

## What's Done
- [ ] Project initialized

## What's Next
- [ ] Define specs
- [ ] Choose tech stack

## Key Decisions
| Decision | Choice | Why |
|----------|--------|-----|
| | | |

## Blockers
None

## File Structure
\`\`\`
<project>/
├── agent/
├── src/
└── ...
\`\`\`

## Project-Specific Rules
<!-- Must-do and must-not-do rules specific to this project -->

## Last Updated
- **Date:** YYYY-MM-DD
- **Summary:** Project initialized
```

**agent/REQS.md:**
```markdown
# REQS.md — <Project Name>

> **Purpose:** Business requirements in client/stakeholder language.
> Raw input preserved in reqs/. Technical requirements go in PLANS.md.
> **Role:** First pipeline stage — WHAT is needed.

## Requirements
| # | Requirement | Type | Priority | Source | Status | Created | Approved by | Approved date | Depends | Research | Raw Ref |
|---|-------------|------|----------|--------|--------|---------|-------------|---------------|---------|----------|---------|

<!-- Type: Functional / Non-functional / Constraint -->
<!-- Status: Draft → Approved → Implemented → Verified -->
<!-- Created: when requirement first captured -->
<!-- Approved by: user, client name, "team" -->
<!-- Depends: R{N} or — -->
<!-- Research: link to research/reqs/r{N}.md or — -->

## Assumptions
| # | Assumption | Impact if wrong | Verified | Verified date |
|---|-----------|----------------|----------|--------------|

## Decisions
| # | Decision | Type | Why | Research |
|---|----------|------|-----|----------|
<!-- Type: mutual / user-override / user-direct / agent-recommended / constraint-driven -->

## Scope Changes
| Date | Type | Req | Description | Reason |
|------|------|-----|-------------|--------|
<!-- Type: DROP / ADD / MODIFY / REPLACE -->
```

**agent/SPECS.md:**
```markdown
# SPECS.md — <Project Name>

> **Purpose:** Features mapped from requirements. R→F traceability.
> Requirements live in REQS.md.
> **Role:** Second pipeline stage — WHAT to build.

## Overview
Brief description of what this project does and who it's for.

## Features
| # | Feature | Req | Priority | Size | Depends | Status | Completed | Design | Tests |
|---|---------|-----|----------|------|---------|--------|-----------|--------|-------|
| F1 | | R1 | High | M | — | [ ] | — | — | — |

<!-- Size: S / M / L -->
<!-- Depends: F{N} or — -->
<!-- Completed: YYYY-MM-DD when [x] -->
<!-- Design: link to design/f{N}.md or — -->

## Scope
- **In scope:**
- **Out of scope (future):**

## Feature Acceptance Criteria

### F1 — Feature Name
- [ ] Criterion 1 (what a passing state looks like)
- [ ] Criterion 2
- [ ] Edge case: what happens when X is empty

## Decisions
| # | Decision | Type | Why | Research |
|---|----------|------|-----|----------|
```

**agent/PLANS.md:**
```markdown
# PLANS.md — <Project Name>

> **Purpose:** System-level architecture. Tech stack. Technical requirements. ADL.
> **Role:** Third pipeline stage — HOW the system is built (macro).

## Stack
| Layer | Technology | Why |
|-------|-----------|-----|

## Technical Requirements
> Technical decisions from client input. Each researched before committing.

| # | Requirement | Source | Req Ref | Status | Research |
|---|-------------|--------|---------|--------|----------|
<!-- Req Ref: links back to REQS.md R{N}. Status: Stated → Researched → Confirmed / Overridden -->

## Architecture
High-level system design.

## Data Model
| Table/Type | Key Fields |
|------------|-----------|

## API Endpoints
| Method | Path | Description |
|--------|------|-------------|

## Security
- Key security considerations for this project

## Research
> Full research index lives in RESEARCH.md.
> See [RESEARCH.md](RESEARCH.md) for all investigations across all stages.

## Architecture Decision Log

> Newest first. Research column links to research file. Plan Ref links to design plan.

| # | Date | Decision | Options | Chosen | Why | Impact | Research | Plan Ref |
|---|------|----------|---------|--------|-----|--------|----------|----------|

## Decisions
| # | Decision | Type | Why | Research |
|---|----------|------|-----|----------|

## Verification
- How to test the system end-to-end
```

**agent/RESEARCH.md:**
```markdown
# RESEARCH.md — <Project Name>

> **Purpose:** Research overview — all investigations across all pipeline stages.
> Per-topic research files in research/{stage}/ subdirectories.
> **Role:** Support file — feeds into any stage when decisions need data.

## Active Questions
| # | Question | Stage | Urgency | Status |
|---|---------|-------|---------|--------|
<!-- Questions currently being investigated -->

## Research Index
| # | Topic | Stage | Depth | Status | File |
|---|-------|-------|-------|--------|------|
<!-- Stage: reqs / specs / plans / design / tasks / releases -->
<!-- Depth: None / Quick / Standard / Deep -->

## Research Principles
- Cost-effectiveness: every tech choice must justify cost vs alternatives
- Performance: every choice must consider latency, throughput, scaling
- Modern stack: prefer current, well-maintained tech
- Evidence-based: decisions backed by data, not habit

## Decisions
| # | Decision | Type | Why | Research |
|---|----------|------|-----|----------|
```

**agent/DESIGN.md:**
```markdown
# DESIGN.md — <Project Name>

> **Purpose:** Design overview — how features are built within the architecture.
> Per-feature designs in design/ subdirectory.
> **Role:** Fourth pipeline stage — HOW each feature works (micro).

## Design Principles
Key patterns and conventions across all features.

## Design Index
| Feature | Design | Status |
|---------|--------|--------|

## Cross-Cutting Decisions
| # | Decision | Type | Why | Research |
|---|----------|------|-----|----------|
```

**agent/TASKS.md:**
```markdown
# TASKS.md — <Project Name>

> **Purpose:** Task tracking by release version.
> **Role:** Fifth pipeline stage — BUILD.

## v0.1 — Current
- [x] Project setup @username (YYYY-MM-DD)
- [ ] Task 1 @username
- [ ] Task 2

<!-- Completion date (YYYY-MM-DD) added automatically when marked [x] -->

### Blocked
<!-- Tasks waiting on dependencies -->

## Backlog (Future Releases)
- [ ] Future feature 1

## Decisions
| # | Decision | Type | Why | Research |
|---|----------|------|-----|----------|

## Progress Summary
| Version | Tasks Done | Tests | Status |
|---------|:----------:|:-----:|--------|
| v0.1 | 1 | 0 | In Progress |
```

**agent/RELEASES.md:**
```markdown
# RELEASES.md — <Project Name>

> **Purpose:** Published release notes — what shipped, user-facing summary.
> Full traceability details in releases/ subdirectory.
> **Role:** Sixth pipeline stage — RELEASE.

## v0.1 — Title (Date)
Released by: @username
Full details: [releases/v0.1-release-summary.md](releases/v0.1-release-summary.md)

### What's New
- Feature 1 — one-line description
- Feature 2 — one-line description

### Improvements
- Improvement description

### Bug Fixes
- Fix description

### Tests
- X tests passing

### Breaking Changes
- (none, or list)

## Decisions
| # | Decision | Type | Why | Research |
|---|----------|------|-----|----------|
```

---

## Feature Plan Template

Every feature (F{N}) in SPECS.md gets a plan file in `agent/design/f{N}-feature-name.md`:

```markdown
# Plan: F{N} — Feature Name

## Context
What + why. Requirement ref (Rn).

## Approach
Architecture, tech choices, high-level design.

## Decisions
| Decision | Options Considered | Chosen | Why |
|----------|-------------------|--------|-----|
Auto-flows to PLANS.md ADL with link back to this file.

## Data Model / Syntax
Schema, formats, config. (skip if none)

## Edge Cases
(filled during design or implementation)

## Commands
New commands. (skip if none)

## Config Changes
AGENT.md, .env, framework. (skip if none)

## Scope Exclusions
What this does NOT do and why.

## Files to Modify
New + existing.

## Tests
Maps to SPECS.md acceptance criteria.

## Implementation Order
Build sequence with dependencies.

## Current State
Plan only / In progress / Done
```

---

## ADL Format Details (PLANS.md)

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

## README.md Template

Create on project setup. Update as the project evolves.

```markdown
# Project Name

Brief one-line description of what this project does.

## Overview
2-3 sentences explaining the project's purpose, who it's for, and what problem it solves.

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Frontend | ... |
| Backend | ... |
| Database | ... |
| Hosting | ... |

## Getting Started

### Prerequisites
- Node.js 18+
- Python 3.9+ (if applicable)

### Installation
\`\`\`bash
# Clone and install
npm install
\`\`\`

### Running Locally
\`\`\`bash
npm run dev    # http://localhost:XXXX
\`\`\`

### Environment Variables
Copy `.env.example` to `.env` and fill in your keys.

## Project Structure
\`\`\`
src/
├── ...        ← brief description
\`\`\`

## Features
- Feature 1
- Feature 2

## Testing
\`\`\`bash
npm test              # run tests
npm run test:coverage # with coverage
\`\`\`

## Deployment
Deployment instructions (added at release time).

## Contributing
<!-- Contributing guidelines if applicable -->

## Author
<!-- Author name and contact -->

## License
<!-- Add license if applicable -->
```

---

## Development Flow

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
