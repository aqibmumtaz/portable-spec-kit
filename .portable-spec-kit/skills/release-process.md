<!-- Section Version: v0.5.7 -->
# Skill: Release Process

> **Loaded when:** User says `prepare release`, `refresh release`, `push`, or any release command.

### Release Process (EXPLICIT SIGNALS ONLY)
Never automatically run tests, update counts, bump versions, regenerate PDFs, or commit after every change. The user may have more changes coming. Wait for explicit signals:
- **"run tests"** → run Test Execution Flow. No commits, no version changes.
- **"prepare release"** / **"update release"** → steps 1–9 only (tests → code review → scope check → flows → counts → version bump → PDFs → RELEASES.md → CHANGELOG.md) + show release summary. **No commit. No push.** Changes sit staged for user review.
- **"refresh release"** → same as prepare release but no version bump. **No commit. No push.**
- **"commit"** → commit staged changes
- **"push"** → push to remote (pre-push gate applies)
- **"prepare release and push"** / **"prepare release, commit and push"** → steps 1–9 + commit all release changes + push via `bash agent/scripts/sync.sh` + show release summary. No confirmation needed between steps — user has given the full instruction.
- **"refresh release and push"** / **"refresh release, commit and push"** → same as above but no version bump.
- **"init"** → scan project thoroughly, create/fill all agent/ files from codebase
- **"reinit"** → re-scan project, sync all agent files to current codebase state

**"prepare release" / "update release" sequence (steps 1–9, no commit/push):**
1. Run **Test Execution Flow** — do not proceed to step 2 until all suites pass. User declines to fix → stop release.
2. **Run code review** — check `.portable-spec-kit/config.md` → `Code Review.In release pipeline`. If enabled → run `bash agent/scripts/psk-code-review.sh`. Issues found → show report, ask user to fix or skip. Advisory — does not block release, but flagged in summary. If disabled → skip, show "Code review: disabled in config" in summary.
3. **Run scope drift check** — check `.portable-spec-kit/config.md` → `Scope Drift.In release pipeline`. If enabled → run `bash agent/scripts/psk-scope-check.sh`. Drift score > 0 → show report, recommend review. Advisory — does not block release, but flagged in summary. If disabled → skip, show "Scope check: disabled in config" in summary.
4. **Full doc-surface sync** — MANDATORY run of `bash agent/scripts/psk-doc-sync.sh`. The analyzer extracts every feature from the current-minor CHANGELOG and checks coverage across ALL five documentation surfaces: `agent/*.md`, `docs/work-flows/*.md`, `docs/research/*.md`, `ard/*.html`, `README.md`. Output classifies each feature as COVERED (≥2 surfaces) / PARTIAL (1 surface) / MISSING (0 surfaces) with suggested target docs.
   - **For every MISSING feature** → either (a) add content to the suggested existing doc, OR (b) create a new flow doc if the feature is a distinct user-facing workflow (next sequential number, e.g. `17-new-feature.md`)
   - **For every PARTIAL feature** that represents a user-facing workflow → expand to at least 2 surfaces. PARTIAL is acceptable only for internal/infrastructure items.
   - **Always update** stale existing content (old step numbers, renamed scripts, removed features)
   - **Order check** — verify the numeric prefix order (`01-`, `02-`, ...) reflects the logical sequence a user would follow. If adding a new flow breaks logical order, renumber affected files and `grep -r` entire repo for every old filename and update every reference (README flow table, Section 19 tests, ARD HTML flow table, CHANGELOG, RELEASES, cross-links) in the same session. No stragglers.
   - Box-style format required for all flow docs. No tree-style connectors. All box lines 63 chars wide.
   - If new flow doc created → update README flow table (PSK015 blocks otherwise).
   - **Re-run analyzer** until Missing=0. Sub-agent critic at Step 9 re-runs it and blocks release if any MISSING remain.
   - **End-user perspective check**: after filling gaps, ask would a new user get everything working from the docs alone? Scan for stale references, missing files/dirs, broken cross-links, permissions. Fix anything found. No author-specific rules in generic framework.
