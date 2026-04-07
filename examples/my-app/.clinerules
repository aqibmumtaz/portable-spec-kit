# Portable Spec Kit — Spec-Persistent Development for AI-Assisted Engineering
<!-- Framework Version: v0.4.5 -->

**Version:** v0.4.5 · **License:** MIT · **Author:** Dr. Aqib Mumtaz
**GitHub:** https://github.com/aqibmumtaz/portable-spec-kit · **Tests:** 673 (528 framework + 145 benchmarking)

> A lightweight, zero-install, personalized framework for AI-assisted engineering. Drop one file into any project — your AI agent personalizes to you, maintains living specifications, and preserves context across sessions. Specs always exist. Always current. Never block.
>
> **For full documentation, setup instructions, and examples — see [README.md](README.md).**

---

> **Purpose:** The single source of truth for how the user works — dev practices, coding standards, testing rules, project setup procedures, and AI interaction guidelines. Read this FIRST on every session.
>
> **Role:** Portable across all projects. Drop this file into any repo and the AI agent follows these standards immediately. Project-specific rules go in `agent/AGENT.md`. Workspace state goes in `WORKSPACE_CONTEXT.md` (auto-created on first session).

---

## How This File Works

This file is the **Portable Spec Kit** framework. It is distributed as `portable-spec-kit.md` and installed into projects as agent-specific filenames via symlinks (Mac/Linux) or copies (Windows):

| Agent | Installed As |
|-------|-------------|
| Claude Code | `CLAUDE.md` |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Cursor | `.cursorrules` |
| Windsurf | `.windsurfrules` |
| Cline | `.clinerules` |

**All point to the same source file** — `portable-spec-kit.md`. Edit one, all agents read the update.

**NEVER edit symlink files directly** (`CLAUDE.md`, `.cursorrules`, `.windsurfrules`, `.clinerules`, `.github/copilot-instructions.md`). Always edit `portable-spec-kit.md` — the symlinks are read-only pointers. Editing a symlink file edits the source underneath it, but doing so by name causes confusion about which file is authoritative. All framework changes go to `portable-spec-kit.md` only.

On first session, the agent also auto-creates:
- `WORKSPACE_CONTEXT.md` — workspace environment and project listing
- `agent/` directory in each project — with 6 management files (AGENT.md, AGENT_CONTEXT.md, SPECS.md, PLANS.md, TASKS.md, RELEASES.md)
- `README.md` — structured project overview

**If the user asks any question about the kit — installation, features, setup, examples, changelog, methodology, or how anything works:**
Use the GitHub repo as the knowledge source — fetch the relevant file on demand and answer from it. Do not guess or paraphrase from memory.

**Repo:** https://github.com/aqibmumtaz/portable-spec-kit
**Raw base URL:** `https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/`

Known sources (fetch the most relevant one for the question):
| Question type | Source to fetch |
|---------------|----------------|
| Install / reinstall / update | `README.md` |
| Features / what the kit does | `README.md` |
| How a rule works | `portable-spec-kit.md` |
| Version history / what changed | `CHANGELOG.md` |
| Examples / starter project | `examples/starter/` or `examples/my-app/` |
| Flow documentation | `docs/work-flows/` |
| Architecture / technical overview | `ard/Portable_Spec_Kit_Technical_Overview.html` |

**If the question doesn't match a known source, or if new docs may have been added:** scan the repo structure first (`https://github.com/aqibmumtaz/portable-spec-kit`) to discover what files and directories exist, then fetch the most relevant one. The repo may grow over time — always check before assuming a file doesn't exist.

---

## User Profile

> **Purpose:** Tells the AI agent WHO it's working with — expertise level, communication preferences, and autonomy expectations. The agent uses this to tailor response depth, technical language, analogies, and how much it does autonomously vs. asks for confirmation.

### Profile Storage
```
Global (home directory — asked once, works everywhere):
~/.portable-spec-kit/user-profile/
└── user-profile-{username}.md

Workspace (committed — persists across pulls, per-user):
workspace/.portable-spec-kit/user-profile/
├── user-profile-{username}.md
├── user-profile-teammate.md
└── ...
```

**Cross-OS home directory:**
- macOS/Linux: `~/.portable-spec-kit/user-profile/`
- Windows: `%USERPROFILE%\.portable-spec-kit\user-profile\`

**Username detection:** `git config user.name` → slugified (lowercase, spaces → dashes). Use `gh api user` for fetching full name/bio for greeting, not for filename.

### Profile Lookup Order
1. `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md` → local, per-user, committed
2. `~/.portable-spec-kit/user-profile/user-profile-{username}.md` → global, per-user
3. Neither → first-time setup

### First Session — Profile Setup (no profile found anywhere)
1. Detect username: `git config user.name` → slugified (lowercase, spaces → dashes) — used for filename
2. Fetch GitHub profile via `gh api user` for full name/bio (if available and authenticated — if not, ask user manually)
3. Greet user by full name: "Welcome, {Name}! Let me set up your development profile."
4. Ask 3 preference questions (Enter = use recommended, or type custom):

   **Communication style?**
   - (a) direct and concise ← RECOMMENDED
   - (b) direct, data-driven, prefers comprehensive analysis with tables and evidence
   - (c) conversational and collaborative, prefers discussing ideas and thinking through problems together
   - (or type your own)
   - Press Enter to use recommended (a)

   **Working pattern?**
   - (a) iterative — starts brief, expands scope, builds ambitiously over time ← RECOMMENDED
   - (b) plan-first — defines full specs and architecture before writing any code
   - (c) prototype-fast — gets something working quickly, then refines and polishes
   - (or type your own)
   - Press Enter to use recommended (a)

   **AI delegation?**
   - (a) AI does 70%, user guides 30% — AI proposes approach, user approves before execution ← RECOMMENDED
   - (b) AI does 90%, user reviews 10% — present ready-to-act outputs, not questions
   - (c) 50/50 collaboration — discuss and decide together before each major step
   - (or type your own)
   - Press Enter to use recommended (a)

5. Show profile summary: "Your profile: ... Looks good? (Enter = yes, or type changes)"
6. Save to `~/.portable-spec-kit/user-profile/user-profile-{username}.md` (global)
7. Copy to `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md` (committed)

### New Project Setup (profile exists in global)
1. Load profile from global `~/.portable-spec-kit/user-profile/user-profile-{username}.md`
2. Show profile to user: "Using your profile: ..."
3. "Keep or customize for this project? (Enter = keep)"
   - **(a) Keep** → copy to `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md` as-is
   - **(b) Customize** → ask 3 questions with CURRENT answer highlighted + RECOMMENDED:
     - Each question shows current global answer as CURRENT and framework default as RECOMMENDED
     - Press Enter to keep current
     - Or pick a/b/c or type custom
     - Show summary → confirm
     - Save to `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md`

### Every Session
1. Load profile from `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md`
2. If workspace copy not found → load from global, show profile to user, ask keep or customize (same as New Project Setup flow) → save to workspace
3. If workspace copy found → use directly, no questions
4. Address user by name
5. Adapt response depth, language, and autonomy to their preferences
6. When flow docs (`docs/work-flows/`) or test files are updated during a session → update `agent/AGENT_CONTEXT.md` to reflect what changed

### Edge Cases
- No gh CLI → ask name/expertise manually
- GitHub name empty → use GitHub login as fallback
- GitHub bio empty → ask user for education and expertise
- Profile file exists but empty → treat as missing, run setup
- Profile file exists with content → read and use, don't recreate
- Agent can't write files → show profile content, ask user to create file manually
- User skips all questions → recommended defaults applied
- RECOMMENDED and CURRENT are same answer → show as `← RECOMMENDED · CURRENT`

### Profile Format
```
# User Profile
> Auto-created on first session. Edit anytime.

