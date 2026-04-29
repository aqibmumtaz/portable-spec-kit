# Portable Spec Kit — Spec-Persistent Development for AI-Assisted Engineering
<!-- Framework Version: v0.6.15 -->

**Version:** v0.6.15 · **License:** MIT · **Author:** Dr. Aqib Mumtaz
**GitHub:** https://github.com/aqibmumtaz/portable-spec-kit · **Tests:** 1747 (1602 framework · 145 benchmarking)

> A lightweight, zero-install, personalized framework for AI-assisted engineering. Drop one file into any project — your AI agent personalizes to you, maintains living specifications, and preserves context across sessions. Specs always exist. Always current. Never block.
>
> **For full documentation, setup instructions, and examples — see [README.md](README.md).**

---

> **Purpose:** The single source of truth for how the user works — dev practices, coding standards, testing rules, project setup procedures, and AI interaction guidelines. Read this FIRST on every session.
>
> **Role:** Portable across all projects. Drop this file into any repo and the AI agent follows these standards immediately. Project-specific rules go in `agent/AGENT.md`. Workspace state goes in `WORKSPACE_CONTEXT.md` (auto-created on first session).

---

## Bootstrap-first rule (MANDATORY on any new project)

**Before doing ANY work in a project — before creating `agent/` files, before running `prepare release`, before invoking reflex — verify the kit is installed by running:**

```bash
bash agent/scripts/psk-bootstrap-check.sh --quiet || bash <path-to-kit>/install.sh --yes --from <path-to-kit>
```

**If the user asks an agent (Copilot, Claude, Cursor, etc.) to "set up a new project with requirements X" and follow up with "prepare release" or "run reflex":** the agent MUST install the kit FIRST as the very first step. The kit's machinery (scripts, hooks, skills, config) only works if `install.sh` has been run. Running `install.sh` is idempotent — safe on fresh and partially-installed projects.

**Why this rule exists:** without install, `agent/scripts/` is empty, `.git/hooks/pre-commit` is missing, skills are not cached, `.portable-spec-kit/config.md` does not exist. Prep-release + reflex will fail-fast with a bootstrap error at Step 0 / Gate 0a, but that wastes a round-trip — install first, build second.

**Canonical install commands:**
```bash
# Option 1 — from a local kit checkout (recommended for dev):
bash <kit-path>/install.sh --yes --from <kit-path>

# Option 2 — one-shot network install (no local kit):
curl -fsSL https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/install.sh | bash

# Option 3 — auto-remediation if bootstrap check exists:
bash agent/scripts/psk-bootstrap-check.sh --remediate
```

**After install completes:** `CLAUDE.md` / `.cursorrules` / `.windsurfrules` / `.clinerules` / `.github/copilot-instructions.md` all symlink to `portable-spec-kit.md`. Every AI agent that reads those entry-points sees the kit's rules immediately.

---

## Reliability Architecture

The kit uses three enforcement layers to prevent agents from skipping steps or shipping inconsistent content. The agent cannot bypass these — they are structural, not trust-based.

**Reliability model — dual critic at the end of each workflow, not per step.** A workflow runs its steps normally; at the end it enters a single validation gate that pairs two critics. Both must pass. Either failure blocks the workflow from completing.

**Layer 2A — Bash Critic (`psk-sync-check.sh`) — deterministic, always on:** Runs 11 structural checks (version, test count, flow doc count, feature count, SPECS staleness, R→F→T gate, script permissions, required directories, CHANGELOG/RELEASES content, ARD content, AGENT.md stack). Returns exit 0 (clean) or exit 1 with specific file:line mismatches and PSK error codes. Fires during workflow steps and again at the final validation gate.

**Layer 2B — Sub-Agent Critic (`psk-critic-spawn.sh`) — semantic, at workflow end:** At the final validation gate, the workflow script writes `agent/.release-state/critic-task.md` and exits AWAITING_CRITIC. The agent spawns a fresh sub-agent via Task tool with that exact prompt — no inherited context from the main session. The sub-agent reads files independently and writes `critic-result.md` with `CURRENT:` / `STALE:` verdicts. The script verifies the result file is fresh (mtime ≥ RUN_ID) and contains no `STALE:` lines before marking the gate passed. Iteration cap: 5 attempts. The `critic-result.md` from prior workflow runs is deleted automatically at `prepare` so stale reports cannot satisfy a new run.

**Layer 3 — Hooks (outside agent control):** PostToolUse hook runs `psk-sync-check.sh --quick` after every Write/Edit (silent on clean, warns on drift). PreCommit hook runs `psk-sync-check.sh --full` and BLOCKS bad commits. Agent physically cannot bypass — hooks fire automatically.

**Critic protocol rule (MANDATORY):** When any workflow's final validation step exits with AWAITING_CRITIC, the agent MUST read `critic-task.md`, spawn a sub-agent via Task tool with that exact prompt, write the sub-agent's response to `critic-result.md`, then re-run the workflow `next` command. The gate re-reads the result file, verifies freshness and content, and advances only on a clean result.

**Workflow coverage — dual gate at end of every executable workflow:** All six executable workflows terminate in the same dual-gate validation step via the shared `agent/scripts/psk-validate.sh <workflow>` helper. Workflows covered: `release` · `feature-complete` · `init` · `reinit` · `new-setup` · `existing-setup`. Each maps to a dedicated critic template (`STEP_9_VALIDATION`, `FEATURE_COMPLETE`, `INIT`, `REINIT`, `NEW_SETUP`, `EXISTING_SETUP`) inside `psk-critic-spawn.sh`. Agent MUST run the helper at the end of any workflow that modifies `agent/*` or project scaffold — no workflow marks complete until both critics pass.

**MANDATORY rule — agent behavior:** When ending any executable workflow (release, feature completion, init, reinit, new/existing project setup), agent runs `bash agent/scripts/psk-validate.sh <workflow>`. Exit 0 = workflow complete. Exit 2 = `AWAITING_CRITIC` — agent reads `agent/.release-state/critic-task.md`, spawns fresh sub-agent via Task tool with that exact prompt, writes sub-agent response to `agent/.release-state/critic-result.md`, re-runs validate. Exit 1 or 3 = a critic failed; fix flagged issues and re-run.

**Emergency bypass:** `PSK_SYNC_CHECK_DISABLED=1` bypasses the bash critic; `PSK_CRITIC_DISABLED=1` bypasses the sub-agent critic; `git commit --no-verify` bypasses the PreCommit hook. All three are for genuine emergencies only — each breaks a gate and should be explicit.

> **Skill: Hooks & Critics** — Full protocol, error codes, customization in `.portable-spec-kit/skills/hooks-and-critics.md`. Loaded when interacting with reliability infrastructure.

---

## Skill-Based Architecture

This file is the **core brain** — behavioral rules loaded every session. Procedural details live in **skill files** loaded on demand:

| Trigger | Skill file loaded |
|---------|------------------|
| Creating/restructuring agent files | `.portable-spec-kit/skills/templates.md` |
| Python project detected (Python-only legacy) | `.portable-spec-kit/skills/python-environment.md` |
| **Any stack-runtime command when env not yet selected** (pip / npm / pytest / cargo / go test / etc.) — generic Python · Node · Ruby · Go · Rust | `.portable-spec-kit/skills/env-management.md` |
| Project setup (init) / auto-scan / existing project | `.portable-spec-kit/skills/project-setup.md` |
| Source code structures by project type | `.portable-spec-kit/skills/source-structures.md` |
| First session (no profile) | `.portable-spec-kit/skills/profile-setup.md` |
| First session (tour) / presence / onboarding | `.portable-spec-kit/skills/onboarding-tour.md` |
| Release / generating docs | `.portable-spec-kit/skills/document-generation.md` |
| New project (test script) | `.portable-spec-kit/skills/test-release-check-template.md` |
| Reliability / hooks / critics | `.portable-spec-kit/skills/hooks-and-critics.md` |
| Progress / dashboard / burndown | `.portable-spec-kit/skills/dashboard.md` |
| My tasks / assign / delegate | `.portable-spec-kit/skills/multi-agent.md` |
| Jira / time tracking | `.portable-spec-kit/skills/jira-integration.md` |
| Help / commands / guidance | `.portable-spec-kit/skills/self-help.md` |
| Enable CI / CI setup | `.portable-spec-kit/skills/ci-setup.md` |
| Config contract / commands / edge cases | `.portable-spec-kit/skills/config-details.md` |
| Losing context / "where was I" / branching / conversation-stack | `.portable-spec-kit/skills/session-trace.md` |
| Integration tests / end-to-end tests / FastAPI tests / subprocess fixtures / live-server | `.portable-spec-kit/skills/test-templates.md` |
| **"Create a project for X" / "build me an app" / "make it a full working project" / "generate the app from these requirements"** | `.portable-spec-kit/skills/project-orchestration.md` (full 10-phase pipeline — research → expand REQS → SPECS+PLANS → UI design system → secure scaffold → feature impl → release-prep → reflex audit → handoff) |
| Domain research + REQS expansion (loose req → R1-R30+) | `.portable-spec-kit/skills/requirement-research.md` |
| Polished UI design system (palette, type scale, 12 component primitives, dark mode, a11y) | `.portable-spec-kit/skills/ui-design-system.md` |
| Security baseline (OWASP Top 10, auth scaffolding, middleware stack, input validation) | `.portable-spec-kit/skills/security-baseline.md` |
| **`/optimize` · `psk optimize` · `optimize tokens` · `clean up bloat`** — token-bloat sweep with safety contract (no rule loss) | `.portable-spec-kit/skills/optimize.md` |

Skills are downloaded from GitHub on first use, cached in `.portable-spec-kit/skills/`. Install is unchanged (one curl command).

### Project orchestration (v0.6.14+ — natural-language preferred)

When the user provides any actual requirement (formal or informal, single sentence or paragraph), the kit's project-orchestration skill drives a full 10-phase pipeline that turns loose requirements into a polished, secure, working, audited application.

**Trigger phrases (any of these):** *"create a project for X"* · *"build me an app that does Y"* · *"make this a full working project"* · *"generate the app from these requirements"* · *"make it polished / professional / production-ready / secure / research-based"*