5. **Consistency sweep — update ALL counts and references across ALL files.** This is the most error-prone step. Check every file type against a single source of truth:
   - **Counts to verify (must all agree):** test count, flow doc count, section count, feature count, version number
   - **Files to check (EXHAUSTIVE — check every one, in order):**
     1. `README.md` — version badge, test badge, "What's New" section, flow table, orchestration table
     2. `portable-spec-kit.md` — Framework Version comment, Version header, Tests line
     3. `CHANGELOG.md` — current minor version entry (≥3 items), Built over range
     4. `agent/AGENT_CONTEXT.md` — Version, Kit version, Phase description (next work), What's Done
     5. `agent/AGENT.md` — Stack table (matches package.json/requirements.txt versions), Tests line
     6. `agent/SPECS.md` — Overall line (test count), Features section, F→T column populated for [x] features
     7. `agent/TASKS.md` — Progress Summary table (no "TBD"), version heading matches AGENT_CONTEXT
     8. `agent/PLANS.md` — Plans Directory, Architecture Decision Log with Plan Ref column
     9. `agent/DESIGN.md` (if present) — feature overview matches SPECS.md
     10. `agent/RESEARCH.md` (if present) — index matches active research
     11. `agent/REQS.md` (if present) — requirement status reflects feature completion
     12. `agent/RELEASES.md` — current version entry (≥3 items), Kit range, Tests block
     13. ALL `ard/*.html` files — version badge, footer, Key Highlights, Version Changelog section (current version described with content, not just range bump)
     14. `examples/*/agent/AGENT_CONTEXT.md` + `examples/*/agent/RELEASES.md` — Kit version propagation
     15. `tests/test-spd-benchmarking.sh` — fixture Kit version references
     16. `docs/work-flows/*.md` — any doc that mentions counts, versions, or process descriptions that changed this release
     
     **Safety net grep:** `grep -rn "v0.N-1" $(git ls-files)` — scan entire tracked repo for old version string. Every hit must be either intentional historical reference or updated. No silent stragglers.
   - **README "Latest Release" section (MANDATORY for minor releases):** When bumping minor version (v0.N-1 → v0.N), update the README "## Latest Release" section (near the top, after Quick Start, before The Methodology). Format:
     1. Start with `**v0.N**` and a one-line title summarizing the release theme
     2. 1–2 sentence highlight paragraph naming the biggest user-visible changes
     3. End with links: `**→ Full release notes:** [CHANGELOG.md](CHANGELOG.md) · [GitHub Releases](…releases)`
     **REPLACE, don't accumulate.** When v0.N+1 ships, the v0.N "Latest Release" is replaced entirely — not appended. README stays roughly constant length across releases. Full history lives in `CHANGELOG.md` (the dedicated release details page) and on GitHub Releases. This prevents the README from growing unboundedly and pushing install instructions below the fold.
     **Full per-patch notes go in CHANGELOG.md** (grouped under the minor version heading) AND `agent/RELEASES.md` (detailed internal notes). README never contains per-patch details — just the minor-version summary + links.
   - **ARD audit (MANDATORY):** Update ALL HTML files in `ard/*.html`. For every file: version badge, footer version, version field. For Technical Overview: Key Highlights version + flow count + test count, Version Changelog section (bump Kit range, update counts). **Check historical entries are not contaminated** by version bump (e.g., v0.4 range should stay v0.4.x, not change to current version). Never update one file and skip others.
   - **ARD CONTENT update (MANDATORY) — not just counts:** ARDs must describe features added this release, not just version numbers. For every new feature, script, skill file, architecture change, or process change made in this release cycle → add content to the appropriate ARD section. Technical Overview gets technical details (new scripts, their purposes, protocols). Guide gets user-facing changes (new commands, workflows, install options). If a feature exists in `agent/SPECS.md` or `CHANGELOG.md` for the current version but is NOT described in any `ard/*.html` → add it. Version-bump-without-content-update is a bug.
   - **Design plan completeness (MANDATORY):** Every feature (Fn) marked `[x]` in SPECS.md that has a design file in `agent/design/` → verify (a) it's listed in PLANS.md Plans Directory table AND (b) has a corresponding ADL entry in PLANS.md Architecture Decision Log with `Plan Ref` column populated linking back to the design file. Missing ADL entry with Plan Ref = incomplete — ADL must be the index that lets future devs find the rationale without opening design files.
   - **Test assertion sync:** If test files contain hardcoded counts (flow count, section count), verify they match current values. Stale assertions = false failures on next run.
   - **Guidance freshness check:** Verify no hardcoded counts, version numbers, or feature-specific examples appear in the Kit Self-Help section or guidance tables. All guidance must be dynamic (derived at runtime from framework/config/project state). If a hardcoded value is found → replace with a dynamic instruction (e.g., "read from SPECS.md" not "66 features").