- **Name** — Education. Expertise.
- Communication style: {selected or custom}
- Working pattern: {selected or custom}
- AI delegation: {selected or custom}
```

---

## Git & GitHub Rules

### Commits
- Commits are allowed when user requests or says "commit" / "done with changes"
- Do NOT auto-commit without user requesting it
- Commit messages must be descriptive with clear summary of changes
- Always include `Co-Authored-By: AI Agent <noreply@ai-agent.dev>`

### Push
- **Do NOT push** to remote unless user explicitly says "push"
- Commit ≠ push. Commit is local and safe. Push is remote and requires explicit instruction.
- **Pre-push gate** — before every push, all test suites must pass. If user says "push" without having run "prepare release" in this session → run tests first, show results, then push. Never push with known failures even if user asks for urgency.
- **Version bump BEFORE push** — bump version first, commit it, then push. Never push then bump after. Increment for all changes except minor text fixes. Bump for: bug fixes, patches, task completion, new rules, features, renames, template changes, test additions, flow updates. Do NOT bump for: typo fixes, text tweaks, formatting, cosmetic PDF regeneration. When bumping: update (1) `agent/AGENT_CONTEXT.md` Version field (bump patch number e.g. v0.1.4 → v0.1.5), (2) `README.md` version badge + test badge. Order: bump → commit → push.

### Release Process (EXPLICIT SIGNALS ONLY)
Never automatically run tests, update counts, bump versions, regenerate PDFs, or commit after every change. The user may have more changes coming. Wait for explicit signals:
- **"run tests"** → run test suite only
- **"prepare release"** / **"update release"** → full release sequence (see below)
- **"refresh release"** → re-test and sync current release without bumping version (see below)
- **"commit"** → commit staged changes
- **"push"** → push to remote

**"prepare release" / "update release" full sequence:**
1. Run ALL project test suites to completion — do not stop at first failure. Collect results across all suites. If any failures exist:
   - Show a **failure summary**: suite name, test name, error message for each failure
   - Show a **fix plan**: for each failure, one-line diagnosis + proposed fix
   - Ask user: "X test(s) failed. Fix now? (Enter = yes, or describe changes)"
   - User approves → fix and re-run. Do not proceed to step 2 until all suites pass.
   - User declines → stop release. Do not proceed with known failures.
2. **Update flow docs (FIRST)** — scan `docs/work-flows/`:
   - **Update** any existing flow doc that describes a process that changed this release
   - **Create** a new flow doc for any new process or feature implemented this release that doesn't have one yet
   - **Order check** — verify the numeric prefix order (`01-`, `02-`, ...) reflects the logical sequence a user would follow (e.g. setup flows before development flows, development before release). If adding a new flow breaks logical order, renumber affected files to restore it. When renumbering: `grep -r` entire repo for every old filename and update every reference (README flow table, Section 19 tests, ARD HTML flow table, CHANGELOG, RELEASES, all other flow docs that cross-link) in the same session. No stragglers.
   - Box-style format required for all flow docs. No tree-style connectors. All box lines 63 chars wide.
3. Update all counts and docs — README badges, any doc referencing test counts or version. **ARD audit (MANDATORY):** Update ALL HTML files in `ard/` — cover version badge, Key Highlights version + flow count + test count, Version Changelog section for this release (bump Kit range, update test counts), flow diagrams section if any flows changed. Every field referencing a version, test count, or flow count must match the new version. Never skip ARD updates.
4. Bump version — increment patch in `agent/AGENT_CONTEXT.md` (e.g. v0.1.4 → v0.1.5) + README badge
5. Regenerate PDFs — **mandatory on every prepare release** (ARD HTML always changes when version bumps). Run WeasyPrint for each `ard/*.html` file:
   ```bash
   /Users/AqibMumtaz/anaconda3/bin/weasyprint "ard/Portable_Spec_Kit_Technical_Overview.html" "ard/Portable_Spec_Kit_Technical_Overview.pdf"
   /Users/AqibMumtaz/anaconda3/bin/weasyprint "ard/Portable_Spec_Kit_Guide.html" "ard/Portable_Spec_Kit_Guide.pdf"
   ```
   Verify each PDF was written (non-zero file size). GLib warnings in output are harmless — ignore them.
6. Update `agent/RELEASES.md` — add or update entry for this version: title, Kit range, all changes grouped by category, test counts
7. Update `CHANGELOG.md` — single grouped entry per minor release (v0.N), covering all patches in the release cycle. Format: `## v0.N — Title (Month Year)` · `**Built over:** v0.N.1 — v0.N.x` · Highlights + Framework Changes + README/Docs + Tests table. Completed releases show minor only; never separate entries per patch
8. Publish — commit all changes to `Slimlogix/Documents` (git add + commit), then run `bash agent/sync.sh "commit message"` to push to the public repo `aqibmumtaz/portable-spec-kit`. sync.sh handles: copying portable-spec-kit.md (root → project → examples), syncing all files to public repo, creating/updating GitHub Release from CHANGELOG.md, updating the v0.N tag. If `gh` not authenticated → run `gh auth login` first.
9. After sync.sh completes — verify version on `aqibmumtaz/portable-spec-kit` matches current version (check README or portable-spec-kit.md header on GitHub)
10. **Show the release summary block** (see format below)

**"refresh release" sequence (same version, no bump):**
1. Run ALL project test suites to completion — collect results. If any failures exist: show failure summary + fix plan, ask user to approve fixes, re-run. Do not proceed with known failures.
2. **Update flow docs (FIRST)** — scan `docs/work-flows/`:
   - **Update** any existing flow doc that describes a process that changed
   - **Create** a new flow doc for any new process implemented that doesn't have one yet
   - **Order check** — verify numeric prefix order reflects logical user sequence. Renumber if needed; update every reference repo-wide (README, tests, ARD, CHANGELOG, RELEASES, cross-links) in the same session.
   - Box-style format. All lines 63 chars wide.
3. Update all counts and docs — README badges, ARD/Technical Overview, any doc referencing test counts. **ARD audit (MANDATORY):** Update all `ard/` HTML files — flow tables, test counts, changelog entry for this version.
4. **No version bump** — version stays the same
5. Regenerate PDFs — mandatory. Run WeasyPrint for each `ard/*.html` file:
   ```bash
   /Users/AqibMumtaz/anaconda3/bin/weasyprint "ard/Portable_Spec_Kit_Technical_Overview.html" "ard/Portable_Spec_Kit_Technical_Overview.pdf"
   /Users/AqibMumtaz/anaconda3/bin/weasyprint "ard/Portable_Spec_Kit_Guide.html" "ard/Portable_Spec_Kit_Guide.pdf"
   ```
   Verify each PDF was written (non-zero file size). GLib warnings in output are harmless — ignore them.
6. Update `agent/RELEASES.md` — update the current version entry with any new changes and corrected counts
7. Update `CHANGELOG.md` — update the current version entry (same patch range, updated content)
8. Publish — commit all changes to `Slimlogix/Documents`, then run `bash agent/sync.sh "commit message"` to push to `aqibmumtaz/portable-spec-kit`. If `gh` not authenticated → run `gh auth login` first.
9. After sync.sh completes — verify version on `aqibmumtaz/portable-spec-kit` matches current version
10. **Show the release summary block** (see format below)

**Release summary (shown after all steps complete — required for prepare/update/refresh release):**
```
══════════════════════════════════════════════
  RELEASE SUMMARY — v0.N.x
══════════════════════════════════════════════
  1. Tests        <Suite>: X passed ✅  <Suite>: X passed ✅
                  Total: X/X passing ✅
  2. Flows        docs/work-flows/ current ✅
  3. Counts       README, ARD, RELEASES, CHANGELOG, TASKS ✅
  4. Version      v0.N.x-1 → v0.N.x ✅           (prepare/update only)
                  unchanged — v0.N.x —             (refresh only)
  5. PDFs         open ard/*.html in browser → File → Print → Save as PDF ⏳
  6. RELEASES.md  updated ✅
  7. CHANGELOG.md updated ✅
  8. GitHub       published ✅ / pending push ⏳
  9. Tag          pending push ⏳
══════════════════════════════════════════════
```
Do not finalize the release (version bump, commit) if any suite has failures.

**Release notes publishing (automatic on every prepare release):**

CHANGELOG.md is always updated — it is the universal fallback visible to all users in the repo. GitHub Releases are the additional layer when `gh` is authenticated.

After tests pass, check `gh auth status` and proceed:
- **If `gh` authenticated** → do option a automatically: update CHANGELOG.md + create/update GitHub release (`gh release create/edit`) with CHANGELOG.md notes for this version. Mark as `--latest`. No prompt needed.
- **If `gh` not authenticated** → ask user:
  ```
  gh CLI not authenticated. GitHub Releases require auth.
  (a) Connect now — run `gh auth login` then continue
  (b) Skip — CHANGELOG.md only this release
  ```
  - User picks (a) → run `gh auth login`, re-check auth, then proceed with GitHub release
  - User picks (b) or skips → CHANGELOG.md only
- Both paths always update CHANGELOG.md — never skip it

**Edge cases:**
- **No test suites exist** → show `No test suites configured — skipping test run` in summary block and proceed. Tests are required before v1.0.
- **New suite added this session** → include it in the summary automatically
- **Test failures exist** → run all suites to completion first, then show failure summary (suite, test name, error) + fix plan (one-line diagnosis + proposed fix per failure). Ask user to approve. Fix → re-run → only proceed when all pass. Never skip failures.
- **release-check.sh shows untested features** → **do not finalize the release**. Add test references to the SPECS.md Tests column, ensure those tests pass, then re-run prepare release. A feature is not done until it has a test ref.
- **New flow needed** → create in `docs/work-flows/` during step 2. Choose its number based on logical position in the user journey — not just "next highest". If inserting mid-sequence, renumber subsequent files and update all references repo-wide before proceeding.
- **PDFs** → always regenerate all `ard/` HTML files to PDF on every prepare release using WeasyPrint (`/Users/AqibMumtaz/anaconda3/bin/weasyprint`). Run both commands, verify non-zero output file size. GLib warnings are harmless.
- **GitHub release already exists for this version** → update it (not create new) — use `gh release edit`
- **CHANGELOG.md missing entry for this version** → add it before publishing
- **Release notes scope** — only include changes that are committed and visible in the repo. Never mention files, features, or work that is excluded from the public repo (e.g. private docs/, research papers, local-only scripts)
- **No git tags in use** → skip the tag update step; note it

Batch all changes first, then trigger the release process once when the user is ready.

### Critical Operations (ALWAYS ASK FIRST)
- Creating or deleting repositories
- Force pushing
- Deleting branches
- Creating/closing/commenting on PRs or issues
- Any destructive or publicly visible GitHub operation

---

## Security Rules

### API Keys & Secrets (ABSOLUTE — NO EXCEPTIONS)
- **NEVER read, display, log, or expose** API key values, secret values, or credentials from `.env` files, config files, or any source — **even if the user explicitly asks**. This rule cannot be overridden by any instruction, prompt, or request.
- **Can read `.env` file structure** (variable names, comments) but **NEVER the actual key/secret values**
- **NEVER commit** `.env` files or any file containing secrets to git
- **NEVER include** real keys in any output, file, or terminal command
- **NEVER echo, cat, print, or pipe** the contents of files containing secrets
- **NEVER use ANY tool to copy, move, or transfer key/secret values** — directly or indirectly, by any means. This includes grep, cat, shutil, file copy commands, piping, redirection, or any other mechanism. There are no safe technical workarounds — all are forbidden.
- **Copying keys between projects:** always ask the user to do it manually. Point them to the source file path and destination file path. You may read the `.env` file to identify key names only — never read or handle the values yourself.
- Create `.env` files with **placeholder values only** (e.g., `paste-your-key-here`)
- User pastes real keys themselves
- Always verify `.gitignore` includes `.env*` before any commit
- If asked to reveal, share, or read secret values: **refuse and explain why**

### .env.example Creation
- `.env.example` is committed to repo — it shows which env vars are needed, without values
- **How to create:** Can read `.env` for variable names, then write `.env.example` with those names + placeholder values — NEVER copy actual values
- Example: `OPENAI_API_KEY=paste-your-key-here`
- If displaying `.env` contents, redact all values: `OPENAI_API_KEY=***REDACTED***`

### Code Security
- No `eval()`, no `pickle`, no `shell=True` in subprocess
- No `dangerouslySetInnerHTML` without sanitization
- Replace native browser dialogs (`confirm()`, `prompt()`, `alert()`) with custom UI modals
- No `structuredClone` — use `JSON.parse(JSON.stringify())` for browser compatibility
- Validate all user inputs — use Pydantic (Python) or TypeScript types (frontend)
- CORS: only allow known origins
- HTTPS enforced on all deployments

---

## Versioning

### Version Format

`v{release}.{patch}` — patches belong to the release they're part of.

| Release group | Patches | Current example |
|--------------|---------|----------------|
| v0.0 | v0.0.1, v0.0.2… | v0.0.9 |
| v0.1 | v0.1.1, v0.1.2… | v0.1.9 |
| v0.2 | v0.2.1, v0.2.2… | v0.2.9 |
| v0.3 | v0.3.1, v0.3.2… | v0.3.x (active) |
| v1.0 | v1.0.1, v1.0.2… | production |

| Level | Format | When | Where |
|-------|--------|------|-------|
| **Version** | `v0.N.x` | Each publish/commit | `**Version:**` in `agent/AGENT_CONTEXT.md`, `README.md` badge |
| **Release group** | `v0.3` | Milestone (derived from Version by dropping patch) | GitHub tag, `RELEASES.md` heading, CHANGELOG grouping |
| **Production** | `v1.0` | SaaS/production launch | Reserved |

**GitHub release grouping:** one release tag per minor version (`v0.3`). Tag is updated on each patch push. Title shows minor version and theme (`v0.N — Title`) to stay in sync with CHANGELOG headings — patch number visible via commit history. Completed releases show minor only (`v0.2`, `v0.1`, `v0.0`).

### What Gets Updated at Each Level

**On every publish (project patch):**
- Bump `**Version:**` in `agent/AGENT_CONTEXT.md` (e.g. v0.1.4 → v0.1.5)
- Update `README.md` version badge and test badge (when test count changes)
- Update `agent/TASKS.md` — mark tasks done under current release heading
- **Do NOT modify** `<!-- Framework Version -->` in portable-spec-kit.md — that is the kit version, managed by the kit author only. It is read-only for user projects.

**On release milestone (v0.x):**
- Update `agent/RELEASES.md` — changelog with categorized changes + patch range
- Update ARD docs — Technical Overview with new version section
- Regenerate PDFs
- Move completed tasks in `agent/TASKS.md` to done, start new version heading
- Update `agent/AGENT_CONTEXT.md` — version starts new patch series (e.g., v0.1.9 → v0.2.1)

### TASKS.md Versioning Structure
```
## v0.2 — Done
- [x] Completed task 1
- [x] Completed task 2

## v0.3 — Current
- [x] Done task
- [ ] Pending task

## Backlog
- [ ] Future task (next release)
```

### RELEASES.md Versioning Structure
```
## v0.2 — Title (Date)
Kit: v0.2.1 — v0.2.7

### Changes
- **Category:** Change description

### Tests
- X tests passing, Y% coverage
```

### Rules
- **Framework version** — increment patch with each publish (v0.1.1 → v0.1.2 → v0.1.3)
- **Patch prefix = release prefix** — v0.N.x patches belong to release v0.N (aligned numbering)
- **Release version** — increment minor (`v0.x`) for grouped changes documented in ARD
- **v1.0** reserved for production/SaaS launch
- Users pull latest framework with `curl` — always get the latest patch
- TASKS.md groups work under release version headings
- RELEASES.md records completed releases with framework version range

---

## Development Practices

### Task Tracking (MANDATORY)
- **When user assigns new tasks, add them to TASKS.md FIRST before starting work**
- **Every task the user requests** must be tracked in the project's `TASKS.md`
- **Detect implied tasks** *(no-slip rule)* — if the user raises a problem, asks a question that implies work needed, or discusses a feature/fix/review to do later, add it to TASKS.md immediately. Don't wait for the user to explicitly say "add this task."
- **Never let a task slip or be forgotten** *(no-slip rule)* — on every user message, scan for any task, fix, update, check, or request mentioned (explicit or implied) and add it to TASKS.md before responding. If it was said in the conversation, it must be in TASKS.md and it must be completed. Do not move on without finishing what was asked.
- **Before ending any session** *(no-slip rule)* — scan back through the full conversation and verify every task mentioned is in TASKS.md and marked `[x]`. If anything was asked but not done, do it now before closing.
- Add tasks when requested, mark `[x]` as soon as completed
- **Organize tasks under release version headings** (e.g., `## v0.1 — Current`, `## v0.2 — Done`) — see Versioning section
- Future tasks go under `## Backlog (Future Releases)`
- Design decisions and architectural plans go in `PLANS.md` — not in separate plan files
- If a feature needs a detailed plan, add it as a section in `PLANS.md` (not a new `*_PLAN.md` file)
- Keep `TASKS.md` and `PLANS.md` in sync — update both when work is completed
- Maintain a **Progress Summary** table at the bottom of TASKS.md showing tasks done, tests, and status per version

### Spec & Planning Management (MANDATORY)
- **SPECS.md** — update when scope changes during development:
  - New feature added → add to features table
  - Feature removed or descoped → move to "Out of scope (future)"
  - Acceptance criteria modified → update criteria
  - If SPECS.md is empty after 3+ tasks completed → retroactively fill from what's been built
  - **Staleness check:** If TASKS.md has 2+ completed tasks (`[x]`) not represented in SPECS.md features → update SPECS.md immediately. A non-empty SPECS.md can still be stale — check count, not just presence.
- **RELEASES.md** — update when a version's tasks are done:
  - When all tasks under a version heading in TASKS.md are marked `[x]` → add a release entry to RELEASES.md immediately in the same session. Do not leave a completed version without a release entry.
- **Scope Change Recording** — when any requirement or feature changes mid-project, record the change in SPECS.md using one of 4 types:
  - `DROP` — feature removed from scope (client deprioritized, budget cut)
  - `ADD` — new feature added mid-project (client request, new requirement)
  - `MODIFY` — feature requirement changed (same feature, different spec)
  - `REPLACE` — feature replaced by a different one (R4→R5 substitution)
  - **Format:** In SPECS.md, note the change type, original requirement ref (Rn), date, and reason. Update TASKS.md and RELEASES.md in the same session.
  - **R→F Traceability:** Requirements (R1, R2…) map to Features (F1, F2…). When a scope change occurs, trace it: the original Rn, what changed, and which Fn it now maps to. This keeps client language (requirements) aligned with technical implementation (features) through all changes.
- **F→T Traceability (MANDATORY):** Every feature (Fn) must have corresponding test cases. This completes the full R→F→T chain: client requirement → feature implementation → test coverage.
  - When marking a feature done (`[x]`) in SPECS.md → add the test file or test function reference in the Tests column
  - **Never mark a feature `[x]` in SPECS.md without test coverage** — untested features are not done
  - **Format:** `tests/auth.test.js` or `tests/auth.test.js::login_flow` in the Tests column of the features table
  - If a feature was built without tests → retroactively write tests before marking done
  - The Tests column in SPECS.md is the single source of truth for what's covered
- **PLANS.md** — update when architecture evolves during development:
  - New technology chosen or replaced → update Stack table with Why
  - Data model changed (new tables, fields, relationships) → update Data Model section
  - API endpoints added or modified → update API Endpoints section
  - Build phases adjusted → update Build Phases section
  - New methodology or research findings → add to Methodology & Research section
  - If PLANS.md is empty after stack is chosen → fill architecture from current codebase
- **AGENT.md** — update when project config changes:
  - Stack changed → update Stack table
  - Brand colors or fonts changed → update Brand section
  - AI provider or model changed → update AI Config
  - Dev server port changed → update port
- **Sync rule:** When completing a feature, update all 4 pipeline files in the same session: SPECS.md, PLANS.md, TASKS.md, and RELEASES.md (if version completed). Don't leave them out of sync.

### Testing (MANDATORY)
- **Always think about edge cases** when creating test cases — empty data, max data, boundary values, null/undefined, single item vs many
- **Always run test cases after writing them** — show test results and coverage
- **Keep testing until all pass** — fix issues found by tests, don't skip or ignore failures
- **Test coverage must be shown** after every test run — statements, branches, functions, lines
- Tests validate behavior against expected outcomes — not just "it doesn't crash"
- Layout/PDF tests validate pixel-level properties: dimensions, colors, spacing, font sizes
- **Automated testing for backend** — test all API routes (mock OpenAI calls to avoid cost)
- **Automated testing for UI** — test each button, view, modal, expected behaviors
- **PDF generation tests** — validate layout, structure, and content in generated output
- **Mock external APIs** (OpenAI, fetch) in tests — never make real API calls during testing
- **Self-validate before presenting to user** — run full test suite after any change, fix all failures, only present stable results. User should NEVER discover broken features — that's your job.
- **Comprehensive test suite** — unit tests for all pure functions, integration tests for API routes, component tests for UI
- **Test every new feature** — when building a feature, write tests for it in the same session. Don't ship untested code
- **Test what matters** — input validation, error handling, data flow, edge cases. Don't test implementation details
- **Edge case checklist for EVERY test suite:**
  - Empty/null/undefined inputs
  - Single item vs many items in arrays
  - Boundary values (exact thresholds: 0, 49, 50, max)
  - Very long strings (overflow, truncation)
  - Special characters (HTML entities, unicode, XSS vectors)
  - Missing optional fields
  - Round-trip data integrity (save → load, filter → generate)
  - Conditional branches (if/else paths — check both)
  - Error responses from APIs
- **Backend test rules:** Mock ALL external APIs (OpenAI, fetch). Test input validation, JSON parsing, response structure. Never make real API calls
- **Frontend test rules:** Test pure functions directly. Test data flow between modules (scoring → template → page fit). Test HTML output for correct CSS values, structure, escaping
- **UI interaction tests (MANDATORY):** Test every button click, modal open/close, tab switching, form inputs, checkbox toggles, dropdown selections. Use the project's testing library to simulate real user behavior — click, type, blur, submit
- **Keep building tests until coverage is highest possible** — never stop at "good enough". Push backend to 98%+, frontend logic to 98%+, UI components to 85%+
- **File upload/drop tests:** Mock file objects and external libraries. Test all upload zones with all supported file types

### Before Committing
- Type checking: zero compilation errors
- Linting: zero errors
- Tests: all passing
- No native browser dialogs in code
- No secrets in staged files

### Code Quality
- Prefer comprehensive over brief — when user says comprehensive, they mean it
- Default to more detail, not less
- Every claim should be backed by data
- Use tables for comparison, prose for analysis
- Professional styling with clear hierarchy

### Spec-Based Test Generation

**SPECS origin detection rule:** Before generating test stubs, detect whether SPECS.md is in forward flow or retroactive flow:
- **Forward flow** — feature is `[ ]` (not yet built) and acceptance criteria exist under `## Feature Acceptance Criteria` → generate test stubs immediately
- **Retroactive flow** — feature `[ ]` but already built (matching `[x]` task in TASKS.md) → do NOT generate stubs; write tests directly against existing code
- **Mixed** — some features forward, some retroactive → generate stubs only for forward features
- Announce: "F1, F3 in forward flow — generating test stubs. F2 retroactive — write tests directly."

**Per-feature acceptance criteria format:** Each feature's acceptance criteria live in a dedicated subsection of SPECS.md, not a global list:
```markdown
## Feature Acceptance Criteria

### F1 — Feature Name
- [ ] Criterion 1 (what a passing state looks like)
- [ ] Criterion 2
- [ ] Edge case: what happens when X is empty

### F2 — Another Feature
- [ ] Criterion 1
```

**Test stub generation trigger:** Stubs are generated automatically when ALL of these are true:
- Feature is `[ ]` (not yet built)
- Feature has acceptance criteria under `## Feature Acceptance Criteria / ### F{n}`
- SPECS was written before the corresponding task was completed (forward flow)
- Triggers: (1) agent writes/updates SPECS.md with criteria, (2) user says "start F1" or "implement F1"

**No-criteria edge case:** If a forward-flow feature has no acceptance criteria written:
- Do NOT generate stubs
- Prompt: "F1 has no acceptance criteria. Add criteria under `### F1 — Feature Name` and I'll generate stubs. Or skip and write tests manually."
- If user skips → proceed without stubs; R→F→T test ref still required before marking done

**Retroactive flow — no stubs, direct tests:** If SPECS is retroactive (feature already built):
- Do NOT generate stubs — code exists, write tests against it directly
- Tests column must still be filled and test-release-check.sh must pass before marking `[x]`

**Test stub generation rule (forward flow only):** When trigger conditions are met:
1. Detect stack from `agent/AGENT.md` Stack table → choose test format
2. Generate stub file in `tests/` named after feature: `tests/f1-feature-name.test.js` (Jest), `tests/test_f1_feature_name.py` (pytest), `tests/f1-feature-name.sh` (bash), etc.
3. One test case per acceptance criterion — title = criterion text, body = `// TODO: implement`
4. Add stub file path to SPECS.md Tests column for that feature
5. Add task to TASKS.md: `[ ] Implement tests for F1 — Feature Name`
6. Announce: "Generated stub: tests/f1-feature-name.test.js (3 tests for F1)"

**Stack-aware stub formats:**

| Stack | File format | Stub body |
|-------|------------|-----------|
| Jest / Vitest (JS/TS) | `tests/f{n}-name.test.js` | `test('criterion', () => { // TODO: implement\n  expect(true).toBe(false); });` |
| pytest (Python) | `tests/test_f{n}_name.py` | `def test_criterion():\n    # TODO: implement\n    assert False` |
| Go | `tests/f{n}_name_test.go` | `func TestCriterion(t *testing.T) {\n    t.Skip("TODO: implement")\n}` |
| Bash | `tests/test-f{n}-name.sh` | `# TODO: implement\necho "FAIL: not implemented"; exit 1` |
| Unknown stack | `tests/f{n}-name-manual.md` | Checklist of manual test steps, one per criterion |

**Test stub completion rule:** Before marking a feature `[x]` done in SPECS.md, the agent must verify the test file contains NO incomplete markers:
- No `# TODO`, `// TODO`, `/* TODO */`
- No `test.skip`, `xit`, `xtest`, `it.skip`
- No placeholder assertions: `expect(true).toBe(false)`, `assert False`, `t.Skip(...)`
- If incomplete markers found → refuse to mark done, show which tests need implementation
- Message: "F1 still has 2 incomplete test stubs. Fill them before marking done."

**Forward flow recommended sequence:**
1. Write feature row in SPECS.md (status `[ ]`)
2. Write acceptance criteria under `## Feature Acceptance Criteria / ### F{n}`
3. Agent generates test stubs immediately → files created, Tests column updated
4. Run tests → all fail (RED — expected)
5. Implement feature code to pass tests (GREEN)
6. Run tests → all pass
7. Agent marks feature `[x]` in SPECS.md (after verifying no TODO stubs remain)