**Behind the scenes:** the agent invokes `bash agent/scripts/psk-orchestrate.sh "<raw req>"`. The orchestrator chains 10 phases: capture → 7-dim research → expand REQS → SPECS+PLANS → UI design system → secure scaffold → feature implementation (one feature per atomic commit) → release ceremony → reflex audit (until convergence) → final handoff with `HANDOFF.md`. Each phase has a confirm-with-user gate where the user can redirect.

**Output:** a working app with secure backend, polished frontend (design tokens, 12+ components, WCAG AA, dark mode), input validation at every boundary, auth scaffolding (Argon2id + JWT + email verify + reset), CI workflow, R→F→T traceability, reflex GRANTED audit verdict, and `HANDOFF.md` with run instructions. **The user does not have to QA the result manually — reflex did that.**

**Full flow doc:** [`docs/work-flows/18-project-orchestration.md`](docs/work-flows/18-project-orchestration.md).

**Scaffold-only fallback:** if the user prefers the lightweight legacy flow (just create empty `agent/` files, no generation), they say *"just scaffold"* / *"empty setup"* / *"don't generate code"* — the kit falls back to `project-setup.md`'s scaffold-only branch.

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

**NEVER edit symlink files directly** (`CLAUDE.md`, `.cursorrules`, `.windsurfrules`, `.clinerules`, `.github/copilot-instructions.md`). Always edit `portable-spec-kit.md` — the symlinks are read-only pointers.

### Rule Persistence (MANDATORY — agent files only)

Everything the agent persists across sessions goes to a committed `agent/*` file. Personal auto-memory is not used. If it's worth remembering, it's worth committing.

**Detect context first** (one check, by file type):

| `portable-spec-kit.md` is a... | Context | Permission |
|---|---|---|
| Regular file | **Kit-dev** (kit author in canonical kit checkout) | May edit `portable-spec-kit.md` |
| Symlink (`ls -la` shows `→`) | **End-user** (project that installed the kit) | `portable-spec-kit.md` is **read-only** |

**Write destination by context:**

| Context | Rule / convention / config | State / observation / anything else |
|---|---|---|
| **End-user** (default — most sessions) | `agent/AGENT.md` | `agent/AGENT_CONTEXT.md` |
| **Kit-dev** (kit author only) | `portable-spec-kit.md` + ADR + CHANGELOG + RELEASES | kit's own `agent/AGENT_CONTEXT.md` |

End-user surface is **exactly those two files** — nothing else, ever. Default to `agent/AGENT_CONTEXT.md` when unclear (state is more inclusive than rules).

**No personal memory at all.** The agent's per-user auto-memory (whatever store the host agent uses) is per-user, per-machine, per-agent, not committed — invisible to other contributors / machines / other AI agents, prunable by the runtime, no git audit trail. Earlier versions of this rule allowed "ephemeral / sparingly" memory use; that exemption leaked and was removed.

**Migration of existing memory entries:** classify → move kit-wide rules to `portable-spec-kit.md` (kit-dev only) or project entries to `agent/AGENT.md` / `agent/AGENT_CONTEXT.md` → delete memory entry once the move is committed.

**Read-only contract:** the existing "version field is kit-author-only" rule extends to the entire `portable-spec-kit.md` file. End-user projects never edit the symlinked kit copy.

**Framework writing principles:**
- **Generic, not version-specific.** Rules must work across all framework versions. Never hardcode file counts, feature counts, test counts, or version numbers in behavioral rules. Use dynamic references ("all pipeline files" not "9 files"). Specific counts belong only in badges, documentation headers, and summary tables that are updated during consistency sweep.
- **No duplicate instructions.** Every rule has ONE authoritative location. If the same topic is covered in multiple places, consolidate. Cross-reference with "see Section X" instead of repeating.
- **Self-validating.** The system validation step catches remaining gaps as a safety net — the user should never have to find issues manually.
- **Learn from mistakes.** When the agent skips a step or misses a gap, don't just fix it — add enforcement so it can't happen again. If a rule exists but was skipped, the fix is enforcement (script, test, or gate), not another rule.
- **Rule-revision post-mortem (learning-from-churn).** If any framework rule is revised ≥3 times in a single session, the agent MUST record an ADL entry in `agent/PLANS.md` (in the kit repo) titled `ADL-YYYY-MM-DD — rule-churn: <rule-name>`. The entry captures: (a) the three (or more) variants the rule cycled through, (b) the signal that each prior variant was wrong, (c) the final landed variant, and (d) the root cause of the churn (unclear requirement, missing user context, over-generalization, etc.). Churn is a signal that either the rule's scope is fuzzy or a deeper design assumption is wrong — ignoring it hides the lesson. This meta-rule applies only to kit-framework changes, not to user project work.

On first session, the agent also auto-creates:
- `WORKSPACE_CONTEXT.md` — workspace environment and project listing
- `agent/` directory in each project — with all pipeline and support files as defined by the current framework version
- `README.md` — structured project overview

**If the user asks any question about the kit — installation, features, setup, examples, changelog, methodology, or how anything works:**

**Three help layers (checked in order, all must agree):**
1. **Local framework** (this file) — primary source. Agent reads the current `portable-spec-kit.md` for rules, commands, processes. Always up to date because it's the file the agent is reading.
2. **Local project files** — `README.md`, `CHANGELOG.md`, `agent/SPECS.md`, `.portable-spec-kit/config.md` — current project state, features, config. Always up to date because they're local.
3. **GitHub repo** (fallback for install/update questions) — fetch from `https://github.com/aqibmumtaz/portable-spec-kit` only for questions about installation, updates, or examples that need the published version.

**Source priority:** Local files first. GitHub repo only when the user asks about installing, updating, or comparing against the published version. Never fetch from GitHub to answer "how do I release?" — that answer is in the local framework file.

**Repo:** https://github.com/aqibmumtaz/portable-spec-kit
**Raw base URL:** `https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/`