6. Bump version — increment patch in `agent/AGENT_CONTEXT.md` (e.g. v0.1.4 → v0.1.5) + README badge. **Also update phase description (MANDATORY)** in AGENT_CONTEXT.md — the phase line must describe NEXT planned work (from TASKS.md Backlog or Current headings), NOT work already completed in this release. Version-bumped-but-phase-unchanged is a bug. Agent reads this on every session start and will work on wrong features if stale.
7. Regenerate PDFs — **mandatory on every prepare release** (ARD HTML always changes when version bumps). Run WeasyPrint for every `ard/*.html` file:
   ```bash
   for f in ard/*.html; do
     weasyprint "$f" "${f%.html}.pdf"
   done
   ```
   Verify each PDF was written (non-zero file size). GLib warnings in output are harmless — ignore them.
8. Update `agent/RELEASES.md` — add or update entry for this version: title, Kit range, all changes grouped by category, test counts
9. Update `CHANGELOG.md` — single grouped entry per minor release (v0.N), covering all patches in the release cycle. Format: `## v0.N — Title (Month Year)` · `**Built over:** v0.N.1 — v0.N.x` · Highlights + Framework Changes + README/Docs + Tests table. Completed releases show minor only; never separate entries per patch
10. **Show the release summary block** (see format below) — GitHub and Tag rows show `⏳ pending push`

**"prepare release and push" / "prepare release, commit and push" sequence (steps 1–9 + commit + push):**
- Run steps 1–9 above in full
- Then: stage and commit all release changes with descriptive message
- Then: run `bash agent/scripts/sync.sh "commit message"` — handles: copying portable-spec-kit.md (root → project → examples), syncing all files to public repo, creating/updating GitHub Release from CHANGELOG.md, updating the v0.N tag. If `gh` not authenticated → run `gh auth login` first.
- Then: verify version on `aqibmumtaz/portable-spec-kit` matches current version
- Then: **Show the release summary block** — GitHub and Tag rows show `✅`

