# Changelog

All notable changes to the Portable Spec Kit are documented here.

> **Versioning:** Each release (v0.N) is built from a series of incremental patches (v0.N.x).
> Completed releases show minor only (v0.3, v0.2, v0.1, v0.0). Active release shows full patch version.

---

## v0.5 — Jira Integration + Feature Design + Code Review + Scope Drift (April 2026)
**Built over:** v0.5.1 · **Tests:** 828 (683 framework across 53 sections + 145 benchmarking)

### Highlights
- **Jira Cloud integration** — `psk-jira-sync.sh` syncs completed tasks to Jira via REST API v3. Explicit-only (`sync to jira`), never automatic. PID-based lock, 5× retry with Retry-After, sanitized SYNC_RESULT.json
- **Automatic hours tracking** — Track A (agent session wall-clock) + Track B (psk-tracker OS daemon). Combined, deduplicated, confirmed by user before any Jira post
- **psk-tracker daemon** — OS-level 10s poll, FOCUS/BLUR logs, macOS/Linux/Windows support, WSL detection, headless/Docker exit
- **Feature Design Pipeline** — every feature in SPECS.md gets a design plan in `agent/design/`. 3 triggers: explicit, auto on SPECS.md, implementation gate. Decisions auto-flow to PLANS.md ADL
- **Auto Code Review (F65)** — two-layer review (psk-code-review.sh mechanical + AI judgment). Security anti-patterns, naming, TODO, secrets, structure. Runs after feature completion, advisory not blocking
- **Scope Drift Detection (F66)** — 5-dimension drift check (feature drift, requirement gaps, scope creep, architecture drift, plan staleness). psk-scope-check.sh with drift score. Proactive at session start
- **Release pipeline expanded** — prepare release now 9 steps (added code review + scope check after tests). Summary block shows 11 rows
- **Agent directory structure** — `agent/` root = markdown only, `agent/design/` = plans, `agent/scripts/` = bash

### Framework Changes
- Jira Integration section + Time Tracking section added to portable-spec-kit.md
- AGENT.md template: Jira Config (URL, project key, mappings, transition mapping, idle threshold)
- ADL format updated: Plan Ref column links decisions back to design files
- Development flow: SPECS → design/ → PLANS.md → TASKS → RELEASES (5-stage pipeline)
- Sync rule: 5 pipeline files (includes plan state update)
- Agent-Created Files rule: scripts/ subdirectory, directory structure diagram

### New Files
| File | Purpose |
|------|---------|
| `agent/scripts/psk-jira-sync.sh` | Jira REST API v3 sync script |
| `agent/scripts/psk-tracker.sh` | OS-level window focus daemon |
| `agent/scripts/install-tracker.sh` | Daemon installer (macOS/Linux/Windows) |
| `agent/scripts/uninstall-tracker.sh` | Daemon uninstaller |
| `agent/scripts/psk-tracker-report.sh` | Track B JSON report generator |
| `tests/mock-jira-server.sh` | Mock Jira HTTP server for testing |
| `tests/fixtures/jira/*.json` | 7 Jira API fixture files |
| `agent/scripts/psk-code-review.sh` | Automated code review (mechanical layer) |
| `agent/scripts/psk-scope-check.sh` | Scope drift detection (5 dimensions) |
| `docs/work-flows/15-jira-integration.md` | Jira sync flow doc |
| `docs/work-flows/16-feature-design.md` | Feature design flow doc |

### Tests
| Section | Tests | What it validates |
|---------|:-----:|-------------------|
| Section 51 | 28 | Jira integration rules, scripts, Track A/B, dedup, commands |
| Section 52 | 15 | Auto code review rules, two-layer, trigger, advisory |
| Section 53 | 12 | Scope drift detection, 5 dimensions, drift score, triggers |

---

## v0.4 — CI/CD Pipeline + Spec-Based Test Generation + Team Intelligence (April 2026)
**Built over:** v0.4.1 — v0.4.11 · **Tests:** 781 (636 framework across 50 sections + 145 benchmarking)

