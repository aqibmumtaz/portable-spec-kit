# Changelog

All notable changes to the Portable Spec Kit are documented here.

> **Versioning:** Each release (v0.N) is built from a series of incremental patches (v0.N.x).
> `v0.3.15` = release v0.3, patch 15 — current active release shows full patch version; completed releases show minor only.

---

## v0.3.15 — Version Alignment Completeness Sweep (April 2026)
**Built over:** v0.3.1 — v0.3.15 (15 patches) · **Tests:** 589 (444 framework + 145 benchmarking)

### Changes
- **Versioning:** Fixed all remaining stale v0.4 references — SPECS.md release headings corrected to v0.0/v0.1/v0.2/v0.3 (was v0.1/v0.2/v0.3/v0.3 with a duplicate)
- **ARD HTML:** Added missing v0.3 changelog section; fixed v0.2 Kit range (`v0.1.1+` → `v0.2.1 — v0.2.9`)
- **Tests:** Updated test fixtures from stale `**Framework:** vX` → `**Kit:** vX` (test-spec-kit.sh + test-spd-benchmarking.sh); updated D2 grep pattern to match Kit field
- **Docs:** Fixed `Framework: v0.3.1` → `Kit: v0.3.1` in requirements-to-delivery.md; `Framework: v0.2.4` → `Kit: v0.2.4` in agentic-communication-discovery.md
- **sync.sh:** Updated 3 comment examples from v0.4.x → v0.3.x

### Tests
- **Framework:** 444 passing (41 sections)
- **Benchmarking:** 145 passing
- **Total:** 589 passing

### GitHub Tags Fixed
- **v0.3** → `d7d7885` (April 5 — v0.3.15 latest commit ✓)
- **v0.2** → `a3a2d56` (April 2 — v0.2.9 last commit ✓)
- **v0.1** → `6a95aa9` (April 1 — v0.1 era last commit ✓)
- **v0.0** → `79a15f3` (March 30 — initial release last commit ✓)
- Stale `v0.4` tag removed
- Tags page and Releases page now show v0.3 first, v0.0 last

---

## v0.3.14 — Framework Hardening + R→F→T Traceability (April 2026)
**Built over:** v0.3.1 — v0.3.14 (14 patches) · **Tests:** 589 (444 framework + 145 benchmarking)

### Highlights
- Full **R→F→T traceability chain** — every done feature requires a test reference in SPECS.md before release
- **`tests/test-release-check.sh`** — R→F→T validator distributed as a kit template, created on project setup
- **15 new enforcement sections** — staleness checks, release triggers, scope change recording, no-slip task rule
- **Release Process rule** — explicit signals only (`run tests` / `prepare release` / `commit` / `push`)
- **Section 41: Pre-Release Consistency Gate** — 23 tests checking cross-file sync before every push
- **Agent-agnostic examples** — `portable-spec-kit.md` + symlinks for all 5 agents in `examples/`
- **Simplified versioning** — aligned patches (`v0.N.x` for release `v0.N`), single `**Version:**` field, `**Kit:**` field for installed kit version

### Framework Changes
- `SPECS.md` staleness check — non-empty SPECS.md can still be stale; agent checks count vs TASKS.md
- `RELEASES.md` trigger rule — entry added immediately when all version tasks are done
- 4 scope change types (DROP/ADD/MODIFY/REPLACE) with R→F traceability format
- No-slip task rule — scan every message for implied tasks, session-end verification sweep
- Session-start unified 5-step read order
- Release Process rule — agent never auto-runs tests, auto-bumps versions, or auto-commits
- **Release Notes Publishing** — CHANGELOG.md always updated; GitHub Releases optional (asks user per release: `gh release create/edit` if authenticated)
- **Versioning simplified** — dropped offset convention; `v0.N.x` patches align with release `v0.N`. Removed redundant `**Framework:**` field; renamed to `**Kit:**` in AGENT_CONTEXT templates. GitHub tag = minor (`v0.N`), title = full patch version
- **test-release-check.sh caching** — each test file runs once; result cached per file to prevent false failures when multiple features share a test

### README / Docs
- Critical Scenarios table — 8 real-world situations (new machine, agent switch, crash/wipe, team handoff…)
- Development Guidelines section — pipeline, file update triggers, core commands, key principles
- "First methodology native to the AI era" framing
- Terminal install commands now single-line (horizontally scrollable), consistent with AI agent section
- Flow docs updated: `**Framework:**` → `**Kit:**` references in file-management.md + returning-session.md
- Example AGENT_CONTEXT files updated: `**Kit:** v0.3.14` field added, version uses 3-part semver

### Tests
| Suite | Count | Notes |
|-------|------:|-------|
| Framework (`test-spec-kit.sh`) | 444 | 41 sections |
| Benchmarking (`test-spd-benchmarking.sh`) | 145 | 5 projects × 8 lifecycle phases |
| Release gate (`test-release-check.sh`) | 53/53 features | R→F→T coverage validator |
| **Total** | **589** | All passing |

---

## v0.2 — SPD Methodology + Research (April 2026)
**Built over:** v0.2.1 — v0.2.9 (9 patches leading to this release) · **Tests:** 443 (298 framework + 145 benchmarking)

### Highlights
- **SPD concept paper** — 9 sections, 27+ references, 5 SVG diagrams, 31-page A4 PDF
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
