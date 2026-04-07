# Changelog

All notable changes to the Portable Spec Kit are documented here.

> **Versioning:** Each release (v0.N) is built from a series of incremental patches (v0.N.x).
> Completed releases show minor only (v0.3, v0.2, v0.1, v0.0). Active release shows full patch version.

---

## v0.4 — CI/CD Pipeline + Spec-Based Test Generation (April 2026)
**Built over:** v0.4.1 — v0.4.5 · **Tests:** 673 (528 framework across 43 sections + 145 benchmarking)

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

### Tests
| Suite | Tests | Status |
|-------|-------|--------|
| test-spec-kit.sh (43 sections) | 528 | ✅ All passing |
| test-spd-benchmarking.sh | 145 | ✅ All passing |
| test-release-check.sh | 57/57 features | ✅ Release ready |

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