### Highlights
- **GitHub Actions CI** — ci.yml runs all 3 test suites on every push and PR; release.yml verifies tag matches framework version on v* tag push
- **Framework CI/CD rules** — every user project now gets CI guidance during setup: ci.yml template, Step 7.5, stack-aware test commands (Jest/pytest/Go/Bash), Existing Project Setup checklist CI item
- **CI & Community Contributions section** — 4 rules: CI badge rule, branch protection guidance, PR workflow, contribution validation
- **Spec-Based Test Generation** — forward flow only: SPECS origin detection, per-feature acceptance criteria format (### F{n} subsections), stub generation trigger, stack-aware stubs, stub completion gate
- **`check_stub_complete()`** — added to test-release-check.sh (kit copy + template); blocks release if test stubs have unfilled TODO markers
- **Community files** — PR template, bug report + feature request issue templates
- **Cross-platform sed fix** — test-spd-benchmarking.sh now runs on Ubuntu (GitHub Actions)
- **Section 41 gate hardening** — 5 new tests enforce ARD version badge, flow doc Kit refs, benchmarking fixture Kit refs, example Kit fields — gaps that previously required manual doc audits
- **Section 42** (29 tests) + **Section 43** (15 tests) — CI/CD and spec-gen validated on every prepare release
- **Flow documentation overhaul** — `docs/system-flows/` → `docs/work-flows/`; 3 flow docs overhauled to reflect current system; `development-release.md` added (full 8-step gate with Section 41 groups, stub gate, pre-push gate)
- **`check_stub_complete()` grep bug fixed** — `grep -cE ... || echo 0` → `grep -E ... | wc -l` (macOS: grep -c exits 1 on 0 matches, causing doubled output and integer comparison failure)

### Framework Changes
- **CI & Community Contributions** — CI badge rule, branch protection guidance, PR workflow rule, contribution validation rule
- **ci.yml template** — shipped in portable-spec-kit.md with `{TEST_COMMAND}` + `{SETUP_STEPS}` placeholders; stack-aware command detection table
- **New Project Setup Step 7.5** — create `.github/workflows/ci.yml` after stack confirmed; always includes `test-release-check.sh agent/SPECS.md`
- **Existing Project Setup checklist** — CI item added
- **Branch & PR Workflow** — CI must be green before merging any PR; branch protection guidance
- **Spec-Based Test Generation section** — 8 rules: origin detection, per-feature criteria format, stub generation trigger, no-criteria edge case, retroactive flow rule, stub generation steps, stack-aware formats, stub completion gate
- **SPECS.md template** — global `## Acceptance Criteria` → per-feature `## Feature Acceptance Criteria / ### F{n}` format
- **test-release-check.sh template** — `check_stub_complete()` + stub gate added (shipped to all new user projects)
- **New Project Setup Step 4** — updated to mention stub generation when criteria written

### Flow Documentation (v0.4.3)
- `docs/system-flows/` → `docs/work-flows/` — renamed, all references updated across 20+ files
- `spec-persistent-development.md` — per-feature criteria in Phase 1; stub lifecycle (RED/GREEN) + CI update step in Phase 3; prepare release 8-step gate in Phase 4; CI step in Pipeline Sync
- `new-project-setup.md` — Step 1 per-feature criteria + stubs; Step 6 CI workflow creation; renumbered
- `development-release.md` — new: full prepare release gate, 3 test suites breakdown, Section 41 groups, stub gate, pre-push gate, edge cases
- Section 41 flow doc count test fixed: grep pattern updated "system flow" → "work flow"

### Flow Documentation (v0.4.5)
- **2 new flow docs** — `11-existing-project-setup.md`: Step 0 state detection (Mapped/Partial/New), full scan flow, edge cases table, contrast with returning session; `12-cicd-setup.md`: stack detection, ci.yml generation, CI badge, branch protection, pre-push gate, PR contribution gate
- **All 12 flow docs aligned** — 63-char box-line standard enforced via Python `unicodedata.east_asian_width`; emoji-wide characters (✅, 🔍) accounted for correctly
- Section 19 expanded: "All 12 Flows + Diagram Integrity" — file existence + title/trigger + content tests for all 12 flows
- README flow table: rows 11 + 12 added; "10 step-by-step flows" → "12 step-by-step flows"
- ARD HTML: flow table rebuilt (12 rows, # column), all count references updated

### Flow Documentation (v0.4.4)
- All 10 flow docs updated with ASCII box diagrams
- `development-release.md` — developer workflow diagram added (DEVELOP → run tests → prepare release → commit → push → verify)
- `returning-session.md` — Step 0 kit status, 5-step read order, Kit update flow with stale sweep + codebase scan, profile/scan decoupling
- `first-session-workspace.md` — profile/scan decoupling, scan announcement
- `file-management.md` — Kit Update scan flow, decision diagram, edge cases
- `user-profile-setup.md` — 2 missing edge cases from framework
- All remaining flows: diagrams added, content audited and accurate

### Flow Documentation + Commands (v0.4.6)
- **Flow docs reordered** — logical user journey: onboarding (01-06), session management (07-10), development (11-12), release (13). 10 files renumbered.
- **New `05-project-init.md`** — `init`/`reinit` explicit command flows: deep scan, agent file create/sync, SPECS/PLANS staleness check, edge cases table, init vs reinit comparison table
- **Renamed** — `12-project-lifecycle.md` (was requirements-to-delivery), `13-release-workflow.md` (was development-release)
- **`init` / `reinit` commands** — added as explicit signals in framework with full 10-step and 8-step flows respectively
- **Test Execution Flow** — extracted as named section, referenced by all test-running commands (run tests, prepare/update/refresh release, push gate). Eliminates redundancy across flows.
- **Version bump BEFORE push rule** — added to Versioning Rules: bump → commit → push order enforced, anti-pattern documented
- **README commands table** — expanded to all 9 commands with accurate descriptions; release summary corrected (10 steps, Flows step added)
- Section 19 updated: all 13 flow file names corrected

### Release Flow Hardened (v0.4.9)
- **ARD audit rule** — uses `ard/*.html` glob; covers all current and future ARD files (no hardcoded filenames)
- **WeasyPrint loop** — `for f in ard/*.html; do weasyprint "$f" "${f%.html}.pdf"; done` — works for any number of files
- **Section 41 + 2 tests** (total 33): kit `agent/AGENT_CONTEXT.md` Version+Kit match; `CHANGELOG.md` built-over range includes current version — closes last two silent failure modes
- **Section 41 count corrected** — documented as 28, actual was 31 → now 33; flow doc and ARD updated
- **ARD Guide version fix** — `ard/Portable_Spec_Kit_Guide.html` was stale at v0.4.6; now at v0.4.9
- **TASKS.md §8.1** — F58/F59/F62 confirmed implemented, marked `[x]`; paper test count updated to 781
- **Section 49 — Kit Self-Validation** (8 tests): example symlink validity (both examples, all 5 agent config files), Progress Summary table required in TASKS.md, AGENT.md/SPECS.md/RELEASES.md template compliance, root/Projects copy sync check; +7 symlink tests in Sections 6, 7, 11
- **Section 50 — Kit Framework Self-Validation** (11 tests): no `/Users/` or `/home/` absolute paths, no hardcoded tool binary paths (`anaconda3/bin/weasyprint`, etc.), WeasyPrint loop form enforced, ARD audit uses `ard/*.html` glob, no hardcoded `both X.html AND Y.html` pair, release summary PDF glob, flow docs/ARD HTML/sync.sh all clean

### Release Command Fix (v0.4.8)
- **`prepare release` corrected** — steps 1–7 only, no commit, no push. Release summary GitHub/Tag rows show `⏳ pending — run: commit and push`
- **`prepare release and push`** — the explicit command that runs steps 1–7 + commit + push + shows summary with GitHub/Tag ✅
- **`13-release-workflow.md`** — renamed to "7-step gate"; publish steps removed from prepare release box; trigger table corrected; 5 new edge cases (prepare release stops, prepare release to review, prepare release and push, changes after release, commit before release)
- **README commands table** — `prepare release` row says "No commit. No push."; release summary block shows `⏳` vs `✅` states per command type
- **Framework `portable-spec-kit.md`** — Release Process signals, prepare/refresh sequences, release notes publishing section all corrected

### Team Intelligence Layer (v0.4.7)
- **F58 — Progress Dashboard** — trigger words (`progress`, `dashboard`, `burndown`, `status report`, `how are we doing`, `what's left`) → inline burndown from TASKS.md; OVERALL / BY VERSION / CURRENT TASKS / NEXT ACTIONS / BLOCKERS / BY CONTRIBUTOR sections; progress bars (█=5%, 20-char, ░ padding); version icons ✅/🔄/🔲; read-only; backlog excluded; edge cases: missing TASKS.md, all-done, truncation at 50+
- **F59 — Multi-Agent Task Tracking** — `@username` ownership syntax in TASKS.md; per-user task view (`my tasks`, `my workload`); delegation/unassign protocol; cross-agent coordination via shared TASKS.md (file is the message bus); shared task rule (`@a @b`); TASKS.md human-readable plain markdown
- **F60 — Persistent Memory Architecture** — named concept for the 6 agent files collectively; 5 properties: Durable (git), Shared (any agent), Portable (Claude/Cursor/Copilot/Cline/Windsurf), Team-scale, Auditable; tracking = writing to persistent memory; no API/no message queue
- **F61 — Architecture Decision Log** — `### Decision Log` promoted to top-level `## Architecture Decision Log` in PLANS.md template; ADR-NNN format (3-digit zero-padded) with Date/Options/Chosen/Why/Impact columns; newest-first; immutable history; supersede pattern; kit PLANS.md updated with 7 retroactive ADRs (ADR-001–007)
- **F62 — AI-Powered Onboarding** — commit `agent/` for team/open-source projects (never gitignore); clone → briefed flow; CONTRIBUTING.md guidance in template; solo exception; sensitive content check; `.gitignore` comment for solo projects; Existing Project Setup checklist updated
- **New flow doc `14-team-collaboration.md`** — Multi-Agent Task Tracking and Progress Dashboard flows; Edge Cases table (11 conditions); Persistent Memory Architecture properties table; 63-char alignment enforced
- **Sections 44–48** — 70 new framework tests across 5 new sections; Section 19 expanded for flow 14 (+6 tests); framework total 531 → 607

### Tests
| Suite | Tests | Status |
|-------|-------|--------|
| test-spec-kit.sh (50 sections) | 636 | ✅ All passing |
| test-spd-benchmarking.sh | 145 | ✅ All passing |
| test-release-check.sh | 62/62 features | ✅ Release ready |

---

## v0.3 — Framework Hardening + R→F→T Traceability (April 2026)
**Built over:** v0.3.1 — v0.3.27 · **Tests:** 597 (452 framework + 145 benchmarking)

### Highlights
- Full **R→F→T traceability chain** — every done feature requires a test reference in SPECS.md before release
- **`tests/test-release-check.sh`** — R→F→T validator distributed as a kit template, created on every project setup
- **15 new enforcement sections** (26–41) — staleness checks, release triggers, scope change recording, no-slip task rule, pre-release gate
- **Release Process rule** — full 8-step sequence: tests → counts → version bump → PDFs → RELEASES.md → CHANGELOG.md → GitHub release → tag update
- **`update release` / `refresh release`** — `update release` is alias for `prepare release`; `refresh release` re-tests + syncs current release without bumping version
- **Section 41: Pre-Release Consistency Gate** — 23 tests checking cross-file sync before every push
- **Agent-agnostic examples** — `portable-spec-kit.md` + symlinks for all 5 agents in `examples/`
- **Simplified versioning** — aligned patches (`v0.N.x` for release `v0.N`), single `**Version:**` field, `**Kit:**` field in AGENT_CONTEXT

### Framework Changes
- **R→F→T traceability** — mandatory Tests column in SPECS.md; never mark a feature `[x]` without a test reference
- **SPECS.md staleness check** — non-empty SPECS.md can still be stale; agent checks count vs TASKS.md completed tasks
- **RELEASES.md trigger rule** — entry added immediately when all version tasks are `[x]` done
- **4 scope change types** (DROP/ADD/MODIFY/REPLACE) with R→F traceability format — tracked across all 4 pipeline files
- **No-slip task rule** — scan every message for implied tasks; session-end verification sweep
- **Session-start unified 5-step read order** — user profile → AGENT.md → AGENT_CONTEXT.md → TASKS.md → PLANS.md
- **Release Notes Publishing** — CHANGELOG.md always updated; GitHub Releases auto-published if `gh` authenticated; prompt to connect or skip if not
- **test-release-check.sh caching** — each test file runs once; result cached to prevent false failures
- **Rename/refactor completeness rule** — grep entire repo before marking a rename done; no stragglers
- **What Goes Where rule** — universal user rules in `portable-spec-kit.md`; author-only rules in `agent/AGENT.md`
- **Versioning examples** — all specific patch numbers replaced with generic `v0.N.x` / `v0.1.4 → v0.1.5` so rules never go stale
- **prepare release 8-step sequence** — tests → counts → version bump → PDFs → RELEASES.md → CHANGELOG.md → GitHub release → tag update to HEAD
- **`update release`** — alias for `prepare release` (same full 8-step sequence including version bump)
- **`refresh release`** — re-test and sync current release without bumping version; same 8-step sequence with step 3 skipped
- **Release notes scope rule** — only include changes committed and visible in public repo; never mention excluded files (private docs/, research papers)
- **GitHub release title format** — minor version (`v0.N — Title`) matching CHANGELOG headings; patch number visible via commit history
- **sync.sh fixes** — CHANGELOG-based title/notes extraction (RELEASE_VER lookup); `--draft=false --latest` flags; commit message from last commit subject; release tags re-pointed to semantically correct commits
- **Kit update summary template** — generic format: lists changes from CHANGELOG.md + each file changed; no hardcoded field names or file names that go stale
- **Author/kit header** — version, license, author, GitHub link, test count at top of all framework copies; visible to humans and AI agents
- **Existing project setup — scan announcement** — agent tells user *"Spec Kit is understanding your project..."* before scanning; Step 0 checks if project already scanned (skip / partial / full); 7 scan edge cases handled (no stack detected, monorepo, conflicting signals, .env values, large project, team-committed agent/ files)
- **GitHub repo as knowledge source** — agent fetches from repo on demand for any kit question; known source table maps question types to files; open-ended repo scan catches new docs added in the future
- **Session-start kit status display** — Step 0 shows status once when agent first loads: ✅ mapped / ⚠ partial / 🔍 new. Also runs after kit version update so user sees updated version in status.
- **Profile setup and project scan decoupled** — kit always proceeds to scan and setup even if user skips profile questions
- **Kit update re-scan clarified** — step 5 explicitly scans the user's project (source code, config files) to update AGENT.md + AGENT_CONTEXT.md; not a kit changelog summary. 5 edge cases: empty project, large project, accurate AGENT.md, document project, no project dir confirmed.

### README / Docs
- Critical Scenarios table — 8 real-world situations (new machine, agent switch, crash/wipe, team handoff, context window…)
- Development Guidelines section — pipeline, file update triggers, core commands, key principles, file management rule
- "First methodology native to the AI era" framing
- Terminal install commands single-line (horizontally scrollable)
- 6 Agent Files table — update triggers corrected per file
- Flow docs + test fixtures updated: `**Framework:**` → `**Kit:**` references throughout

### Tests
| Suite | Count | Notes |
|-------|------:|-------|
| Framework (`test-spec-kit.sh`) | 452 | 41 sections |
| Benchmarking (`test-spd-benchmarking.sh`) | 145 | 5 projects × 8 lifecycle phases |
| Release gate (`test-release-check.sh`) | 55/55 features | R→F→T coverage validator |
| **Total** | **597** | All passing |

---

## v0.2 — SPD Methodology + Research (April 2026)
**Built over:** v0.2.1 — v0.2.9 (9 patches leading to this release) · **Tests:** 443 (298 framework + 145 benchmarking)

### Highlights
- **Benchmarking suite** — 145 tests across 5 projects × 8 development lifecycle phases
- **Requirements-to-delivery flow** — 9-phase lifecycle with R→F traceability and 4 scope change types
- **Two-level versioning** — framework v0.0.x patches + release v0.x milestones
- **Existing project setup** — guide don't force, checklist, 9 project scenarios

### Framework Changes
- R→F traceability — Requirements (R1, R2…) trace to Features (F1, F2…) through all scope changes
- 4 scope change types: DROP, ADD, MODIFY, REPLACE — tracked across all 4 pipeline files
- Conda env selection flow — per-project, 9 edge cases handled
- Git rule — check `.git/` before committing
- Pipeline sync rule — SPECS, PLANS, TASKS, RELEASES stay in sync

---

## v0.1 — Personalized Profile + Flow Documentation (April 2026)
**Built over:** v0.1.1 — v0.1.9 (9 patches leading to this release) · **Tests:** 242 (22 sections)

### Highlights
- **User Profile system** — global (`~/.portable-spec-kit/`) + workspace (committed, per-user)
- **First-session setup** — GitHub auto-detect + 3 preference questions with RECOMMENDED/CURRENT labels
- **9 system flow documents** — user-profile-setup, new-project-setup, returning-session, agent-switching, and more
- **Fully agent-agnostic** — no hardcoded Claude paths or tool names
- **Technical Overview ARD** — HTML + PDF architecture reference
- **Repo made public** — April 1, 2026

---

## v0.0 — Initial Release (March 2026)
**Built over:** v0.0.1 — v0.0.9 (9 patches leading to this release) · **Tests:** 122 (13 sections)

### Highlights
- `portable-spec-kit.md` — single framework file, zero dependencies, zero install
- 6 agent file templates (AGENT.md, AGENT_CONTEXT.md, SPECS.md, PLANS.md, TASKS.md, RELEASES.md)
- README, CONTRIBUTING.md, PDF Quick Guide
- `examples/starter/` and `examples/my-app/`
- Sync script + symlink setup for 5 AI agents