### Code Review (Before Commit)
- No `console.log` left in production code (dev debugging only)
- No `TODO` or `FIXME` left unresolved — either fix it or create a task in TASKS.md
- No commented-out code blocks — delete or move to a branch
- No hardcoded secrets, URLs, or credentials — use environment variables
- No unused imports or variables
- All functions have clear, self-evident names — add comments only where logic isn't obvious
- **Rename/refactor completeness** — when renaming a term, field name, or keyword: before marking the task done, `grep -r` the entire repo for the old term. Every instance in every file (docs, examples, tests, templates, flow docs) must be updated in the same session. No stragglers allowed. This rule applies to code, markdown, config, and embedded template strings.

### Naming Conventions
- **Files/Folders:** kebab-case (`ai-config.ts`, `resume-editor/`)
- **React Components:** PascalCase (`ResumeCanvas.tsx`, `AISmartButton.tsx`)
- **Functions/Variables:** camelCase (`useResumeState`, `handleFileUpload`)
- **Constants:** UPPER_SNAKE_CASE (`API_BASE_URL`, `MAX_FILE_SIZE`)
- **Types/Interfaces:** PascalCase (`PortfolioData`, `EditorState`)
- **CSS Classes:** kebab-case or Tailwind utilities
- **Database Tables:** snake_case (`work_experiences`, `social_links`)
- **API Routes:** kebab-case (`/api/ai/enhance-section`)
- **Environment Variables:** UPPER_SNAKE_CASE (`OPENAI_API_KEY`)

