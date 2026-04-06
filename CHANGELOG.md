# Changelog

All notable changes to the Portable Spec Kit are documented here.

> **Versioning:** Each release (v0.N) is built from a series of incremental patches (v0.N.x).
> Completed releases show minor only (v0.3, v0.2, v0.1, v0.0). Active release shows full patch version.

---

## v0.3 — Framework Hardening + R→F→T Traceability (April 2026)
**Built over:** v0.3.1 — v0.3.21 (21 patches) · **Tests:** 594 (449 framework + 145 benchmarking)

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
| Framework (`test-spec-kit.sh`) | 449 | 41 sections |
| Benchmarking (`test-spd-benchmarking.sh`) | 145 | 5 projects × 8 lifecycle phases |
| Release gate (`test-release-check.sh`) | 55/55 features | R→F→T coverage validator |
| **Total** | **594** | All passing |

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