Known GitHub sources (fetch only when local can't answer):
| Question type | Source to fetch |
|---------------|----------------|
| Install / reinstall / update | `README.md` from repo |
| Examples / starter project | `examples/starter/` or `examples/my-app/` from repo |
| What's the latest published version? | `CHANGELOG.md` from repo |

**Everything else → read from local files.** The agent already has this framework file loaded — no need to fetch from GitHub for "how do I release?" or "what commands can I use?".

**If the question doesn't match a known source, or if new docs may have been added:** scan the repo structure first to discover what files exist, then fetch the most relevant one.

---

## User Profile

> **Purpose:** Tells the AI agent WHO it's working with — expertise level, communication preferences, and autonomy expectations. The agent uses this to tailor response depth, technical language, analogies, and how much it does autonomously vs. asks for confirmation.

### Profile Storage
Profile locations, cross-OS paths, and username detection — see `.portable-spec-kit/skills/profile-setup.md`.

### Profile Lookup Order
1. `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md` → local, per-user, committed
2. `~/.portable-spec-kit/user-profile/user-profile-{username}.md` → global, per-user
3. Neither → first-time setup

### First Session — Profile Setup (no profile found anywhere)
> **Skill: Profile Setup** — First session profile setup, preference questions, new project flow in `.portable-spec-kit/skills/profile-setup.md`. Loaded on first session when no profile found.### Every Session
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
Profile markdown format — see `.portable-spec-kit/skills/profile-setup.md`.

---

## Project Config

> **Purpose:** Project-level configuration for kit behavior — what's enabled, what's disabled, how the kit behaves for this project. Stored in `.portable-spec-kit/config.md`, committed to repo, shared across team.

### Config Storage
```
workspace/.portable-spec-kit/
├── user-profile/          ← Per-user preferences (who)
│   └── user-profile-{username}.md
└── config.md              ← Project config (what's enabled)
```

**One config per project.** Lives alongside user profiles in `.portable-spec-kit/`. Committed to git — team shares the same config. Not in `agent/` (config is kit infrastructure, not project management).

### Config Format & Defaults
Project config template and default values — see `.portable-spec-kit/skills/config-details.md`.

### Config Creation
**Auto-created** on first session if `.portable-spec-kit/config.md` doesn't exist — uses defaults above. No questions asked. User can review and change anytime.

### Config Review (user-triggered)
User says `"show config"` / `"review config"` / `"update config"`:
1. Agent reads `.portable-spec-kit/config.md`
2. Shows current settings in a formatted table
3. Asks: "Change anything? (type setting name, or Enter to keep)"
4. User types setting → agent shows options → user picks → config updated
5. If CI/CD changed to enabled → agent creates `.github/workflows/ci.yml` and adds badge to README
6. If CI/CD changed to disabled → agent removes `.github/workflows/ci.yml` and hides badge in README (HTML comment)

### Config After Profile Setup
After first-session profile setup completes, agent shows config summary:
```
"Project config (defaults applied):
  CI/CD:         disabled (enable: say 'enable ci')
  Jira:          disabled (enable: say 'jira setup')
  Code review:   enabled (auto after features)
  Scope check:   enabled (auto at session start)

  Review anytime: say 'show config'"
```

### Config Gateway Rule (MANDATORY)

**Before executing ANY config-dependent action, the agent MUST:**
1. Read `.portable-spec-kit/config.md`
2. Check the relevant toggle in the Config Contract table below
3. If disabled → follow the "If disabled" column exactly
4. If enabled → proceed normally

This is a **single gateway** — not per-step checks. Every automatic trigger, every pipeline step, every command that touches a configurable feature goes through this gate. No exceptions.

**When adding a new config toggle or a new feature that should be configurable:**
1. Add the toggle to `.portable-spec-kit/config.md` template (with default value)
2. Add ALL actions controlled by this toggle to the Config Contract table (every pipeline, every trigger, every auto-action)
3. Add enable/disable command to Config Commands table
4. In every pipeline step or trigger that uses this feature → reference the Config Gateway Rule explicitly
5. **The toggle takes effect immediately** — agent reads config before every action, not once at startup

**When adding an existing configurable feature to a new pipeline:** Add a new row to Config Contract for that pipeline. The toggle name stays the same — the row just maps it to the new location. This ensures disabling the feature stops it everywhere, including the new pipeline.

**Integrity rule:** If a toggle exists in Config Contract, there must be ZERO places in the framework where that action runs without checking the toggle. To verify: `grep` the framework for the action name — every hit must have a config gate or be a manual command.

> **Config Contract, Commands, and Edge Cases** — see `.portable-spec-kit/skills/config-details.md`. Loaded when config is accessed.

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
- **Pre-push gate** — check if any files were modified since the last `prepare release` completed (use `git diff` against the last release commit):
  - **No changes since last prepare release** → push immediately, no tests needed
  - **Changes exist** → run **Test Execution Flow**. If all pass → warn user: "Changes were made after the last prepare release — flow docs, ARD, version bump, PDFs, RELEASES, CHANGELOG may be out of date. Proceed anyway? (y/n)". User yes → push. Do NOT attempt any release steps — push is not a substitute for prepare release.
- **Push** = `git push` to remote. If the project has a custom sync script (`agent/scripts/sync.sh`), use it instead — it may handle additional tasks like copying files between repos, creating GitHub releases, or updating tags.

### Test Execution Flow (used by all commands that run tests)

Whenever any command triggers a test run (run tests, prepare release, update release, refresh release, push gate), always follow this flow:

1. Run ALL 3 suites to completion — never stop on first failure, collect all results:
   - `bash tests/test-spec-kit.sh`
   - `bash tests/test-spd-benchmarking.sh`
   - `bash tests/test-release-check.sh agent/SPECS.md`
2. If all pass → show pass summary and continue
3. If any failures exist:
   - Show **failure summary**: suite name, test name, error message for each failure
   - Show **fix plan**: one-line diagnosis + proposed fix for each failure
   - Ask user: "X test(s) failed. Fix now? (Enter = yes, or describe changes)"
   - User approves → fix, re-run from step 1
   - User declines → stop. Do not proceed with known failures.

### Release Process (EXPLICIT SIGNALS ONLY)
Never automatically run tests, update counts, bump versions, regenerate PDFs, or commit after every change. The user may have more changes coming. Wait for explicit signals:
- **"run tests"** → run Test Execution Flow. No commits, no version changes.
- **"prepare release"** / **"update release"** → steps 1–10 only (tests → code review → scope check → validation → flows → counts → version bump → PDFs → RELEASES.md → CHANGELOG.md) + show release summary. **No commit. No push.** Changes sit staged for user review.
- **"refresh release"** → same as prepare release but no version bump. **No commit. No push.**
- **"commit"** → commit staged changes
- **"push"** → push to remote (pre-push gate applies)
- **"prepare release and push"** / **"prepare release, commit and push"** → steps 1–10 + commit all release changes + push to remote (via `git push` or project sync script) + show release summary. No confirmation needed between steps — user has given the full instruction.
- **"refresh release and push"** / **"refresh release, commit and push"** → same as above but no version bump.
- **"init"** → scan project thoroughly, create/fill all agent/ files from codebase
- **"reinit"** → re-scan project, sync all agent files to current codebase state

**Release execution:** Agent runs `bash agent/scripts/psk-release.sh prepare` (or `refresh`), then repeats `bash agent/scripts/psk-release.sh next` until all steps complete. Automated steps (tests, code review, scope check, counts, version bump, PDFs) are executed by the script. Agent-required steps (flow docs, releases) pause with instructions — the agent does the work, sub-agent critic verifies, then `bash agent/scripts/psk-release.sh done` to proceed. No step can be skipped. Validation is Step 9 (final gate).

> **Skill: Release Process** — Full prepare/refresh release sequences (10 steps), release summary format, release notes publishing, edge cases, prepare+push flow in `.portable-spec-kit/skills/release-process.md`. Loaded on `prepare release` / `refresh release` / `push` command.

> **Skill: Init/Reinit Process** — Full `init` (10 steps) and `reinit` (9 steps) procedures in `.portable-spec-kit/skills/init-process.md`. Loaded on `init` / `reinit` command.

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
- **Version bump BEFORE push** — always bump → commit → push in that order. Never push then bump after — the remote tag must always point to the version-bumped commit.
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
- Design decisions and architectural plans go in `PLANS.md` — architecture summary, ADL, and stack decisions
- **Feature plans (MANDATORY)** — every feature (F{N}) in SPECS.md gets a plan file in `agent/design/f{N}-feature-name.md`. Small features get a small plan; large features get a large plan. Same template, same location.
  - **Four triggers:**
    - **Explicit** — user says "plan F3" / "plan this feature" / "design F3" → agent creates/opens the plan file
    - **Auto on SPECS.md** — feature added to SPECS.md → agent auto-creates plan stub in `agent/design/`
    - **Implementation gate** — user says "implement F3" / "start F3" → agent checks plan exists. If not → creates + fills first, confirms with user, then implements
    - **Plan-mode → implementation transition (MANDATORY)** — when a plan-mode planning session transitions to implementation (plan mode exits, user says "implement it", or user approves the plan for execution), agent automatically executes the **plan-to-pipeline sync**:
      1. **Save the plan** to `agent/design/f{N}-feature-name.md` (if the plan was in an ephemeral location such as the IDE's local plans directory) — this makes the plan part of the repo history
      2. **Add SPECS.md entry** — new F{N} row in features table with acceptance criteria subsection (`### F{N}` with `- [ ]` items)
      3. **Add TASKS.md entries** — tasks for each implementation phase/milestone under the current or next version heading, assigned per multi-agent rules
      4. **Update AGENT_CONTEXT.md phase** — describe the current phase of work (the new F{N} being built)
      5. **Add PLANS.md ADL entries** — one row per significant decision in the plan's Decisions section, with `Plan Ref` link to the design file
      6. **If requirement-level** — add R{N} to REQS.md if the plan addresses a new client/business requirement not previously recorded
      These six updates happen together, in one commit if possible, so the pipeline is never left partially in sync after a major planning session.
  - **Plan template:** See `.portable-spec-kit/skills/templates.md` for the full 12-section plan template (Context, Approach, Decisions, Data Model, Edge Cases, Commands, Config, Scope Exclusions, Files, Tests, Implementation Order, State).
  - **ADL integration** — decisions in plan `## Decisions` auto-extracted to PLANS.md ADL with `Plan Ref` column. Plan is source of truth for rationale; ADL is index. `agent/design/` holds depth; `agent/PLANS.md` is the summary.
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
- **Architecture Decision Log (ADL)** — add a row to `## Architecture Decision Log` in PLANS.md for every significant technical decision. ADL format, numbering rules, date format, immutability rules, and scope rules — see `.portable-spec-kit/skills/templates.md` (ADL Format Details section).
- **AGENT.md** — update when project config changes:
  - Stack changed → update Stack table
  - Brand colors or fonts changed → update Brand section
  - AI provider or model changed → update AI Config
  - Dev server port changed → update port
- **Sync rule:** When completing a feature, update **all affected pipeline + support files** in the same session. Check each file — if this feature's completion changes its state, update it:
  - REQS.md → requirement status (Implemented/Verified if all features for this req done)
  - SPECS.md → feature status [x] + Completed date + Tests column
  - PLANS.md → ADL entry if architectural decisions were made
  - RESEARCH.md → research index if research was done
  - DESIGN.md → design index status. `design/f{N}.md` → Current State = Done
  - TASKS.md → mark [x] with completion date
  - RELEASES.md → add to current version entry (if version complete)
  - AGENT_CONTEXT.md → update phase, what's done, what's next
  - Don't leave files out of sync. If you changed one, check all others.

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
> **Skill: CI/CD Setup** — CI badge rule, branch protection, PR workflow, contribution validation, ci.yml template, stack-aware test commands in `.portable-spec-kit/skills/ci-setup.md`. Loaded on `enable ci` or project setup.

### Python Environment

Superseded by §Environment Selection — the generic env-management rule covers Python (conda · venv · poetry · uv) and every other supported stack. Legacy `python-environment.md` skill kept for backward compat with older projects; new work uses `env-management.md`.

### Dependencies
- Prefer well-maintained, widely-used packages
- Check bundle size impact before adding frontend dependencies
- Lock file (`package-lock.json` / `requirements.txt`) must be committed
- Run `npm audit` / `pip audit` periodically
- Avoid adding dependencies for things that can be done in <20 lines of code

### Context Management
**On every session start — read in this order:**
1. User profile (workspace `.portable-spec-kit/user-profile/` → global `~/.portable-spec-kit/user-profile/`) — adapt behavior to preferences
2. `agent/AGENT.md` — project config, stack, rules
3. `agent/AGENT_CONTEXT.md` — project state (what's done, what's next)
4. `.session-stack.md` (if present) — live conversation-branch tree; restores in-session context from the previous turn
5. `agent/REQS.md` — requirements
6. `agent/SPECS.md` — features
7. `agent/PLANS.md` — architecture
8. `agent/RESEARCH.md` — active research questions
9. `agent/DESIGN.md` — design overview
10. `agent/TASKS.md` — current tasks
11. `agent/RELEASES.md` — version history (scan for last release state)

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
> **Skill: Document Generation** — ARD HTML styling, presentations, changelog format in `.portable-spec-kit/skills/document-generation.md`. Loaded during release or when generating documents.## Project Organization

- Read the relevant project's `agent/AGENT.md` based on user's current task
- Do not mix context between projects
- **When working on a specific project, stay in that project's directory** — do not create files outside it unless explicitly told to
- Agent memory/preference files contain cross-project user preferences

### Agent-Created Files
- Any documentation, rules, trackers, or reference files created by the AI agent **must go inside `agent/` directory** — not project root
- Examples: layout rules, outreach trackers, scoring plans, research notes
- Only code files, configs, and READMEs belong at project root
- The `agent/` directory is the single location for all project management and AI-generated reference docs
- **`agent/` directory structure — what goes where:**
  ```
  agent/
  ├── AGENT.md, AGENT_CONTEXT.md, SPECS.md,   ← Root: markdown management files ONLY
  │   PLANS.md, TASKS.md, RELEASES.md
  ├── design/                                  ← Per-feature design plans (f{N}-name.md)
  └── scripts/                                 ← All bash scripts (.sh files)
  ```
  - **`agent/` root** — 6 markdown management files only. No `.sh`, no `.json`, no temp files.
  - **`agent/design/`** — per-feature design plans. Auto-created when features added to SPECS.md.
  - **`agent/scripts/`** — all bash scripts: sync, Jira sync, tracker daemon, installer/uninstaller, report generators. Never place `.sh` files at the `agent/` root.

### AI-Powered Onboarding
> **Skill: Onboarding** — Commit agent/ rules, CONTRIBUTING.md guidance, .gitignore defaults, sensitive content check in `.portable-spec-kit/skills/onboarding-tour.md`. Already loaded with tour skill.

### File Creation/Update Rule
> **Skill: File Management** — Auto-managed file creation/update rules, framework update migration, scan-before-summary rule in `.portable-spec-kit/skills/project-setup.md`. Already loaded with project setup skill.

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

### Onboarding Tour (First Session Only)
> **Skill: Onboarding Tour** — Tour flow (4 steps), trigger conditions, tour rules, edge cases in `.portable-spec-kit/skills/onboarding-tour.md`. Loaded on first session when no tour_completed in config.

### Contextual Presence (Always-On Help)
> **Skill: Contextual Presence** — Session greeting, milestone acknowledgments, transition guidance, error recovery in `.portable-spec-kit/skills/onboarding-tour.md`. Loaded alongside tour skill.

**WORKSPACE_CONTEXT.md rules:**
- Only created once on first session — never overwritten unless user explicitly asks
- Not for project-specific state — that goes in each project's `agent/AGENT_CONTEXT.md`
- Only update when user explicitly requests it

### Auto-Scan (On Entering Any Project)
> **Skill: Project Setup** — Auto-scan rules, existing project setup (guide don't force), kit status detection, scan edge cases in `.portable-spec-kit/skills/project-setup.md`. Loaded on project entry.

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
When creating a brand new project, create the standard directory structure with all agent files, scripts, README, .gitignore, .env.example, and config.

**Step 0 (FIRST, before any code or scaffold) — environment selection.** Per §Environment Selection, the agent runs `bash agent/scripts/psk-env.sh detect` on the planned stack, then invokes the `env-management` skill to ask the user which env to use (existing or create new dedicated env for this project). The choice persists in `.portable-spec-kit/env-config.yml` and every subsequent setup step uses the env. **No `pip install` / `npm install` / package operation runs before the env is selected** — that would pollute the user's system tooling, defeating the kit's portability promise.

> **Skill: Project Setup** — Full directory structure, file list, and 8-step procedure in `.portable-spec-kit/skills/project-setup.md`.

> **Skill: Environment Management** — env-selection prompt + persistence flow in `.portable-spec-kit/skills/env-management.md`. Loaded as Step 0 of new-project setup AND on first stack-runtime command in any project.

### Standard Source Code Structures (by project type)
> **Skill: Source Structures** — 8 project type templates (Web, Python, Mobile, Android, iOS, Full Stack, Full Stack+Mobile, Document) in `.portable-spec-kit/skills/source-structures.md`. Loaded during project setup.### Directory Purposes

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

| File / Dir | Purpose | When Updated |
|------------|---------|:---:|
| **Pipeline files** | | |
| `agent/REQS.md` + `reqs/` | Business requirements in client language. Raw input preserved in reqs/ | First — when requirements gathered + **when scope changes** |
| `agent/SPECS.md` + `specs/` | Features mapped from requirements (R→F). Acceptance criteria | Before dev + **when scope changes** |
| `agent/PLANS.md` + `plans/` | System architecture, tech stack, ADL, technical requirements | Before dev + **when architecture evolves** |
| `agent/DESIGN.md` + `design/` | Design overview + per-feature designs. Cross-cutting patterns | **When features designed** (auto/explicit/gate) |
| `agent/TASKS.md` + `tasks/` | Task tracking by version. Sprint plans when complex | **Before and after every task** |
| `agent/RELEASES.md` + `releases/` | Published release notes + full traceability summaries | End of version release |
| **Support files** | | |
| `agent/RESEARCH.md` + `research/` | Research index across all stages. Per-topic research files | When decisions need data — any stage |
| `agent/AGENT.md` | Project rules, stack, config, Definition of Done | Setup, when stack/config changes |
| `agent/AGENT_CONTEXT.md` | Living state — what's done, what's next, blockers | **Every session + after significant work** |
| **Docs** | | |
| `ard/` | Generated docs — technical overview (HTML+PDF) | End of each version release |

### README.md Template
Create on project setup, update as project evolves. Full template in `.portable-spec-kit/skills/templates.md`.

### Development Flow

**6 pipeline stages:** REQS.md → SPECS.md → PLANS.md → DESIGN.md → TASKS.md → RELEASES.md (require → specify → architect → design → build → release). 3 support files: RESEARCH.md + AGENT.md + AGENT_CONTEXT.md. Full pipeline diagram in `.portable-spec-kit/skills/templates.md`.

**Full traceability chain:** Raw Input → R (REQS) → F (SPECS) → Research → Design → ADR (PLANS) → T (tests/) → Release.

**Feedback loops:** Pipeline is logical order, not a gate. When iterating backwards, update upstream file FIRST.

### Agent Guidance Behavior

The agent is a **helpful guide, not a strict enforcer**. Follow these principles:

**Don't block the user.** The user can start anywhere — jump into coding, give direct tasks, ask questions, or follow the full spec-persistent flow. All valid. The agent adapts to how the user wants to work, not the other way around. Track everything in the background regardless.

**Guide when asked.** If the user asks "what should I do next?" or "how should I approach this?" — walk them through the spec-persistent process:
1. "Let's start by defining what you want in SPECS.md — what are the key features?"
2. "Now let's plan the architecture in PLANS.md — what stack do you want?"
3. "I'll break this into tasks in TASKS.md — here's the module breakdown"
4. "I'll track everything as we go and log it in RELEASES.md at the end"

**Always mention project name when reporting.** When confirming tasks, status, or actions — always include which project it applies to (e.g. "Noted in **ProjectName** agent/TASKS.md").

### Response Format Rule (MANDATORY)

Every agent response follows one of three templates. Scan-optimized so user can read a reply in seconds. **BRIEF and DETAILED share the same section labels** (progressive disclosure). MINIMAL is a fast-path for short answers where a table would be padding.

**Shared section backbone for BRIEF and DETAILED (always in this order):**

`WHAT → WHERE → WHY → FIX → VERIFY → RISK → SUMMARY`

BRIEF shows 5 of the 7 as table rows (omits VERIFY + SUMMARY — those are execute-path, not decide-path). DETAILED shows all 7 as full sections. MINIMAL shows none of them. Pick tier by the shape of the answer, not the shape of the question.

**MINIMAL template (fast path).** Use when the answer is one-dimensional: yes/no, status check, short factual recall, simple acknowledgment after action.

```
**<Headline = the answer itself>**

<Optional single short paragraph — one or two sentences of context. Skip if not needed.>

→ <next action, 3–7 words>
```

Pattern: headline → optional paragraph → arrow footer. No badges, no table. Breadcrumb uses full-name form same as BRIEF/DETAILED. **Generation time: ~2 sec. Output: ~100 tokens.** Read time: ~3 sec. Typical length: 4-8 lines total.

**BRIEF template (default for multi-dimensional answers).** Use when the answer has more than one dimension: design proposals, decision points, problem diagnosis, action summaries with context.

```
**<Headline = the answer itself, not a lead-in>**

`status: <one-word>` · `effort: <~Nmin>` · `impact: <scope>`

| Section | Value |
|---|---|
| What  | <one phrase> |
| Where | <file:line or component> |
| Why   | <trigger or cause> |
| Fix   | <one line> |
| Risk  | <low / medium / high — one phrase> |

→ <next action, 3–7 words>
```

Pattern: headline → 3-fact badge row → 5-row key/value table (same labels as DETAILED sections) → arrow footer. Breadcrumb uses full-name form. **Generation time: ~8 sec. Output: ~500 tokens.** Read time: ~8 sec.

**DETAILED template (on request).** Use when user says "details" / "explain" / "go deep" / asks a drill-down question.

```
**<Headline>**

`status: <one-word>` · `effort: <~Nmin>` · `impact: <scope>`

### WHAT
<1–2 sentence problem statement>

### WHERE
<file:line citation, bullets if multi-file>

### WHY
<1–2 sentence root cause>

### FIX
```<lang>
<code, diff, or config>
```

### VERIFY
```<lang>
<test command + expected output / assertion>
```

### RISK
<severity + why in 1–2 sentences>

### SUMMARY
| Section | Value |
|---|---|
| What  | <one phrase — same shape as BRIEF> |
| Where | <file:line or component> |
| Why   | <trigger or cause> |
| Fix   | <one line> |
| Risk  | <low / medium / high — one phrase> |

(The SUMMARY table at the end of DETAILED is literally the BRIEF version of the same answer — same 5 labels, same shapes. If a reader got lost mid-body, they re-anchor on this final table.)

→ <next action>
```

Pattern: headline → badge row → 7 `### LABEL` sections (shared backbone) → SUMMARY recap table → arrow footer. Breadcrumb uses full-name form. **Generation time: ~25 sec. Output: ~2000 tokens.** Read time: ~25 sec.

**Why BRIEF omits VERIFY + SUMMARY (intentional asymmetry):**
- BRIEF = **decide-surface** (enough to say yes / no / later). VERIFY is an execute-path concern — only matters *after* deciding yes. SUMMARY is a long-doc recap — useless when the doc IS short.
- Keeping BRIEF at 5 rows preserves ~8-second read time. Adding VERIFY + SUMMARY would push it to ~14 s and blur BRIEF vs DETAILED into one mushy view.
- Escape hatch: BRIEF footer arrow always offers "details" on demand.

**Hard rules — applies to EVERY response:**

1. **Headline IS the answer.** No prose lead-in ("Let me...", "I'll check...", "First..."). First line is the conclusion.
2. **Badge row** uses backticks, 3 facts max, separated by `·`. Example: `status: open` · `effort: ~30min` · `impact: kit-wide`.
3. **Shared-label consistency.** BRIEF table rows and DETAILED section headers use identical label names and ordering. Switching BRIEF → DETAILED reveals depth, never restructures.
4. **Tables beat bullets beat prose.** In that order of preference. Use prose only when narrative is required.
5. **One-line `→` footer is mandatory** so the user always knows the next action.
6. **Every technical claim cites `file:line`** when referencing code, `file:section` when referencing docs.
7. **Bold only keywords, never whole sentences.** Bold is the eye anchor; overuse destroys it.
8. **Never mix templates in one reply.** Pick MINIMAL, BRIEF, or DETAILED. One tier per reply.
9. **Multi-answer replies:** one BRIEF block per sub-topic, separated by `---`. Each block keeps its own headline + badges + table + arrow.
10. **Code blocks** use triple-backticks with language tag (`bash`, `python`, `yaml`, etc.).
11. **Never ask the user to pick between too-short and too-long.** Default is BRIEF; they ask for DETAILED when needed. Both templates are pre-designed to be complete-for-their-purpose.

**Pre-send self-check (MANDATORY — run silently before EVERY reply):**

Before emitting any reply in a kit project, agent verifies all four anchors are present:

1. ✓ **Breadcrumb** line at top? (`↳ **Nx** root › ... › **Nz** current` — always render per §Breadcrumb Header Rule, even at depth 1)
2. ✓ **`---` border** immediately after breadcrumb on its own line?
3. ✓ **Template body** — MINIMAL paragraph OR BRIEF 5-row table OR DETAILED 7-section block? (not freestyle prose + mixed headers)
4. ✓ **`→` footer** with a concrete next action?

Any missing → rewrite before sending. **No exemptions** for "let's discuss", "exploratory question", "status update", "short answer", or replies after a conversation-summary compact. Trust-based compliance has failed before; this self-check is the gate. After a context-compact, re-read §Response Format Rule + §Breadcrumb Header Rule before the first reply of the new context.

**Writing Style (MANDATORY — editorial discipline inside templates):**

The scaffolding carries most of the scan: breadcrumb, headline, badges, tables, labels. The prose inside cells and sections is where smoothness actually matters. Five rules apply to every sentence of reply body, regardless of template:

1. **One idea per sentence.** A compound sentence with "; and", "; but", "— which means" usually signals that the sentence should be two. Split it.
2. **Default terminator is a period, not an em-dash.** Em-dash is for genuine parenthetical emphasis, not a substitute for a sentence break. If a reply has em-dashes in more than one of every three sentences, rewrite for periods.
3. **Drop semicolons.** They almost always mean a sentence should be two sentences. One rare exception: lists of items that share a head clause, where commas inside items force semicolons as separators.
4. **Cut parenthetical asides unless load-bearing.** `(see my reply above)` is almost never load-bearing. `(Unix man-page style)` is load-bearing because it disambiguates a term. If the reply reads correctly without the parenthetical, remove it.
5. **One voice per reply.** Second-person when addressing the user: `you see`, `your reply`. Third-person when describing machinery: `the rule produces`, `the reader scans`. Do not mix voices inside a single section. Pick one per section based on the subject.

The goal is natural prose, not clipped terseness. Sentences can still be long when a long sentence is the right shape. The rules target patterns that hide sloppy thinking behind dense syntax. They are not a word-count cap.

**Design rationale (for future maintainers — do not "normalize away" the asymmetry):**
Progressive disclosure is the industry standard (Apple docs TL;DR, Wikipedia lead sections, IETF RFC abstracts, Unix man pages, Terraform registry "basic usage" vs "full reference"). All use *one set of labels, two depths*. The shared backbone lets the user's eye find WHAT / WHERE / WHY / FIX / RISK in any reply regardless of depth. Do not add VERIFY or SUMMARY to BRIEF — the asymmetry is the feature. MINIMAL is the pre-progressive-disclosure tier: when there is no progression to disclose, just answer.

**Template dispatch (auto-selection rule — agent picks, user does not specify):**

The agent auto-selects the template per reply based on the shape of the answer. Size the content first, then pick the tier that fits. Fallback on genuine ambiguity is BRIEF.

| Trigger | Template | Gen time | Tokens |
|---|---|---|---|
| Yes/no confirmation | MINIMAL | ~2 sec | ~80 |
| Status check ("are we done?", "is it landed?") | MINIMAL | ~2 sec | ~80 |
| Short factual recall ("what is N33?") | MINIMAL | ~2 sec | ~80 |
| Simple acknowledgment after an action | MINIMAL | ~2 sec | ~80 |
| Multi-dimensional answer with 2+ independent facets | BRIEF | ~8 sec | ~500 |
| Decision point requiring trade-off analysis | BRIEF | ~8 sec | ~500 |
| Design proposal, problem diagnosis | BRIEF | ~8 sec | ~500 |
| Action summary with commit SHA + files + tests | BRIEF | ~8 sec | ~500 |
| User says "details" / "explain" / "go deep" / "walk through" | DETAILED | ~25 sec | ~2000 |
| Complex multi-component implementation plan | DETAILED | ~25 sec | ~2000 |
| Drill-down question after a prior BRIEF | DETAILED | ~25 sec | ~2000 |

**User overrides.** The user can force any tier at any time: `"shorter"` drops one tier, `"more depth"` promotes one tier, `"raw reply"` strips scaffolding entirely for that turn.

This rule is framework-level. Applies to all agent communication in all projects using the kit.

### Breadcrumb Header Rule (MANDATORY when deeply branched)

Passive context anchor rendered at the TOP of every reply when the session-stack current node is ≥ 3 levels deep. Complements the `.session-stack.md` file — stack is read on demand, breadcrumb is always visible.

**Format:**

```
↳ **N<root-id>** <root-name> › **N<parent-id>** <parent-name> › **N<current-id>** <current-name>
```

**When to render:**

**Always.** Every reply renders the breadcrumb regardless of depth — perfect-sync orientation. Even at depth 1 (root only), the single-entry breadcrumb anchors the reader to the current root task.

| Current node depth | Breadcrumb rendered? | Form |
|---|---|---|
| 1 (root only) | **Yes** | Single entry: `↳ **N1** root-name` |
| 2 | **Yes** | Two entries: `↳ **N1** root › **N2** current` |
| 3+ | **Yes** | Three entries: `↳ **N1** root › **Nx** parent › **Nz** current` (intermediate active ancestors collapsed) |

**Placement in reply:**
- BEFORE the headline of the first block (or any multi-block `---` separators)
- Always on its own line
- **Followed by `---` horizontal rule on its own line** (border for visual separation from body)
- Uses `↳` arrow to indicate "we came from"

Layout:
```
↳ **Nx** root › **Ny** parent › **Nz** current
---

**Headline of first block**
...reply body...
```

The `---` border under the breadcrumb is a one-time orientation bar. It does not collide with the multi-block `---` separator because position disambiguates:
- `---` directly under the breadcrumb line → breadcrumb border
- `---` between blocks (preceded + followed by blank line + headline) → multi-block separator

**Rules:**
1. Breadcrumb traces the **CURRENT active chain only** — root-ancestor → parent-active → current-active. Closed (`✓`), abandoned (`✗`), and queued (`·`) nodes **never appear** in the active-chain portion of the breadcrumb. Rule 6a below adds one narrow exception (trailing closed-sibling hint) — do not confuse the two.
2. Breadcrumb shows **exactly 3 entries** when depth ≥ 3 — root, immediate parent, current. Intermediate active ancestors collapsed; closed nodes skipped entirely.
3. Names are **truncated to ~30 chars** per entry — full context is in `.session-stack.md`, breadcrumb is the skim-summary.
4. Node IDs are **bolded** so the user can reference them (`"back to N7"`).
5. `›` is the separator between entries (not `>` or `→` — reserved for other meanings).
6. **Always render the breadcrumb on every reply** — perfect-sync orientation regardless of depth. Even at depth 1 the single-entry breadcrumb anchors the reader. Consistency > visual-noise savings.
6b. **(REVERTED 2026-04-22 — user feedback: IDs-only was unreadable.)** All templates (MINIMAL, BRIEF, DETAILED) render the breadcrumb with full node names. The ~15-token cost is small compared to the clarity loss of bare IDs. Bigger latency wins live in Rules 6c and 6d below, which don't trade readability.

6c. **Consecutive-reply breadcrumb skip (latency optimization).** When the reply uses the MINIMAL template AND the current active node has not changed since the previous reply (no branch, no park, no close, no resume), the breadcrumb + `---` border may be skipped entirely. First MINIMAL reply in a new node renders breadcrumb. Subsequent MINIMAL replies under the same node can start directly at the headline. Saves ~20-30 tokens per reply on conversational threads. BRIEF and DETAILED always render breadcrumb regardless. Any node-state change (branch, close, park, resume) forces a breadcrumb on the next reply.

6d. **Arrow footer is optional in MINIMAL.** When the reply is purely informational with no concrete next action to propose (e.g. "yes", "3 tiers exist", "the answer is X"), the `→ <next action>` footer may be omitted. Saves ~10-15 tokens. BRIEF and DETAILED keep the arrow as mandatory since those tiers are decision-surface replies that always have a next step.

6a. **Trailing closed-sibling hint.** After the active-chain breadcrumb, append exactly **one** trailing reference to the most-recently-closed qualifying node, so the reader sees "what just wrapped up here" without opening `.session-stack.md`. Qualification rule:
    - If the deepest active node has a parent → the most-recently-closed **sibling** of the deepest active (same parent, marker `✓`)
    - If the deepest active IS root (no parent) → the most-recently-closed **direct child** of root

    **Format:** `› ✓**Nx** <name>` — same `›` separator as active entries; `✓` prefix distinguishes from active. Name truncated to ~25 chars. No `closed:` prefix or other label — the `✓` mark alone signals closed-reference semantics.

    **Lifecycle:**
    - **Replaced** when a newer qualifying sibling closes → the newer `✓`-node takes the slot. Older closes fall out by being out-competed, not by aging.
    - **Never dropped** otherwise — the slot always shows *the most recent* close at the current level.
    - **Re-evaluated** when the active node itself moves (branch deeper, resume a parked node, switch roots) — the new deepest active determines the new hint scope.
    - **Session archive** resets the breadcrumb naturally (new tree = no prior closes).

    **Edge case:** if no qualifying closed node exists yet (e.g. first sub-topic in a fresh session), emit no hint — breadcrumb stays active-chain-only.

    **Depth interaction:** the hint appends after the active chain regardless of depth. A full depth-3 breadcrumb with hint reads `↳ **N1** root › **Ny** parent › **Nz** current › ✓**Nw** last-sibling-of-Nz`. Four entries maximum; breadcrumb still fits a scan.

**Why this works with the rest of the Response Format Rule:**
- BRIEF template already targets 8-second reads. Breadcrumb (active chain + up to one hint) adds ~1-2 seconds. Still within budget.
- DETAILED template targets 25-second reads. Breadcrumb is negligible overhead.
- No breadcrumb pollution when conversation is linear (depth ≤ 2, no prior closes) — the rule self-suppresses.
- The hint is a convenience signal, not a history log — `.session-stack.md` remains the authoritative trail. One ✓-node at a time keeps the breadcrumb from drifting into full-history territory.

**Example (this very conversation):**

```
# Active chain only (no closed sibling yet):
↳ **N1** AVACR eval

# Active chain + trailing hint (after N36 closed as direct child of root N1):
↳ **N1** AVACR eval + Kit evolution › ✓**N36** G1-G15 kit gaps

# Depth-3 active chain + hint:
↳ **N1** AVACR eval › **N7** Kit evolution › **N24** Breadcrumb rule fix › ✓**N23** Session-stack demo
```

### Session Stack (`.session-stack.md`) — Conversation Branching Trace (MANDATORY)

Long conversations branch into sub-topics; users lose the original task. `.session-stack.md` is the real-time branching log — a mid-granularity layer between `agent/AGENT.md` (static) and `agent/AGENT_CONTEXT.md` (across-session).

**File location (project-root, gitignored):**
- `.session-stack.md` — live index + current active session tree at bottom
- `.session-archive/YYYY-MM-DD-HH-MM.md` — frozen per-session trees

**Strict vocabulary segregation from `agent/TASKS.md` — zero-collision guarantee:**

| File | Markers used | Status words used |
|---|---|---|
| `agent/TASKS.md` | `[x]` `[ ]` `[~]` | done · pending · acknowledged |
| `.session-stack.md` | `→` `⏸` `✓` `·` `✗` | current · parked · closed · queued · abandoned |

**Never cross-use.** Agent physically cannot use `[x]` in the stack file or `→` in TASKS.md. Grep-safe: no marker or status word appears in both files.

**Node format:** `N{id} <marker> HH:MM │ <short description>`. Example: `N5 → 11:50 │ Session stack design ← CURRENT`.

**Auto-triggers (agent MUST detect these in user messages and update stack BEFORE responding):**

| User signal | Stack action |
|---|---|
| New sub-topic (branch) | Current `→` → `⏸`; new child appended as `→` |
| `"back to <name\|ID>"` / `"resume <name\|ID>"` | Current `→` → `⏸`; target → `→` |
| `"done"` / `"next"` + no new topic | Current `→` → `✓` (with commit SHA if available); parent → `→` |
| `"skip"` / `"abandon"` | Current `→` → `✗`; parent → `→` |
| `"where was I"` / `"status"` / `"context"` / `"stack"` | Agent renders current tree + runs drift check |

**Invariant:** exactly one `→` per tree at any moment. Violation = drift, surfaced on next `where was I`.

**Ambiguity rule:** if `"back to <name>"` matches 0 or >1 parked branches, agent asks for clarifying ID. Never silent guess.

**Integration with other rules:**
- **Task Tracking (MANDATORY):** `agent/TASKS.md` remains source of truth for PROJECT tasks. `.session-stack.md` is conversation-branching only. Entries never migrate between files.
- **Response Format Rule:** after a switch-back, agent's reply need NOT include the tree unless user explicitly asked via `"where was I"`. Silent auto-updates keep replies clean.
- **Overhead budget:** ~1 ms per transition, <10 KB per session, zero user friction — all writes are agent-managed.

**Promotion rule — closed stack node → durable TASKS.md entry:** When a node closes with `✓` (optionally with commit SHA) AND represents durable project work (a feature built, a doc shipped, a bug fixed), agent MUST propose promoting it to `agent/TASKS.md` under the current version heading before the session ends. This converts transient session progress into persistent project record without breaking vocabulary segregation — the stack entry stays `✓`; a *separate* new `[x]` task is added to TASKS.md referencing the same commit SHA. Skip promotion for nodes that are purely navigational (e.g., "demo", "walk-through", "context restore") — those die with the session. Ambiguous? Ask the user once: `"N12 closed — promote to TASKS.md under v0.6? (y/n)"`. Never silent-skip a node that contained code/doc changes.

**Long-session scalability (3-tier compaction):** single very long sessions can accumulate 100+ nodes. Three tiers prevent unbounded growth: (T1) auto-collapse 3+ consecutive `✓` siblings into `Nx–Ny ✓ <summary>` range lines; (T2) default-render only active chain + siblings on `"where was I"` (full tree on `"show full stack"`); (T3) when live file ≥ 15 KB or ≥ 80 nodes, rotate oldest fully-closed sub-trees into `.session-archive/YYYY-MM-DD-chapter-NN.md` with a one-line `[chapter-NN: Nx–Ny, N nodes closed]` reference left in live file. All three tiers are reversible — chapter files permanent, T1/T2 render-only. Full rules in the Session Trace skill.

**Opt-out:** project config can set `session_stack: disabled` for linear conversations where branching is rare.

> **Skill: Session Trace** — full file format, state-transition rules, drift-detection logic, archive rotation, and long-session compaction tiers in `.portable-spec-kit/skills/session-trace.md`. Loaded when user mentions losing context / branching / "where was I".

### Kit-vs-Project Scope Separation (MANDATORY)

When working in a project that has the kit installed, every fix the agent makes must land in the correct repo. Two repos coexist in any kit-enabled workspace: the **project repo** (the user's app — features, business logic, project-specific config) and the **kit repo** (`portable-spec-kit/` — generic machinery shared across all projects via symlinked `portable-spec-kit.md`, scripts in `agent/scripts/`, the `reflex/` framework, skill files, templates).

**Genericity test — apply before any commit:** ask "would this exact change be correct for *every* project that installs the kit?"

| Test outcome | Land the fix in |
|---|---|
| Yes — change is correct for all kit users | **Kit repo** |
| No — change is shaped by this project's stack / features / files / acceptance criteria | **Project repo** |
| Mixed — root cause is generic but the user-visible bug is in the project | **Split commits** — kit commit for the generic root-cause fix, project commit for the project-side mitigation |

**Examples by category:**

| Project repo (project-specific) | Kit repo (generic) |
|---|---|
| Feature implementation (F1-F12 of an app) | Reflex orchestrator logic in `reflex/run.sh` / `reflex/lib/loop.sh` |
| CVE upgrade in `package.json` | Sync-check rules in `agent/scripts/psk-sync-check.sh` |
| Project's CSP / auth / route handlers | Skill files in `.portable-spec-kit/skills/` |
| Project's README / HANDOFF / TASKS.md | Kit's own README / CHANGELOG / RELEASES.md |
| Project's TS hygiene (tsconfig excludes for project's own paths) | Kit-level prompts in `reflex/prompts/` |
| Project's `.env.example` for project's secrets | Kit's installer / updater scripts |
| Tightening security headers for the user's app surface | New ADR rule that affects how every project handles security |

**Why this matters:** the kit is portable across projects. A change shaped by one project's accidental properties (e.g. one app's specific Next.js version, Postgres schema, Twilio webhook structure, Tailwind palette) over-fits the kit and either breaks or misleads other projects. The kit's value is its genericity — every project pulls the latest kit and inherits well-tested, project-agnostic machinery. Project-specific fixes leaking into the kit pollute that contract.

**Default behavior when in doubt:** land the fix in the **project repo**. Promote to the kit only after the fix is independently verified as generic — i.e., the same fix would help two or more unrelated projects. One-off observations stay in the project; only validated patterns become kit changes.

**Cross-cutting work — split commits cleanly:** when a bug surfaces via one project but the root cause is in kit machinery (a generic bug in `reflex/`, `agent/scripts/`, a skill, a template), the agent MUST split:
1. **Kit commit** — the generic root-cause fix, kit-version bumped, kit's own ADR / RELEASES updated, regression test added in `tests/sections/`.
2. **Project commit** — the project-side mitigation or revalidation that proves the kit fix works in this project.

Never bundle project-shaped code into a kit commit. Never bundle kit-machinery edits into a project commit.

**Allowed kit-touching work without genericity proof:**
- Kit's own version-consistency sweeps (badges, ARD, examples, count drift) when a kit version bump lands — these are kit-internal and generic by definition.
- Regression tests added in `tests/sections/` that lock in a kit-level fix already proven generic.
- ADR / RELEASES / CHANGELOG entries documenting a kit-level decision.

**This rule is the general superset.** The `Reflex Finding Classification` section below applies the same principle specifically to reflex/AVACR findings (where the QA-Agent attaches a `scope:` field machine-routing to project vs kit). The kit-vs-project rule here applies to every form of work — manual fixes, plan-mode implementations, refactors, doc work — not just reflex outputs.

### Environment Selection (MANDATORY before any stack-runtime command)

The kit owns runtime-environment selection across every project, every stack, every agent. Without explicit env management, the agent silently falls back to system Python / system Node / whatever's on PATH — which works on the agent's machine but breaks for every other contributor on a different machine.

**The contract:**
1. **Auto-detect on session start.** Agent runs `bash agent/scripts/psk-env.sh detect` to enumerate project stacks (Python / Node / Ruby / Go / Rust based on file presence: `requirements.txt`, `package.json`, `Gemfile`, `go.mod`, `Cargo.toml`).
2. **Prompt if not configured.** For each detected stack with no entry in `.portable-spec-kit/env-config.yml`, the agent invokes the `env-management` skill — interactive prompt offering existing envs (conda envs, project venv, system runtime) AND a "create new dedicated env" option. **The prompt is mandatory** before any stack-runtime command runs in this project.
3. **User picks existing or creates new.** If user picks "create new", the agent runs the manager's create command (`conda create -n <name>`, `python3 -m venv .venv`, `nvm install <version>`, etc.) with explicit confirmation before destructive operations.
4. **Persist the choice.** `psk-env.sh set <stack> <manager> <name-or-version>` writes the entry to `.portable-spec-kit/env-config.yml` (committed — every contributor pulls the same env choice).
5. **Use the env for EVERY command thereafter.** The agent prefixes every stack-runtime command with the activation prefix from `psk-env.sh activate-cmd <stack>`. This applies to:
   - Project commands the user requested (`pytest`, `npm test`, `prisma migrate dev`, etc.)
   - Agent-internal scripts that import project code
   - Dev-server starts (`npm run dev`, `flask run`, `cargo run`, etc.)
   - Package installs (`pip install`, `npm install`, `bundle install`, `cargo build`, etc.)
   - Lint / format / typecheck commands (ruff, eslint, prettier, mypy, etc.)
6. **Verify before invocation.** First time per session, agent runs `psk-env.sh check` to confirm the saved env still works (e.g., conda env wasn't deleted between sessions). If broken → re-prompt user, do not silently fall back to system.

**The agent runs in the project's env, always.** Every command the agent invokes that touches project runtime executes inside the env — not just user-invoked commands. There is no "informal" path where the agent uses system tools while the user's stuff uses the env. If the env is selected, the env is used universally.

**No env yet selected (pre-prompt state):** the agent does NOT silently invoke the runtime — it raises the prompt first, then runs. Refusing to run is the correct behavior here. Skipping the prompt would lock the project to whatever tool happens to be on PATH at that moment, which is exactly the problem env-config solves.

**Manual triggers:** user can re-prompt anytime with `"reset env"` / `"choose env"` / `"switch env"` — agent re-invokes the env-management skill, walks the menu again, overwrites the entry.

**Disable / bypass:** `PSK_ENV_AUTO_DETECT=0` env var skips the auto-detect (for kit's own self-tests, CI scenarios where env is pre-configured by the runner). The check is opt-out, not opt-in — defaults to ON.

**Performance impact:** ~10ms per command for the activation-prefix lookup (single YAML read). Detect runs once per session start (~10ms). Negligible compared to actual runtime.

**Manifest contract (companion to detect):** the same files §Environment Selection uses for detection are the **required manifests** for every project running that stack — `package.json` for Node, `pyproject.toml` / `requirements.txt` / `setup.py` / `Pipfile` for Python, `Gemfile` for Ruby, `go.mod` for Go, `Cargo.toml` for Rust. New-project setup creates the appropriate manifest as part of Step 0 (with `engines.node` / Python version / Ruby version aligned to the chosen env). Existing-project setup blocks if a stack is detected but its manifest is missing — silent fallback would let "works on my machine" become the project's only deployment story. Verify with `bash agent/scripts/psk-env.sh check` (existing command — already validates env + manifest cohesion).

> **Skill: Environment Management** — full procedural flow (detect → list → prompt → pick → save → verify), edge cases (multiple stacks, missing manager, deleted env), schema definition, performance budget — in `.portable-spec-kit/skills/env-management.md`. Loaded the first time a stack-runtime command needs to run in a session.

### Optimization Health Indicator (MANDATORY when state file exists)

The kit tracks optimization health in `.portable-spec-kit/optimize-state.yml` (committed to repo, updated by every `bash agent/scripts/psk-optimize.sh --scan` invocation, read by `--health` flag and by agents at session start). The state encodes: last scan timestamp, candidate count by category, recommended-next-scan date, and a status field (optimized / review / stale).

**Agent behavior — read state, append to breadcrumb:**

At session start (cost: ~5ms — one file read + 3 awk parses) the agent reads `.portable-spec-kit/optimize-state.yml` if present. If state exists, append a one-token health indicator to the breadcrumb header on EVERY reply, immediately after the active chain + any closed-sibling hint:

```
↳ **N1** root › **Nz** current · opt: 🟢 optimized
↳ **N1** root › **Nz** current · opt: 🟡 review (3 candidates)
↳ **N1** root › **Nz** current · opt: 🔴 stale (45d, 8 candidates)
```

**Status thresholds (combine candidate count + days-since-scan):**

| Status | Indicator | Trigger |
|---|---|---|
| 🟢 optimized | `opt: 🟢 optimized [(N deferred)]` | 0-2 candidates AND scan within 30 days. Trailing `(N deferred)` if there are explicitly-deferred candidates (e.g., qa-agent.md prompt). |
| 🟡 review | `opt: 🟡 review (N candidates)` | 3-9 candidates OR scan 30-60 days old |
| 🔴 stale | `opt: 🔴 stale (Nd, M candidates — sweep recommended)` | 10+ candidates OR scan >60 days OR no scan ever |

**Suppression:** if `.portable-spec-kit/optimize-state.yml` is missing (older project, never scanned), suppress the indicator entirely rather than triggering a scan from breadcrumb context. The user runs `/optimize` or `--scan` when ready; the indicator becomes visible after the first scan creates the state file.

**Manual probe:** `bash agent/scripts/psk-optimize.sh --health` prints the same one-liner the agent renders in the breadcrumb. Use it in shell scripts, CI, or to verify the indicator state out-of-band.

**Refresh discipline:** the state file is only as fresh as the last `--scan`. Prep-release Step 10 runs `--scan` automatically (advisory, non-blocking), so projects on a normal release cadence keep the state fresh without manual effort. Long-quiet projects show the age-escalation honestly (yellow at 30d, red at 60d) so the user knows to refresh.

### Reflex Finding Classification (MANDATORY)

Every reflex/AVACR finding carries a `scope:` field that classifies where the fix belongs. Three categories — the kit evolves empirically via this mechanism.

| Scope | What it targets | Who fixes it | Fix lands in |
|---|---|---|---|
| `target-project` | User's project code / tests / docs / config | Dev-Agent (auto) | User's repo |
| `kit` | Kit scripts (`reflex/`, `agent/scripts/`), kit prompts, skills, templates, flow-docs | Kit maintainer (human-routed) | `portable-spec-kit` repo |
| `meta` | Kit's research output (papers, methodology claims, public positioning, ADL rationale) | Kit maintainer (human-routed) | `portable-spec-kit` repo |

**QA-Agent classification rule:** every finding in `findings.yaml` MUST include `scope`. Default is `target-project`. Set `kit` when the fix belongs in kit scripts/prompts/skills/templates. Set `meta` when the fix is about a claim the kit makes to the world (paper, README, methodology doc, competitive positioning).

**Routing at `file-bugs.sh`:**
- `scope: target-project` → append as `@reflex-dev` task in user's `agent/TASKS.md` (current behavior).
- `scope: kit` → append as `@kit-maintainer` task at `agent/tasks/Gxx-<slug>.md` in the kit repo AND single-line entry in kit's `agent/TASKS.md` under the active v0.x backlog. Do NOT route to the Dev-Agent of the running project.
- `scope: meta` → same destination as `kit`, but also tag `meta` in the task title so later batch-review can sort.

**Dev-Agent rule:** only auto-fix findings with `scope: target-project`. `kit` and `meta` findings are informational to Dev-Agent — they are routed to the kit repo for maintainer review, not silently applied.

**Kit-Evolution Protocol — how reflex findings become kit improvements:**
1. QA surfaces finding → classifies scope → file-bugs routes.
2. Kit maintainer (not Dev-Agent) reviews `agent/tasks/Gxx-*.md` batch before a kit release.
3. Proposed fix verified generic — must hold true for any user project, not just the one that surfaced it. Fixes that over-fit one project are rejected or reframed.
4. Approved fixes land in kit via normal R→F→T + ADL + mechanical-gate discipline. Commit message references source: `[source: avacr-eval-<project>/pass-NNN/Gxx]`.
5. Rejected fixes stay in `agent/tasks/rejected/Gxx-*.md` with rationale — audit trail of "why not."

**Net effect:** every user running AVACR on their own project contributes (optionally) to kit improvement — the kit is continuously stress-tested by real-world use, not just by maintainer self-testing. `agent/tasks/` becomes the empirical record of how the kit evolves.

**Execution isolation — three invariants (MANDATORY):**

1. **QA-Agent runs in a sandbox worktree** at `reflex/sandbox/cycle-NN/pass-NNN/` with `agent/AGENT.md` + `agent/AGENT_CONTEXT.md` physically removed. QA cannot read Dev's narrative.
2. **Dev-Agent runs on an isolated branch** `reflex/dev-cycle-NN-pass-NNN` off the current HEAD. Fix commits land there; the user's main branch is untouched during the pass. On GRANTED verdict, run.sh fast-forward merges to main (falls back to no-ff merge on divergence) and deletes the dev branch. On DENIED / REGRESSION the branch is retained for review (last-3 pattern, prune-history.sh enforces).
3. **Protected-files write-ban: reflex never modifies AGENT.md / AGENT_CONTEXT.md (3-layer enforcement).** `agent/AGENT.md` and `agent/AGENT_CONTEXT.md` are owned by the spec-persistent pipeline, never by reflex findings. Layer 1: `reflex/prompts/dev-agent.md` mandates the constraint. Layer 2: `reflex/lib/gates.sh` fails any commit on a `reflex/dev-*` branch that touches them. Layer 3: `psk-sync-check.sh check_reflex_protected_files` blocks the commit at the pre-commit hook when on a reflex branch. If a finding's recommendation would touch these files, Dev-Agent files it as Bucket D (QA scope violation) + routes the underlying concern to human-arbitration via a `QA-<ID>-ARB` task in `agent/TASKS.md`.

**Autoloop — one command for kit + user projects:** `bash reflex/run.sh` (default mode = autoloop; `--autoloop` / `--loop` / `--kit-loop` flag aliases retained for backward compat) chains prep-release → reflex pass → iterate **until convergence** (GRANTED / REGRESSION / findings-floor / plateau / fix-rate drop). The `convergence.max_iterations_safety` ceiling (default 20) is an escape hatch, not the primary stop. Use `bash reflex/run.sh single` for single-pass mode. Works identically on the kit itself, new projects, existing projects, and any user project — kit-identity auto-detection routes `scope: kit | meta` findings to `agent/tasks/Gxx-*.md` when the target is the kit; otherwise findings append to the target's `agent/TASKS.md`.

**History retention (bounded disk use):** `reflex/history/REFLEX_EVAL_TRACE.md` (register) and `summary.csv` are kept forever. Per-pass directories are capped at `history_retention.pass_dirs_keep` (default 10) in `reflex/config.yml`. Dev branches are capped at `dev_branches_keep` (default 3, unhappy paths only). QA sandbox worktrees at `qa_sandbox_keep` (default 3). Pruning runs automatically at the start of every pass. Pruned passes remain in the register with an `_(archived)_` marker — status still resolvable via `agent/TASKS.md` lookup, drill-down links removed. Manual clean slate: `bash reflex/run.sh --purge-history --confirm`.

**v0.6.2 reflex refinements (in addition to the execution-isolation rules above):**

- **Nested per-cycle layout (v0.6.13+):** per-pass directories are `cycle-NN/pass-NNN/` (autoloop) or `standalone/pass-NNN/` (single-pass). The per-cycle parent dir hosts a `summary.md` aggregator. Pass numbers globally monotonic. Sandbox worktrees mirror the same layout: `reflex/sandbox/cycle-NN/pass-NNN/`. Flat identity (`cycle-NN-pass-NNN`) is reserved for git branches, CSV pass id, and `[source: ...]` commit trailers.
- **Cycle metadata + grouped register render:** each pass directory gets a `.cycle-meta` file at creation (cycle id + iteration + mode + started timestamp). `reflex/lib/update-eval-trace.sh` groups register blocks by Reflex cycle with `## Reflex cycle N` headings and `iter N` labels per pass.
- **All per-pass artifacts committed:** every file QA / Dev produces per pass — `findings.yaml`, `signoff.md`, `verdict.md`, `investigation-log.md`, `coverage.md`, `pass-plan.md`, `project-understanding.md`, `qa-summary.md`, `qa-usage.yaml`, `test-plan.md`, `dev-trace.md`, `deferred-decisions.md`, `regression-diff.md`, `gates-result.md`, `.cycle-meta` — is now committed. Only `reflex/sandbox/` stays gitignored.
- **Sandbox purge after QA:** `reflex/lib/file-bugs.sh` purges the current pass's sandbox worktree the moment findings are extracted into `reflex/history/<pass>/`. Dev physically cannot read QA's private workspace — structural enforcement, not trust-based. Previous 2 sandboxes retained for QA's own cross-pass debugging.
- **Entry consolidation — single CLI surface:** `bash reflex/run.sh` is the sole public entry; default mode is autoloop. The old wrapper scripts (`reflex/autoloop.sh`, `reflex/kit-loop.sh`, `reflex/self-test.sh`, top-level `reflex/loop.sh`) are retired. Use positional `single` (or `--single`) for single-pass mode. `reflex/lib/loop.sh` remains as the internal state-machine library.

**Trace files (reviewer surface):** three committed artifacts live under `reflex/history/`:

| File | Scope | Written by |
|---|---|---|
| `<pass-name>/findings.yaml` | one pass · structured evidence (id · priority · scope · dimension · citable_quote · regression_vector · recommendation) | QA-Agent peer-exchange |
| `<pass-name>/signoff.md` | one pass · verdict (GRANTED / DENIED) + deferred decisions + human-arbitration list | `reflex/lib/spawn-qa.sh` + QA-Agent |
| `REFLEX_EVAL_TRACE.md` | **all** passes · cross-pass findings register (one block per pass · one row per finding · id · severity · scope · status · one-line summary) | `reflex/lib/update-eval-trace.sh` (auto-refresh on every pass filing + every kit-loop iteration) |

Open `REFLEX_EVAL_TRACE.md` to review every finding across every pass with current status (`[x]` closed · `[ ]` open · `[~]` acknowledged · `[?]` untracked). Drill into a pass via its `signoff.md` (narrative + verdict) or `findings.yaml` (structured evidence with invocation_verbatim + expected_assertion for re-execution). Do not edit `REFLEX_EVAL_TRACE.md` by hand — edit the pass's `findings.yaml` or the matching `agent/TASKS.md` entry, then re-run `bash reflex/lib/update-eval-trace.sh`.

### Kit Self-Help (Built-in Guidance)
The kit is self-sufficient — the user should never need to memorize commands. The agent guides naturally.

**Strict rule: NEVER expose kit internals to the user.** Explain WHAT and HOW — never WHY, section numbers, rule names, or enforcement logic.

**All guidance is dynamic — never hardcoded.** Agent derives help by reading current framework, project files, and config at request time.

> **Skill: Kit Self-Help** — Dynamic guidance sources, help triggers, contextual help, command discovery, proactive nudges, version upgrade resilience in `.portable-spec-kit/skills/self-help.md`. Loaded when user asks for help.

### Progress Dashboard
> **Skill: Dashboard** — Dashboard format, computation rules, BY CONTRIBUTOR section, edge cases in `.portable-spec-kit/skills/dashboard.md`. Loaded on `progress` / `dashboard` / `burndown` trigger.

### Multi-Agent Task Tracking
> **Skill: Multi-Agent** — @username syntax, per-user task view, delegation/unassign, cross-agent coordination, shared tasks in `.portable-spec-kit/skills/multi-agent.md`. Loaded on `my tasks` / `assign` / `delegate` trigger.

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

### Persistent Memory Architecture

The 9 agent files (`REQS.md`, `SPECS.md`, `PLANS.md`, `RESEARCH.md`, `DESIGN.md`, `TASKS.md`, `RELEASES.md`, `AGENT.md`, `AGENT_CONTEXT.md`) collectively form the project's **Persistent Memory** — not merely documentation. Any AI agent that reads them is instantly briefed: no verbal handoff, no onboarding call, no stale wiki.

**Properties of Persistent Memory:**
- **Durable** — persists in git across time; survives session ends, machine changes, team turnover
- **Shared** — any agent on any machine reads the same files from the same repo
- **Portable** — works with Claude, Cursor, Copilot, Cline, Windsurf — agent-agnostic by design
- **Team-scale** — multiple users and agents coordinate without any real-time connection
- **Auditable** — git history records every change, who made it, and when

**How Persistent Memory enables team coordination:** Agent A works on the project → writes decisions to PLANS.md, tasks to TASKS.md, state to AGENT_CONTEXT.md → commits and pushes. Agent B on another machine (or using a different AI tool) pulls → reads the same files → is fully briefed without any message exchange. No APIs. No message queues. No real-time orchestration required.

This is the core innovation of SPD beyond spec persistence. Just as Spec-Persistent Development keeps specs alive through development, Persistent Memory Architecture keeps project intelligence alive across contributors, agents, and time.

**Persistent Memory vs. agent memory/context:** Agent memory (like Claude Code's conversation history) is ephemeral — lost when the session ends. Persistent Memory lives in git. It survives across sessions, across agents, and across team members. Always tracking silently = always writing to Persistent Memory.

### Jira Integration (Optional)
> **Skill: Jira Integration** — TASKS.md tags, Jira commands, sync flow, hours tracking, psk-tracker in `.portable-spec-kit/skills/jira-integration.md`. Loaded on `sync to jira` / `jira` / `install tracker` trigger.

### Auto Code Review

Automated two-layer code review after every feature completion. The agent runs the mechanical script then adds AI-judgment review. Shows combined report before marking feature `[x]` in TASKS.md.

**Two layers:**
- **Layer 1 — `psk-code-review.sh`** (mechanical, grep-based): security anti-patterns (`eval`, `pickle`, `shell=True`, `dangerouslySetInnerHTML`, native browser dialogs, hardcoded secrets), code quality (`console.log` in production, unresolved `TODO/FIXME`, `.env` files committed), directory structure (agent files present, scripts in `agent/scripts/`), naming conventions (kebab-case files, snake_case Python). Stack auto-detected from `agent/AGENT.md`.
- **Layer 2 — AI judgment** (agent adds after script): architecture compliance (code matches `PLANS.md` Stack and structure), design decision compliance (code matches `agent/design/f{N}.md` decisions), naming clarity (semantically clear, not just pattern-compliant), test quality (meaningful assertions, not just "doesn't crash").

**Trigger:** After completing a feature, before marking `[x]`. **Config gate:** check `Code Review.Auto on feature completion` in Config Contract — if disabled, skip. If enabled, agent runs `bash agent/scripts/psk-code-review.sh` then appends AI review items.

**Advisory, not blocking.** Kit principle: "never blocks." If issues found, agent shows report and asks: "N issues found. Fix now? (y/n/skip)". User can skip. But skipped reviews are flagged at `sync to jira` and `prepare release`.

**Commands:**
| Command | What it does |
|---------|-------------|
| *(auto)* Feature completed | Agent runs review before marking [x] |
| `"review code"` / `"code review"` | Run review on current working state |

### Scope Drift Detection

Proactive detection of scope drift across 5 dimensions. Ensures the project stays aligned with defined requirements, features, and architecture throughout development.

**Five drift dimensions:**
| Dimension | What it detects | Source |
|-----------|----------------|--------|
| Feature drift | Completed tasks not mapped to any feature | TASKS.md → SPECS.md |
| Requirement gaps | Requirements with no features | SPECS.md Rn → Fn |
| Scope creep | Features without requirement references | SPECS.md Req column |
| Architecture drift | Codebase has tech not in PLANS.md | PLANS.md → package.json/requirements.txt |
| Plan staleness | Design plan status ≠ SPECS.md status | agent/design/ → SPECS.md |

**Drift score:** 0 = aligned. Each issue adds 1. Score > 0 triggers report.

**Trigger schedule (all subject to Config Gateway Rule):**
- Session start — **config gate:** `Scope Drift.Auto on session start`. Quick check only.
- Before `sync to jira` — **config gate:** `Scope Drift.Auto on session start`. Full check.
- During `prepare release` Step 3 — **config gate:** `Scope Drift.In release pipeline`. Full check.
- On `"check scope"` command — **always runs** (manual commands bypass config)

**Advisory at session/sync. Recommended-fix at release.** Drift doesn't block work, but is surfaced for user awareness. At release, drift is flagged prominently.

**Commands:**
| Command | What it does |
|---------|-------------|
| *(auto)* Session start | Quick check (feature drift + plan staleness) |
| `"check scope"` / `"scope check"` / `"drift check"` | Full 5-dimension check on demand |

### Agent File Templates

Use these exact templates when creating `agent/` files. Replace `<Project Name>` with actual name.

> **Skill: Project Setup** — Full templates for all 9 agent files (REQS.md, SPECS.md, PLANS.md, RESEARCH.md, DESIGN.md, TASKS.md, RELEASES.md, AGENT.md, AGENT_CONTEXT.md) are in `.portable-spec-kit/skills/templates.md`. Agent reads this file when creating or restructuring agent files.

**tests/test-release-check.sh:**
> Script validates R→F→T coverage: every done feature must have passing test reference. Full script at `tests/test-release-check.sh` (distributed with kit). When setting up new projects, copy from existing `tests/test-release-check.sh`, not from this template.

<!-- §New Project Setup Procedure removed — duplicate of §New Project Setup at line 829. Single-source-of-truth: that section already loads .portable-spec-kit/skills/project-setup.md. -->