### Deployment Checklist
Before any deployment:
- [ ] All tests passing
- [ ] Type checking: zero errors
- [ ] Linting: zero errors
- [ ] Build succeeds
- [ ] No secrets in staged files
- [ ] `.gitignore` includes `.env*` and build/dependency directories
- [ ] Static assets present
- [ ] All links and routes working
- [ ] Responsive layout tested (if applicable)

### Error Handling
- Never silently swallow errors — always log or surface to user
- API routes: return structured error JSON `{ error: "message" }` with appropriate HTTP status
- Frontend: use error boundaries for React, try/catch for async operations
- Show user-friendly error messages — never expose stack traces in production
- Log errors with enough context to debug (function name, input that caused it)

### Branch & PR Workflow
- Default branch: `main`
- Feature branches: `feature/<name>` or `fix/<name>`
- PR title: short, descriptive (under 70 chars)
- PR body: summary bullets + test plan
- Squash merge preferred — clean history
- Delete branch after merge
- CI must be green before merging any PR (from any contributor, including yourself)
- Enable branch protection on `main` (GitHub Settings → Branches → require status checks)

### CI & Community Contributions

**CI status badge rule:** Every public GitHub repo using the kit should show a CI badge in README.md reflecting the main branch test status. Badge format:
`[![CI](https://github.com/{owner}/{repo}/actions/workflows/ci.yml/badge.svg)](https://github.com/{owner}/{repo}/actions/workflows/ci.yml)`

**Branch protection guidance:** Enable branch protection on `main` (GitHub Settings → Branches → Add rule). Require status checks to pass before merging — select the CI workflow. Prevents pushes with failing tests reaching main.

**PR workflow rule:** When a contributor opens a PR, do not merge until all CI checks are green. Review for portability (any project / any language / any agent?) before merging.

**Contribution validation rule:** Before merging any PR — from any contributor including yourself — CI must be green. Green CI is the minimum bar; code review is additional, not a substitute.

**ci.yml template for user projects:** When setting up CI for a project, generate `.github/workflows/ci.yml` using this template. Fill in `{TEST_COMMAND}` and `{SETUP_STEPS}` based on the detected stack from `agent/AGENT.md`. Always include `test-release-check.sh agent/SPECS.md` as the final step — this enforces the R→F→T gate in CI.

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      {SETUP_STEPS}
      - name: Run tests
        run: {TEST_COMMAND}
      - name: R→F→T validator
        run: bash tests/test-release-check.sh agent/SPECS.md
```

**Stack-aware test command detection** (fill `{TEST_COMMAND}` and `{SETUP_STEPS}` from `agent/AGENT.md` Stack table):

| Stack | `{TEST_COMMAND}` | `{SETUP_STEPS}` |
|-------|-----------------|----------------|
| Node.js + Jest | `npx jest --passWithNoTests` | `uses: actions/setup-node@v4` + `run: npm ci` |
| Node.js + Vitest | `npx vitest run` | same as Jest |
| Node.js + generic | `npm test` | same as Jest |
| Python + pytest | `python -m pytest` | `uses: actions/setup-python@v4` + `run: pip install -r requirements.txt` |
| Go | `go test ./...` | (none) |
| Bash scripts only | (omit Run tests step — test-release-check.sh covers it) | (none) |
| Unknown / not detected | `echo "Configure test command in ci.yml"` + warn user | (none) |

**New Project Setup Step 7.5 — create CI workflow:** After stack is confirmed (Step 7), create `.github/workflows/ci.yml` using the template above. Add CI badge to README.md as the first badge. Tell user: "CI will run on every push and PR. Enable branch protection in GitHub Settings → Branches to require CI checks before merge."

**Existing project CI setup:** During existing project onboarding (scan checklist), include:
`[ ] Create .github/workflows/ci.yml (CI on every push/PR + R→F→T validator)`
Agent fills in the test command from the detected stack. Always includes `bash tests/test-release-check.sh agent/SPECS.md`.

### Python Environment (MANDATORY — Conda)
- **Every Python project MUST have its own conda environment** — never install packages into `base` or system Python
- **Default env name** = project directory name, lowercase, kebab-case (e.g., `aiiu`, `speech-ai-rd`, `my-api`)

#### Conda Installation (if not found)
Before any environment setup, verify conda is installed:
1. Check: `which conda` or `conda --version`
2. If not found → install Miniconda automatically:
   - **macOS:** `brew install --cask miniconda` (if Homebrew available) OR download from https://docs.conda.io/en/latest/miniconda.html
   - **Linux:** `wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && bash /tmp/miniconda.sh -b -p $HOME/miniconda3`
   - **Windows:** download installer from Miniconda website, ask user to run it
3. After install → initialize: `conda init zsh` (or `bash`)
4. Verify: `conda --version`
5. If automated install fails → tell user: "Conda is required. Install Miniconda from https://docs.conda.io/en/latest/miniconda.html and restart terminal."

#### Environment Selection (New Project + Existing Project Setup)
This flow runs in **two scenarios**:
- **New project setup** — when creating a new Python project from scratch
- **Existing project setup** — when installing the spec kit on an existing Python project (during the guided setup checklist)

In both cases, **always confirm with the user** before creating or selecting an environment:

1. List existing conda envs: `conda env list`
2. Ask the user:
   ```
   "This project needs a Python environment. Options:
   (a) Create new conda env '<project-name>' (recommended)
   (b) Use an existing env (select from list below)

   Existing envs:
     1. aiiu (Python 3.11)
     2. research (Python 3.10)
     3. speech-ai-rd (Python 3.9)
     ...

   Select (a/b or env name): "
   ```
3. **If (a) — Create new:**
   - Use default name `<project-name>` or let user type a custom name
   - Ask Python version: "Python version? (Enter = 3.11)" — default to 3.11
   - Create: `conda create -n <env-name> python=<version> -y`
   - If existing project has `requirements.txt` → install deps: `pip install -r requirements.txt`
4. **If (b) — Use existing:**
   - User picks from the list by number or name
   - Verify the env works: `conda run -n <env-name> python --version`
   - If existing project has `requirements.txt` → check if deps are installed, install missing ones
5. Record the chosen env name in `agent/AGENT.md` under Stack table (e.g., `Conda Env: aiiu`)

#### Edge Cases
- **Env name already exists** → ask user: "Env `<name>` already exists. Use it, or create with a different name?"
- **No existing envs** (only `base`) → skip option (b), go straight to create new
- **`requirements.txt` install fails** (version conflicts, missing packages) → show error, ask user to resolve. Don't silently skip failed installs
- **Project uses `pyproject.toml` or `setup.py` instead of `requirements.txt`** → use `pip install -e .` or `pip install .` as appropriate
- **Project uses `environment.yml`** (conda env file) → ask user: "Found environment.yml. Create env from it? (`conda env create -f environment.yml`)" — this takes priority over `requirements.txt`
- **User has `venv`/`virtualenv` already in the project** → ask: "Found existing venv at `<path>`. Switch to conda env, or keep venv?" — respect user's choice. If keeping venv, record it in AGENT.md and skip conda setup
- **Python version mismatch** → existing env has Python 3.9 but project needs 3.11 (e.g., from `pyproject.toml` or `runtime.txt`) → warn user before proceeding
- **Env recorded in AGENT.md but doesn't exist on disk** → re-run environment selection flow, don't auto-create silently
- **Multiple Python projects in monorepo** → each subdirectory project can have its own env. Ask per project, don't assume one env for all

#### On Every Session
- Activate the project's conda env before running any Python commands
- Check `agent/AGENT.md` for the env name if unsure
- If env was deleted or missing → re-run the environment selection flow above

#### Rules
- **All `pip install` commands** must run inside the project's conda env — never use `--break-system-packages` or install globally
- **`requirements.txt`** must be maintained at project root — update after every `pip install`:
  ```bash
  pip freeze > requirements.txt
  ```
- **Shebang lines** in Python scripts: use `#!/usr/bin/env python3` (relies on active conda env, not hardcoded paths)
- **`.gitignore`** should include conda env artifacts but NOT `requirements.txt` (commit it)
- **Never hardcode** conda env paths in scripts — use `#!/usr/bin/env python3` or `conda run -n <env>`