**"refresh release" sequence (same version, no bump, no commit/push):**
1. Run **Test Execution Flow** — do not proceed to step 2 until all suites pass. User declines to fix → stop.
2. **Run code review** — check config → `Code Review.In release pipeline`. If enabled → run `bash agent/scripts/psk-code-review.sh`. If disabled → skip.
3. **Run scope drift check** — check config → `Scope Drift.In release pipeline`. If enabled → run `bash agent/scripts/psk-scope-check.sh`. If disabled → skip.
4. **Full doc-surface sync** — MANDATORY run of `bash agent/scripts/psk-doc-sync.sh`. Analyzer checks every CHANGELOG feature against 5 doc surfaces (agent/*, flow-docs, paper, ARD, README). For every MISSING → add to suggested doc or create new flow doc. For every PARTIAL user-facing workflow → expand. Re-run until Missing=0. Box-style format, 63-char lines. Update README flow table if new doc created.
5. **Consistency sweep** — same as prepare release Step 5. Verify all counts agree across README, ARD, SPECS, TASKS, PLANS, CHANGELOG, RELEASES, AGENT_CONTEXT. Check design plan completeness, test assertion sync, README "What's New" section. ARD audit mandatory.
6. **No version bump** — version stays the same
7. Regenerate PDFs — mandatory. Run WeasyPrint for every `ard/*.html` file:
   ```bash
   for f in ard/*.html; do
     weasyprint "$f" "${f%.html}.pdf"
   done
   ```
   Verify each PDF was written (non-zero file size). GLib warnings in output are harmless — ignore them.
8. Update `agent/RELEASES.md` — update the current version entry with any new changes and corrected counts
9. Update `CHANGELOG.md` — update the current version entry (same patch range, updated content)
10. **Show the release summary block** (see format below) — GitHub and Tag rows show `⏳ pending push`

**"refresh release and push" / "refresh release, commit and push" sequence:**
- Run steps 1–9 above in full
- Then: stage and commit all release changes
- Then: run `bash agent/scripts/sync.sh "commit message"` to push. If `gh` not authenticated → run `gh auth login` first.
- Then: verify version on `aqibmumtaz/portable-spec-kit` matches current version
- Then: **Show the release summary block** — GitHub and Tag rows show `✅`

**Release summary (shown at end of every prepare/refresh release command):**
```
══════════════════════════════════════════════
  RELEASE SUMMARY — v0.N.x
══════════════════════════════════════════════
  1. Tests        <Suite>: X passed ✅  <Suite>: X passed ✅
                  Total: X/X passing ✅
  2. Code Review  X passed, Y issues (advisory) ✅/⚠  (or: disabled in config)
  3. Scope Check  drift score: N ✅/⚠              (or: disabled in config)
  4. Flows        docs/work-flows/ current ✅
  5. Counts       README, ARD, RELEASES, CHANGELOG, TASKS ✅
  6. Version      v0.N.x-1 → v0.N.x ✅           (prepare/update only)
                  unchanged — v0.N.x —             (refresh only)
  7. PDFs         all ard/*.pdf regenerated ✅                
  8. RELEASES.md  updated ✅
  9. CHANGELOG.md updated ✅
  10. GitHub      ⏳ pending — run: commit and push   (prepare release)
                  published ✅                        (prepare release and push)
  11. Tag         ⏳ pending — run: commit and push   (prepare release)
                  updated ✅                          (prepare release and push)
══════════════════════════════════════════════
```
Do not finalize the release (version bump) if any suite has failures.

**Release notes publishing (only when committing and pushing):**

Applies only when running `prepare release and push` / `prepare release, commit and push` (or `refresh release and push`). CHANGELOG.md is always updated as part of step 9 above — it is the universal fallback. GitHub Releases are the additional layer published during the push step.

During the push step, check `gh auth status` and proceed:
- **If `gh` authenticated** → automatically: commit all release changes + run `bash agent/scripts/sync.sh` to push + create/update GitHub release with CHANGELOG.md notes for this version (`--latest`). No prompt needed.
- **If `gh` not authenticated** → ask user:
  ```
  gh CLI not authenticated. GitHub Releases require auth.
  (a) Connect now — run `gh auth login` then continue
  (b) Commit and push only — skip GitHub release this time
  ```
  - User picks (a) → run `gh auth login`, re-check auth, then proceed with full publish
  - User picks (b) → commit + push via git, skip GitHub release creation
- CHANGELOG.md is always updated in step 7 regardless of auth state — never skip it

**Edge cases:**
- **No test suites exist** → show `No test suites configured — skipping test run` in summary block and proceed. Tests are required before v1.0.
- **New suite added this session** → include it in the summary automatically
- **Test failures exist** → run all suites to completion first, then show failure summary (suite, test name, error) + fix plan (one-line diagnosis + proposed fix per failure). Ask user to approve. Fix → re-run → only proceed when all pass. Never skip failures.
- **release-check.sh shows untested features** → **do not finalize the release**. Add test references to the SPECS.md Tests column, ensure those tests pass, then re-run prepare release. A feature is not done until it has a test ref.
- **New flow needed** → create in `docs/work-flows/` during step 2. Choose its number based on logical position in the user journey — not just "next highest". If inserting mid-sequence, renumber subsequent files and update all references repo-wide before proceeding.
- **PDFs** → always regenerate all `ard/*.html` files to PDF on every prepare release using WeasyPrint (`weasyprint`). Use the loop form: `for f in ard/*.html; do weasyprint "$f" "${f%.html}.pdf"; done`. Verify non-zero output file sizes. GLib warnings are harmless.
- **GitHub release already exists for this version** → update it (not create new) — use `gh release edit`
- **CHANGELOG.md missing entry for this version** → add it before publishing
- **Release notes scope** — only include changes that are committed and visible in the repo. Never mention files, features, or work that is excluded from the public repo (e.g. private docs/, research papers, local-only scripts)
- **No git tags in use** → skip the tag update step; note it

Batch all changes first, then trigger the release process once when the user is ready.

**"init" — Project initialization:**
Explicit trigger for full project scan and agent file setup. Handles any kit status (New, Partial, or already Mapped).

1. Confirm project directory — list visible dirs, ask: "Which directory is your project? (Enter = current)"
2. Show current kit status (✅ Mapped / ⚠ Partial / 🔍 New)
3. If already Mapped → show: "Project already initialized (vX.X.X). Running full re-scan to refresh agent files." then continue.
4. Announce: "Scanning project — stack, source files, config, dependencies..."
5. **Deep scan** — read all config files (`package.json`, `requirements.txt`, `pyproject.toml`, `Dockerfile`, `docker-compose.yml`, `tsconfig.json`, `go.mod`, `Cargo.toml`, `build.gradle`, `*.xcodeproj`, `pubspec.yaml`, `README.md`) + all top-level dirs + sample `src/` files. Build a complete picture before touching anything.
6. Create `agent/` dir + all 9 agent files if missing — fill every field from scan. Never leave TBD if the answer is visible in the code.
7. Create `README.md`, `.gitignore`, `.env.example` if missing.
8. Present scan summary + optional changes checklist:
   ```
   Scan complete. Detected: <stack> · Port <X>

   [x] agent/ — 6 files created/updated (pre-filled from scan)
   [ ] CI/CD — disabled by default (say `enable ci` when ready)
   [ ] .env.example              — env var template
   [ ] README.md                 — restructure to kit template

   Which optional changes? (all / none / list numbers)
   ```
9. Apply selected changes.
10. Show init summary:
    ```
    ✅ Init complete — <project-name>
    Stack:  <detected>
    Files:  X created · Y updated
    Status: ✅ Mapped
    ```

**"reinit" — Re-scan and sync agent files:**
Re-scans the entire project and brings all agent files in sync with the current codebase. Use when significant code changes have been made since the last scan and agent files are stale.

1. Announce: "Re-scanning — syncing agent files to current codebase..."
2. Read current `agent/AGENT.md` + `agent/AGENT_CONTEXT.md` as baseline.
3. **Deep scan** — same scope as `init` step 5. Read source files, config files, directory structure.
4. **Update `agent/AGENT.md`** — update only fields that changed (stack versions, new tools, port, conda env). Note what changed.
5. **Rebuild `agent/AGENT_CONTEXT.md`** — rewrite from current codebase state:
   - Phase — inferred from TASKS.md progress + codebase completeness
   - What's done — `[x]` tasks + visible completed code
   - What's next — `[ ]` tasks
   - Blockers — TODO/FIXME markers in source, missing deps, failing tests
   - File structure — current directory tree
6. **SPECS.md staleness check** — count `[x]` tasks in TASKS.md vs features in SPECS.md. If completed tasks are not represented in SPECS → list them: "3 completed tasks not in SPECS.md — add as features? (y/n)"
7. **PLANS.md vs code** — if architecture visible in the code differs from PLANS.md → flag it: "PLANS.md may be stale — <field> shows <X> in code but <Y> in PLANS. Update? (y/n)"
8. Show reinit summary:
   ```
   ✅ Reinit complete — <project-name>
   AGENT.md:      <fields updated, or "no changes">
   AGENT_CONTEXT: rebuilt — phase: <X> · <Y> tasks pending
   SPECS.md:      <N stale features> / current ✅
   PLANS.md:      <stale fields flagged> / current ✅
   ```