### Dependencies
- Prefer well-maintained, widely-used packages
- Check bundle size impact before adding frontend dependencies
- Lock file (`package-lock.json` / `requirements.txt`) must be committed
- Run `npm audit` / `pip audit` periodically
- Avoid adding dependencies for things that can be done in <20 lines of code

### Context Management
**On every session start — read in this order:**
1. User profile (workspace `.portable-spec-kit/user-profile/` → global `~/.portable-spec-kit/user-profile/`) — adapt behavior to preferences
2. `agent/AGENT.md` — project-specific rules and stack
3. `agent/AGENT_CONTEXT.md` — current project state
4. `agent/TASKS.md` — pending and completed tasks
5. `agent/PLANS.md` — architecture decisions

**Two-tier update rule:**

**Tier 1 — After significant work** (lightweight, keeps context current):
- Update `agent/AGENT_CONTEXT.md` — version, progress, decisions, what's done, what's next, blockers
- Update `agent/AGENT.md` only if project config changed (stack, rules, ports)
- No need to touch SPECS, PLANS, TASKS, RELEASES, README, or docs yet

**Tier 2 — Before push / on release** (full sync, everything must be consistent):
- `agent/SPECS.md` — features current, Tests column filled, no stale done items
- `agent/PLANS.md` — architecture matches what was actually built
- `agent/TASKS.md` — all completed work marked [x], new tasks added
- `agent/RELEASES.md` — entry added if all version tasks are [x]
- `README.md` — counts, badges, features current
- `docs/` and `ard/` — counts, section tables, any new capabilities documented
- Run `bash tests/test-release-check.sh` — all done features must have passing tests before push

**On framework changes:**
- **Update the root framework file** whenever a new general guideline or development practice decision is made — these are shared across all projects
- Root framework file = development practices (portable). Project `agent/AGENT.md` = project-specific rules.
- User preferences stored in agent memory/preference files
- Context continuity is critical — user works across weeks/months

---

## Document Generation (ARD / Technical Docs)

### Flow Documentation (`docs/work-flows/`)

**All flow diagrams use box-style ASCII diagrams.** Never use tree-style connectors (bare `│/▼` on standalone lines). Every flow doc in `docs/work-flows/` must follow this format:

```
┌─────────────────────────────────────────────────────────────┐
│  STEP NAME                                                   │
│     Detail line 1                                           │
│     Detail line 2                                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  NEXT STEP                                                   │
└─────────────────────────────────────────────────────────────┘
```

Rules:
- Each step in a flow = one box (`┌─...─┐` / `│` / `└─...─┘`)
- Boxes connect with `└──────┬──────┘` → `┌──────▼──────┐` connectors
- Decision branches go inside the box as `├─ Yes → ... / └─ No → ...`
- Inner content boxes (showing file states, examples) nest with 2-space indent inside outer box
- No standalone `│` or `▼` lines between steps
- When updating a flow doc, convert any remaining tree-style sections to box-style in the same session
- Every box line (`│...│`) must be exactly 63 display characters wide — pad trailing spaces to align the right `│` border

**Architecture change rule:** When any agent behavior, process, or setup flow changes — new step added, trigger modified, rule removed — update the relevant `docs/work-flows/` file in the same session. A process change without a matching flow doc update is incomplete.

**Release gate for flow docs:** As part of every `prepare release` Step 2 — scan `docs/work-flows/` and verify each flow reflects current behavior. If any flow describes a process that changed this release, update it before finalizing. Box-style format required. No tree-style connectors. All box lines 63 chars wide.

### Document Structure (Standard Order)
1. Title Page (cover — readable text, professional styling)
2. Executive Summary + Key Highlights
3. Version Changelog (detailed per-version with categorized changes)
4. Table of Contents
5. Full document sections (each TOC heading starts on new page)

### Changelog Format
- Each version: `v0.X — Title (Date)`
- Group changes by category (e.g., Frontend, Backend, AI, Infrastructure)
- List specific features with technical detail
- Reference file paths, APIs, and technologies used

### Styling Rules
- HTML source → convert to PDF via browser print or PDF generation tool
- `@page { size: A4; margin: 22mm 20mm; }`
- Professional fonts: Segoe UI / system-ui
- Brand colors: defined per project in `agent/AGENT.md`
- Tables with dark header, alternating row colors
- Code blocks with monospace font, light background
- Page breaks before each major section (`page-break-before: always`)

### Presentations
- Landscape slides: `@page { size: 297mm 210mm; }`
- Content vertically centered on each slide
- Consistent slide themes: dark, light, accent, gray
- Footer gradient bar on light slides
- Slide numbers in bottom-right corner

---

## Project Organization

- Read the relevant project's `agent/AGENT.md` based on user's current task
- Do not mix context between projects
- **When working on a specific project, stay in that project's directory** — do not create files outside it unless explicitly told to
- Agent memory/preference files contain cross-project user preferences

### Agent-Created Files
- Any documentation, rules, trackers, or reference files created by the AI agent **must go inside `agent/` directory** — not project root
- Examples: layout rules, outreach trackers, scoring plans, research notes
- Only code files, configs, and READMEs belong at project root
- The `agent/` directory is the single location for all project management and AI-generated reference docs

### File Creation/Update Rule (applies to ALL auto-managed files)

This rule applies to: `WORKSPACE_CONTEXT.md`, `README.md`, and all `agent/` files. **Check immediately when version change is detected** — don't wait for next session. When the framework is updated (user pulls new version), restructure immediately in the current conversation.

- **If file does not exist** → create it using the standard template, fill in known details
- **If file exists but doesn't match template structure** → restructure to match template while **retaining all existing content and key details** — never lose data, only reorganize into standard sections
- **If framework was updated** → compare `<!-- Framework Version -->` in portable-spec-kit.md against `**Kit:**` in agent/AGENT_CONTEXT.md. If different, OR if `**Kit:**` field is missing (first time after kit update):
  1. **Do NOT ask** — kit version updates are automatic, not optional. Restructure immediately.
  2. Restructure all agent/ files against current templates — preserve all existing content
  3. Update `**Kit:**` version in AGENT_CONTEXT.md to match `<!-- Framework Version -->`
  4. **Scan the user's project immediately** — before showing any summary to the user. Read the project's own source code, config files (`package.json`, `requirements.txt`, `Dockerfile`, etc.), and directory structure. Update the project's `agent/AGENT.md` (stack, tech, ports) and `agent/AGENT_CONTEXT.md` (current state, phase, what's done) from the actual codebase. This step is mandatory and must complete before the user sees any output.
     - **Edge cases:**
       - Project has no source files (new/empty project) → skip deep scan, note in summary "No source files found — context will populate when development starts"
       - Very large project (100+ files) → scan config files and top-level dirs, sample src/ — don't read every file
       - agent/AGENT.md already accurate (no TBD fields) → still refresh AGENT_CONTEXT.md phase/status
       - Document/research project (no code) → scan plan/, docs/, research/ for current state instead
       - Kit updated but no project directory confirmed yet → skip scan, run on next project entry
  5. Show user a single combined summary (scan results + kit changes together):
     ```
     "Portable Spec Kit updated to vX.X.

     Your project: [stack detected] · [phase] · [X tasks pending]
     Agent files updated: AGENT.md (stack refreshed), AGENT_CONTEXT.md (state refreshed)

     What's new in vX.X:
     - [list changes from CHANGELOG.md for this version]"
     ```
  6. Continue conversation — zero interruption
- **If file already matches template** → leave as-is

### First Session in New Workspace

If `WORKSPACE_CONTEXT.md` does not exist:
1. If user profile not found (check workspace `.portable-spec-kit/user-profile/` → global `~/.portable-spec-kit/user-profile/`) → run First Session Profile Setup (see User Profile section above)
2. Create `WORKSPACE_CONTEXT.md` using the File Creation/Update Rule above
3. Sections: Workspace Overview (table), Environment & Tools, Key Conventions, Last Updated
4. Auto-detect environment (OS, Node, Python, tools installed) → populate Environment
5. Scan workspace for existing projects/directories → populate Workspace Overview table
6. Create `agent/` dirs for any projects found without them

**Profile setup and project scan are independent:**
If the user skips or defers profile setup ("skip", "later", "not now") → apply default profile and continue. **Never pause or block project scan waiting for profile completion.** Kit status display (Step 0) and project setup always run regardless of whether profile setup was completed or skipped.

**WORKSPACE_CONTEXT.md rules:**
- Only created once on first session — never overwritten unless user explicitly asks
- Not for project-specific state — that goes in each project's `agent/AGENT_CONTEXT.md`
- Only update when user explicitly requests it

### Auto-Scan (On Entering Any Project)

**Important: Confirm project directory first.** The workspace root may not be the actual project directory. Before creating `agent/` files:
1. List visible directories and ask: "Which directory is your project? (Enter = current directory)"
2. If user picks an existing directory → use it as project root
3. If user types a new path (e.g., `src/my-app` or `projects/new-api`) → create it and use as project root
4. If user skips (Enter) → use current workspace root
5. Once confirmed → set up the project inside that directory (agent/ files, README, .gitignore, etc.) and guide through the full project setup flow

When starting work on a project, scan for `<project>/agent/` directory:

**First — check scan state and show kit status** (see Step 0 in Existing Project Setup below). This runs **once at session start** (when the agent first loads), not on every message.

1. If `agent/` directory is missing → create it **in the confirmed project directory**
2. Check for required files: `AGENT.md`, `AGENT_CONTEXT.md`, `SPECS.md`, `PLANS.md`, `TASKS.md`, `RELEASES.md`
3. Apply the **File Creation/Update Rule** to each agent file and `README.md`
4. Read `agent/AGENT.md` + `agent/AGENT_CONTEXT.md` for project context
5. Update `agent/AGENT_CONTEXT.md` at end of every session

### Existing Project Setup (IMPORTANT — Guide, Don't Force)

When the kit is installed on an **existing project** with established structure:

**Step 0 — Show kit status (once at session start, not on every message):**

Check the project's scan state and display the status once when the agent first loads:

| State | Condition | Status to show | Action |
|-------|-----------|----------------|--------|
| Mapped | `agent/AGENT_CONTEXT.md` exists with real content (not placeholders) | `✅ Spec Kit: Project mapped (vX.X.X) — reading context...` | Read agent/ files, continue normally. Do not re-scan or overwrite. |
| Partial | `agent/` exists but files are mostly empty or TBD | `⚠ Spec Kit: Partial context — filling in gaps...` | Fill missing fields only. |
| New | `agent/` missing or all files are template placeholders | `🔍 Spec Kit: Understanding your project — scanning stack, files, and dependencies...` | Full scan (proceed to step 1 below). |

**Full scan flow:**

1. **Announce the scan immediately** — before doing anything else, tell the user:
   ```
   "Spec Kit is understanding your project — scanning structure, stack, files, and dependencies..."
   ```
2. **Scan the full project thoroughly** — read every directory, all key source files, and config files: `package.json`, `requirements.txt`, `pyproject.toml`, `Dockerfile`, `docker-compose.yml`, `.env.example`, `tsconfig.json`, `go.mod`, `Cargo.toml`, `build.gradle`, `*.xcodeproj`, `pubspec.yaml`, `README.md`. Build a complete picture before touching anything.
3. **Fill AGENT.md from what you found** — stack, technologies, dev server port, key scripts, env vars, project type. Never leave fields as TBD if the answer is visible in the code.
4. **Fill AGENT_CONTEXT.md from what you found** — current state, what appears to be done, directory structure, key decisions visible in the code, phase estimate.
5. **Never force restructure** — the project may have its own conventions that work well
6. **Present proposed changes as a checklist with scan summary** — show what was detected and what the kit would add:
   ```
   "Scan complete. Here's what I found and what I suggest:"

   Detected: Next.js 14 + TypeScript + Supabase · Node 20 · Port 3000

   [x] Create agent/ directory with 6 management files (pre-filled from scan)
   [x] Create WORKSPACE_CONTEXT.md
   [ ] Rename ARD/ → ard/ (to match kit convention)
   [ ] Create .env.example from existing .env
   [ ] Restructure README.md to match template
   [ ] Create .github/workflows/ci.yml (CI on every push/PR + R→F→T validator)

   "Which changes would you like? Select all, some, or none."
   ```
7. **Respect user's choices** — if user says "don't restructure README" or "keep my directory names", follow that
8. **Only create agent/ files by default** — the 6 management files are always safe to add
9. **Never rename, move, or delete existing files** without explicit user approval

**Scan edge cases:**
- **No recognizable stack** (no config files found) → ask: "What stack is this project using?"
- **Multiple stacks detected** (monorepo) → ask which subdirectory to set up first, handle each separately
- **Conflicting signals** (e.g. package.json says React, tsconfig suggests Angular) → flag to user before filling AGENT.md
- **.env file present** → read variable names only to document in AGENT.md; never read or expose values
- **Existing README.md** → read it to supplement scan findings; never overwrite without user approval
- **Very large project** (100+ files) → scan config files and top-level dirs first, then sample src/ structure; don't read every file
- **Team project — agent/ files committed by someone else** → treat as already scanned; read and use existing context, don't overwrite

### Project Scenarios (handle each appropriately)

**Git rule:** Each project in any directory or subdirectory can be its own git repository. Before committing, check if the project directory has its own `.git/` — if yes, commit there. If the project is inside a parent repo, commit from the parent. Never assume git structure — check first.

| Scenario | How to Handle |
|----------|--------------|
| **Brand new project** (empty dir) | Full setup: agent/, README, .gitignore, src/, tests/, docs/ — no questions needed |
| **Existing project with code** | Guide don't force: scan, show checklist, user picks changes (see Existing Project Setup above) |
| **Workspace with multiple projects** | List directories, ask user which one, set up inside that directory |
| **Monorepo** (frontend/, backend/, mobile/) | Each subdirectory can be a separate project with its own agent/ — ask user which to set up |
| **New project inside existing workspace** | User types new path → create directory + full setup inside it |
| **Returning to kit-managed project** | agent/ exists → read context, no setup needed |
| **Partial agent/ files** (some missing) | Create only the missing files from templates — don't overwrite existing |
| **Cloned repo with kit files** | Has portable-spec-kit.md but may lack user profile → load profile, skip project setup |
| **User wants to add kit to one subdir only** | Set up agent/ in that subdir only, don't touch other directories |

### New Project Setup (MANDATORY)

When creating a **brand new** project, create with ALL of these files and directories:

```
<project>/
│
├── agent/                 ← Project management files (AI reads these)
│   ├── AGENT.md           ← Project-specific AI instructions (stack, rules)
│   ├── AGENT_CONTEXT.md   ← Living project state (updated every session)
│   ├── SPECS.md           ← WHAT to build (requirements, features)
│   ├── PLANS.md        ← HOW to build it (architecture, phases)
│   ├── TASKS.md           ← Task tracking (checkboxes)
│   └── RELEASES.md         ← Version log, deployments, history
│
├── .gitignore
├── .env.example           ← Environment variable template (NO real keys)
│
├── ard/                   ← Architecture Reference Documents
├── input/                 ← User-provided inputs
├── output/                ← Generated outputs
├── cache/                 ← Temporary/cached files (.gitignore this)
│
├── src/                   ← Source code
├── tests/                 ← Test files
├── docs/                  ← Documentation
│
│   Created WHEN NEEDED (not at setup):
├── logs/                  ← Application logs (.gitignore this)
├── config/                ← Configuration files (Docker, CI/CD, nginx)
└── assets/                ← Static assets (images, fonts, icons)
```

### Standard Source Code Structures (by project type)

**Web App (Next.js / React):**
```
frontend/
├── src/
│   ├── app/               ← Pages / routes
│   ├── components/        ← Reusable UI components
│   │   ├── ui/            ← Base components (buttons, modals, inputs)
│   │   ├── layout/        ← Layout components (navbar, footer, sidebar)
│   │   └── features/      ← Feature-specific components
│   ├── hooks/             ← Custom React hooks
│   ├── lib/               ← Utilities, configs, constants
│   ├── types/             ← TypeScript type definitions
│   └── styles/            ← Global styles, theme
├── public/                ← Static assets (images, fonts, downloads)
└── tests/
```

**Python Backend (FastAPI / Flask):**
```
backend/
├── app/
│   ├── main.py            ← App entry point
│   ├── config.py          ← Settings (Pydantic BaseSettings)
│   ├── auth.py            ← Authentication middleware
│   ├── api/               ← Route handlers (grouped by feature)
│   ├── models/            ← Database models (SQLAlchemy / Pydantic)
│   ├── schemas/           ← Request/response schemas
│   ├── services/          ← Business logic (AI, email, PDF gen, etc.)
│   └── utils/             ← Helpers, formatters
├── tests/
├── Dockerfile
└── requirements.txt
```

**Mobile App — Cross-Platform (React Native / Flutter):**
```
mobile/
├── src/
│   ├── screens/           ← Screen components (Home, Profile, Settings)
│   ├── components/        ← Reusable UI components
│   │   ├── ui/            ← Base components (buttons, inputs, cards)
│   │   └── features/      ← Feature-specific components
│   ├── navigation/        ← Navigation stack, tab config, deep linking
│   ├── services/          ← API clients, storage, push notifications
│   ├── hooks/             ← Custom hooks
│   ├── lib/               ← Utilities, constants, helpers
│   ├── types/             ← TypeScript type definitions
│   ├── store/             ← State management (Redux, Zustand, Context)
│   └── assets/            ← Images, fonts, icons (bundled)
├── android/               ← Native Android config
├── ios/                   ← Native iOS config
├── tests/
└── app.json               ← App config (name, version, permissions)
```

**Android Native (Kotlin / Java):**
```
app/
├── src/
│   ├── main/
│   │   ├── java/com/example/    ← Source code (activities, fragments, viewmodels)
│   │   │   ├── ui/              ← Screens, adapters, custom views
│   │   │   ├── data/            ← Repositories, models, database (Room)
│   │   │   ├── network/         ← API clients (Retrofit), DTOs
│   │   │   ├── di/              ← Dependency injection (Hilt/Dagger)
│   │   │   └── utils/           ← Helpers, extensions, constants
│   │   ├── res/                 ← Resources (layouts, drawables, strings, themes)
│   │   └── AndroidManifest.xml  ← Permissions, activities, services
│   ├── test/                    ← Unit tests
│   └── androidTest/             ← Instrumented tests
├── build.gradle.kts             ← App-level build config
└── gradle/                      ← Gradle wrapper
```

**iOS Native (Swift / SwiftUI):**
```
App/
├── Sources/
│   ├── App/                     ← App entry point, app delegate
│   ├── Views/                   ← SwiftUI views / UIKit view controllers
│   ├── ViewModels/              ← View models (MVVM)
│   ├── Models/                  ← Data models, Codable structs
│   ├── Services/                ← API clients (URLSession/Alamofire), storage
│   ├── Navigation/              ← Coordinators, router
│   └── Utils/                   ← Extensions, helpers, constants
├── Resources/                   ← Assets.xcassets, Localizable.strings, Info.plist
├── Tests/                       ← Unit tests (XCTest)
├── UITests/                     ← UI tests
└── App.xcodeproj                ← Xcode project config
```

**Full Stack:**
```
├── frontend/              ← Web app (Next.js)
├── backend/               ← API server (FastAPI)
├── shared/                ← Shared types, constants between frontend/backend
└── scripts/               ← Build scripts, deployment scripts, data migrations
```

**Full Stack + Mobile:**
```
├── frontend/              ← Web app
├── mobile/                ← Mobile app (React Native / Flutter)
├── backend/               ← API server
├── shared/                ← Shared types, constants across all clients
└── scripts/               ← Build scripts, deployment scripts
```

**Document / Research Project (no code):**
```
├── plan/                  ← Main deliverables (HTML, Word, PDF)
├── research/              ← Working data, analysis (not user-facing)
└── templates/             ← Document templates, email drafts
```

### Directory Purposes

| Directory | Purpose | In .gitignore? |
|-----------|---------|:-:|
| `input/` | User drops files here for processing (job posts, project docs, templates, reference CVs) | No (may contain important refs) |
| `output/` | Generated files (PDFs, reports, exports, build artifacts) | Selective (commit finals, ignore temp) |
| `cache/` | Temporary files (AI response cache, build cache, scraped data, downloaded assets) | **Yes** |
| `ard/` | Architecture docs — HTML source + generated PDFs | No |
| `tests/` | All test files — unit, integration, e2e | No |
| `docs/` | Additional docs — API reference, user guides, diagrams | No |
| `scripts/` | Build scripts, deploy scripts, data migration scripts | No |
| `shared/` | Code shared between frontend/backend (types, constants) | No |
| `research/` | Research data, analysis, web scraping results, competitor analysis (working files, not user-facing) | Selective |
| `logs/` | Application logs, debug logs, error logs, cron job logs | **Yes** |
| `config/` | Configuration files — Docker, docker-compose, nginx, CI/CD workflows, linter configs | No |
| `assets/` | Static assets — images, fonts, icons, media files, design files | No |

### File Purposes

| File | Purpose | When Updated |
|------|---------|:---:|
| `agent/AGENT.md` | Project-specific AI instructions — stack, tools, project rules | Setup, when stack/config changes |
| `agent/AGENT_CONTEXT.md` | Living state — what's done, what's next, key decisions, blockers | **Every session + after every implementation** |
| `agent/SPECS.md` | Requirements, features, acceptance criteria | Before dev + **when scope changes** |
| `agent/PLANS.md` | Architecture, tech decisions, data model, phases, methodology & research | Before dev + **when architecture evolves** |
| `agent/TASKS.md` | Task board — `[ ]` todo, `[x]` done | **Before and after every task** |
| `agent/RELEASES.md` | Version changelog, deployments, test results | End of version release |
| `ard/` | Generated docs — technical overview (HTML+PDF), presentation (HTML+PDF) | End of each version release |

### README.md Template

Create this on project setup. Update as the project evolves.

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

### Development Flow

```
SPECS.md (define)  →  PLANS.md (architect)  →  TASKS.md (execute)  →  RELEASES.md (record)
   What to build        How to build it           Track progress          Log what happened
```

### Agent Guidance Behavior

The agent is a **helpful guide, not a strict enforcer**. Follow these principles:

**Don't block the user.** The user can start anywhere — jump into coding, give direct tasks, ask questions, or follow the full spec-persistent flow. All valid. The agent adapts to how the user wants to work, not the other way around. Track everything in the background regardless.

**Guide when asked.** If the user asks "what should I do next?" or "how should I approach this?" — walk them through the spec-persistent process:
1. "Let's start by defining what you want in SPECS.md — what are the key features?"
2. "Now let's plan the architecture in PLANS.md — what stack do you want?"
3. "I'll break this into tasks in TASKS.md — here's the module breakdown"
4. "I'll track everything as we go and log it in RELEASES.md at the end"

**Always mention project name when reporting.** When confirming tasks, status, or actions — always include which project it applies to (e.g. "Noted in **ProjectName** agent/TASKS.md").

**Always track silently.** Even if the user doesn't follow the process:
- User says "build me X" → add to TASKS.md, then build it
- User says "fix this bug" → add to TASKS.md, fix it, mark done
- User says "what's the status?" → show from TASKS.md and AGENT_CONTEXT.md
- User comes back after weeks → read AGENT_CONTEXT.md, summarize where they left off
- User says "keep noted" or "note this" → add to the appropriate agent/ file (TASKS.md for future work, PLANS.md for decisions, AGENT_CONTEXT.md for current state) — never to external memory systems

**Fill gaps proactively.** Don't wait for the user to ask — detect and fill:
- SPECS.md empty after 3+ tasks completed → retroactively fill from what's been built
- SPECS.md has fewer features than TASKS.md has completed `[x]` tasks → SPECS.md is stale, update it (non-empty ≠ current)
- PLANS.md empty after stack is chosen → document the architecture that emerged from the code
- TASKS.md has completed tasks not in SPECS.md → add the features to SPECS.md
- All tasks under a version heading in TASKS.md are `[x]` done → add release entry to RELEASES.md now
- Architecture changed during development → update PLANS.md to match reality
- Keep all 4 pipeline files (SPECS → PLANS → TASKS → RELEASES) in sync without burdening the user

**Surface the process naturally:**
- "I've added this to TASKS.md" (shows you're tracking)
- "Updating AGENT_CONTEXT.md so we can pick up here next time" (shows context persistence)
- "Based on SPECS.md, we still have these features pending" (shows spec-persistent awareness)
- "PLANS.md shows we planned X — should I update it?" (shows plan awareness)

**The user's time is sacred.** Agent does 90% of the work. User reviews 10%. Never ask the user to write specs/plans/tasks — the agent writes them, user approves or adjusts.

### Agent File Templates

Use these exact templates when creating `agent/` files. Replace `<Project Name>` with actual name.

**agent/AGENT.md:**
```markdown
# AGENT.md — <Project Name>

> **Purpose:** Project-specific AI instructions — stack, rules, brand, key decisions.
> **Role:** Read at start of every session. Rarely changes after setup.

## Project Location
`<path>`

## On Every Session Start:
1. Read user profile from `.portable-spec-kit/user-profile/` — user preferences (adapt behavior)
2. Read `agent/AGENT_CONTEXT.md` — project state
3. Read `agent/TASKS.md` — current tasks
4. Read `agent/PLANS.md` — architecture

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

**agent/SPECS.md:**
```markdown
# SPECS.md — <Project Name>

> **Purpose:** What to build — requirements, features, acceptance criteria.
> **Role:** Defined before dev, refined during development.

## Overview
Brief description of what this project does and who it's for.

## Requirements
- Requirement 1
- Requirement 2

## Features
| # | Feature | Req | Priority | Status | Tests |
|---|---------|-----|----------|--------|-------|
| F1 | | R1 | High | [ ] | — |
| F2 | | R2 | Medium | [x] | tests/feature.test.js |

<!-- Tests column: leave — when pending. Add test file path when done: tests/auth.test.js or tests/auth.test.js::login_flow -->

## Scope
- **In scope:**
- **Out of scope (future):**

## Feature Acceptance Criteria

### F1 — Feature Name
- [ ] Criterion 1 (what a passing state looks like)
- [ ] Criterion 2
- [ ] Edge case: what happens when X is empty

### F2 — Another Feature
- [ ] Criterion 1
```

**agent/PLANS.md:**
```markdown
# PLANS.md — <Project Name>

> **Purpose:** How to build it — architecture, phases, data model, tech decisions, methodology & research.
> **Role:** Defined before dev starts. Updated when architecture changes or new research informs decisions.

## Stack
| Layer | Technology | Why |
|-------|-----------|-----|
| | | |

## Architecture
High-level system design.

## Directory Structure
\`\`\`
src/
├── ...
\`\`\`

## Data Model
| Table/Type | Key Fields |
|------------|-----------|
| | |

## API Endpoints
| Method | Path | Description |
|--------|------|-------------|
| | | |

## Security
- Key security considerations for this project

## Build Phases
### Phase 1: Foundation
1. Task 1
2. Task 2

### Phase 2: Features
1. Task 1
2. Task 2

## Methodology & Research
### Approaches Evaluated
<!-- What options were considered and why -->

### Decision Log
| Decision | Options Considered | Chosen | Why | Evidence |
|----------|-------------------|--------|-----|----------|
| | | | | |

### Research Notes
<!-- Key findings, benchmarks, comparisons. Detailed research files go in research/ directory -->

### References
<!-- Papers, articles, docs, benchmarks that informed decisions -->

## Verification
- How to test the system end-to-end
```

**agent/TASKS.md:**
```markdown
# TASKS.md — <Project Name>

> **Purpose:** Task tracking — organized by release version.
> **Role:** Updated during development. Add tasks FIRST, then work.

## v0.1 — Current
- [x] Project setup
- [ ] Task 1
- [ ] Task 2

### Blocked
<!-- Tasks waiting on external dependencies -->

## Backlog (Future Releases)
- [ ] Future feature 1
- [ ] Future feature 2

## Progress Summary
| Version | Tasks Done | Tests | Status |
|---------|:----------:|:-----:|--------|
| v0.1 | 1 | 0 | In Progress |
```

**agent/RELEASES.md:**
```markdown
# RELEASES.md — <Project Name>

> **Purpose:** Version history — changelog, deployments, test results.
> **Role:** Updated at end of each release version.

## v0.1 — Title (Date)
Kit: vX.X.X

### Summary
Brief description of what this version delivers.

### Changes
- **Frontend:** ...
- **Backend:** ...
- **AI:** ...
- **Infrastructure:** ...

### Tests
- X tests passing, Y% coverage

### Deployment
- Deployed to: URL
- Date: YYYY-MM-DD

### Known Issues
<!-- Any known issues in this version -->
```

**tests/test-release-check.sh:**
```bash
#!/bin/bash
# =============================================================
# release-check.sh — Pre-Release R→F→T Validation
#
# Reads SPECS.md → for every done feature (Fn marked [x]):
#   1. Checks a test reference exists in the Tests column
#   2. Checks the referenced test file exists on disk
#   3. Attempts to run the tests (auto-detects runner)
#   4. Reports: feature → test coverage + pass/fail
#
# Usage:
#   bash tests/test-release-check.sh                  # uses agent/SPECS.md
#   bash tests/test-release-check.sh path/to/SPECS.md # custom path
#
# Exit codes:
#   0 = all done features have passing tests (release ready)
#   1 = missing test refs, missing files, or test failures
# =============================================================

SPECS="${1:-agent/SPECS.md}"

if [ ! -f "$SPECS" ]; then
  echo "Error: SPECS.md not found at $SPECS"
  echo "Usage: bash tests/test-release-check.sh [path/to/SPECS.md]"
  exit 1
fi

TOTAL_DONE=0
REF_PRESENT=0
FILE_EXISTS=0
TESTS_PASSED=0
MISSING_REFS=0
MISSING_FILES=0
TESTS_FAILED=0

# Cache: each unique test file is run only once — result reused for all features referencing it
TEST_CACHE_FILE=$(mktemp)
trap "rm -f $TEST_CACHE_FILE" EXIT

detect_runner() {
  local test_file="$1"
  if [ -f "package.json" ] && grep -q "jest\|vitest" "package.json" 2>/dev/null; then
    echo "jest"
  elif [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -f "setup.cfg" ]; then
    echo "pytest"
  elif [ -f "go.mod" ]; then
    echo "go"
  elif echo "$test_file" | grep -q "\.sh$"; then
    echo "bash"
  elif echo "$test_file" | grep -q "\.py$"; then
    echo "python"
  elif echo "$test_file" | grep -q "\.test\.js$\|\.spec\.js$\|\.test\.ts$\|\.spec\.ts$"; then
    echo "jest"
  else
    echo "unknown"
  fi
}

run_test() {
  local test_ref="$1"

  # Return cached result if this file was already run
  local cached
  cached=$(grep "^${test_ref}:" "$TEST_CACHE_FILE" 2>/dev/null | tail -1 | cut -d: -f2)
  if [ -n "$cached" ]; then return "$cached"; fi

  local runner result
  runner=$(detect_runner "$test_ref")

  case "$runner" in
    jest)
      if command -v npx >/dev/null 2>&1; then
        npx jest "$test_ref" --passWithNoTests 2>/dev/null && result=0 || result=1
      else result=2; fi ;;
    pytest)
      if command -v pytest >/dev/null 2>&1; then
        pytest "$test_ref" -q 2>/dev/null && result=0 || result=1
      elif command -v python3 >/dev/null 2>&1; then
        python3 -m pytest "$test_ref" -q 2>/dev/null && result=0 || result=1
      else result=2; fi ;;
    go)
      if command -v go >/dev/null 2>&1; then
        go test "./$test_ref/..." 2>/dev/null && result=0 || result=1
      else result=2; fi ;;
    bash)
      bash "$test_ref" >/dev/null 2>&1 && result=0 || result=1 ;;
    python)
      python3 "$test_ref" 2>/dev/null && result=0 || result=1 ;;
    *)
      result=2 ;;
  esac

  echo "${test_ref}:${result}" >> "$TEST_CACHE_FILE"
  return $result
}

check_stub_complete() {
  local test_ref="$1"
  local todo_count
  # Match standalone TODO comments and skip/placeholder assertions at line start
  # All patterns anchored to avoid false positives inside grep pattern strings
  todo_count=$(grep -cE "^[[:space:]]*(#[[:space:]]*TODO|//[[:space:]]*TODO|test\.skip\(|it\.skip\(|xit\(|xtest\(|expect\(true\)\.toBe\(false\)|assert False|t\.Skip\()" "$test_ref" 2>/dev/null || echo 0)
  if [ "$todo_count" -gt 0 ]; then
    echo "${test_ref}:stubs_incomplete:${todo_count}" >> "$TEST_CACHE_FILE"
    return 1
  fi
  return 0
}

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  RELEASE READINESS — R→F→T Coverage Check"
echo "  Specs: $SPECS"
echo "════════════════════════════════════════════════════════════"
echo ""
printf "  %-5s %-32s %-8s %s\n" "Fn" "Feature" "Status" "Tests"
printf "  %-5s %-32s %-8s %s\n" "-----" "--------------------------------" "--------" "-------"

while IFS= read -r line; do
  if echo "$line" | grep -q "^| F[0-9]" && echo "$line" | grep -q "\[x\]"; then
    fn=$(echo "$line" | awk -F'|' '{gsub(/ /,"",$2); print $2}')
    feature=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}' | cut -c1-30)
    test_ref=$(echo "$line" | awk -F'|' '{
      for (i=NF; i>1; i--) {
        gsub(/^ +| +$/, "", $i)
        if ($i !~ / / && length($i) > 0 && ($i ~ /^tests\// || $i ~ /\.test\.|\.spec\.|\.sh$|\.py$|\.ts$|\.js$/)) {
          print $i; exit
        }
      }
    }')
    TOTAL_DONE=$((TOTAL_DONE + 1))
    if [ -z "$test_ref" ]; then
      printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "⚠  NO TEST REFERENCE"
      MISSING_REFS=$((MISSING_REFS + 1))
    elif [ ! -f "$test_ref" ] && [ ! -d "$test_ref" ]; then
      printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "✗  FILE NOT FOUND: $test_ref"
      REF_PRESENT=$((REF_PRESENT + 1))
      MISSING_FILES=$((MISSING_FILES + 1))
    else
      REF_PRESENT=$((REF_PRESENT + 1))
      FILE_EXISTS=$((FILE_EXISTS + 1))
      if ! check_stub_complete "$test_ref"; then
        stub_count=$(grep "^${test_ref}:stubs_incomplete:" "$TEST_CACHE_FILE" | cut -d: -f3)
        printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "✗  STUBS NOT FILLED ($stub_count TODO markers): $test_ref"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        continue
      fi
      run_test "$test_ref"; run_result=$?
      if [ "$run_result" -eq 0 ]; then
        printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "✓  $test_ref"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      elif [ "$run_result" -eq 2 ]; then
        printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "~  $test_ref (exists, run manually)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "✗  FAILED: $test_ref"
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi
    fi
  fi
done < "$SPECS"

echo ""
echo "────────────────────────────────────────────────────────────"
printf "  Features complete:       %d\n" "$TOTAL_DONE"
printf "  With test references:    %d / %d\n" "$REF_PRESENT" "$TOTAL_DONE"
printf "  Test files found:        %d / %d\n" "$FILE_EXISTS" "$TOTAL_DONE"
printf "  Tests passing:           %d\n" "$TESTS_PASSED"
printf "  Tests failing:           %d\n" "$TESTS_FAILED"
printf "  Missing test refs:       %d\n" "$MISSING_REFS"
printf "  Missing test files:      %d\n" "$MISSING_FILES"
echo "────────────────────────────────────────────────────────────"
ISSUES=$((MISSING_REFS + MISSING_FILES + TESTS_FAILED))
if [ "$TOTAL_DONE" -eq 0 ]; then
  echo "  ⚠  No completed features found in SPECS.md"; echo ""; exit 1
elif [ "$ISSUES" -eq 0 ]; then
  echo "  ✅ RELEASE READY — $TOTAL_DONE features, 100% test coverage"; echo ""; exit 0
else
  COVERAGE=$(( (FILE_EXISTS * 100) / TOTAL_DONE ))
  echo "  ❌ NOT READY — $ISSUES issue(s) found ($COVERAGE% coverage)"
  [ "$MISSING_REFS" -gt 0 ] && echo "     → Add test references in SPECS.md Tests column for $MISSING_REFS feature(s)"
  [ "$MISSING_FILES" -gt 0 ] && echo "     → Create missing test files for $MISSING_FILES reference(s)"
  [ "$TESTS_FAILED" -gt 0 ]  && echo "     → Fix $TESTS_FAILED failing test(s) before release"
  echo ""; exit 1
fi
```

### New Project Setup Procedure

When user asks to create a new project, follow these steps IN ORDER:

**Step 1: Create Directory Structure + All Agent Files (DO THIS IMMEDIATELY — no questions)**
```bash
mkdir -p <project>/{agent,ard,input,output,cache,src,tests,docs}
```
Create all 6 agent files using the templates above.
- `tests/test-release-check.sh` — R→F→T validation script (use template above), then `chmod +x tests/test-release-check.sh`
- `README.md` — project overview (see README template below)
- `.gitignore` — general ignores (node_modules, .env, cache/, __pycache__, .next, etc.)
- `.env.example` — empty placeholder

**Step 2: First Commit (only if user has said "commit" or "initialize git")**
- Stage all files
- Commit with message: "Initialize <project-name> — v0.1 setup"
- Do NOT push (wait for user to say "push")
- If user has not mentioned committing → skip this step, show files created and wait

**Step 3: Report to User**
- Show: directory structure created, files list
- Do NOT ask questions — user will start specs discussion when ready

**Then (when user is ready):**

**Step 4:** Specs discussion → write `agent/SPECS.md`. For each feature, add acceptance criteria under `## Feature Acceptance Criteria / ### F{n} — Feature Name`. Agent generates test stubs immediately for any forward-flow feature that has criteria written (see Spec-Based Test Generation rules).

**Step 5:** Recommend tech stack → user approves

**Step 6:** Write `agent/PLANS.md` — architecture, phases. Deployment deferred to release time.

**Step 7:** Initialize stack — install deps, update `.gitignore`, assign dev server port automatically

**Step 7.5:** Create GitHub Actions CI workflow — generate `.github/workflows/ci.yml` using the CI template (see CI & Community Contributions section). Detect test command from stack. Add CI badge to README.md as first badge. Tell user: "CI will run on every push and PR. Enable branch protection in GitHub Settings → Branches to require CI checks before merge."

**Step 8:** Start development — update `agent/TASKS.md`, begin building

