# Skill: Project Setup
> Loaded when: User asks to create a new project, on project entry (auto-scan), or existing project setup. Templates in `.portable-spec-kit/skills/templates.md`.

---

## New Project Setup Procedure

When user asks to create a new project, follow these steps IN ORDER:

**Step 1: Create Directory Structure + All Agent Files (DO THIS IMMEDIATELY — no questions)**
```bash
mkdir -p <project>/{agent,ard,input,output,cache,src,tests,docs}
mkdir -p <project>/agent/{reqs,specs,plans,design,tasks,releases,scripts}
mkdir -p <project>/agent/research/{reqs,specs,plans,design,tasks,releases}
mkdir -p <project>/.portable-spec-kit/{skills,user-profile}
```
Create all agent files using the templates (from `.portable-spec-kit/skills/templates.md` — download from GitHub if not cached).
Create automation scripts in `agent/scripts/`:
- `psk-code-review.sh` — code review (download from GitHub or generate from framework rules)
- `psk-scope-check.sh` — scope drift detection
- `psk-release.sh` — release process executor
- `tests/test-release-check.sh` — R→F→T validation script, then `chmod +x`
- All scripts must be executable (`chmod +x agent/scripts/*.sh`)
Other files:
- `README.md` — project overview (see README template)
- `.gitignore` — general ignores (node_modules, .env, cache/, __pycache__, .next, etc.). **Do NOT add `agent/` for team or open-source projects.**
- `.env.example` — empty placeholder
- `.portable-spec-kit/config.md` — project config with defaults

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

---

## Auto-Scan (On Entering Any Project)

**Important: Confirm project directory first.** The workspace root may not be the actual project directory. Before creating `agent/` files:
1. List visible directories and ask: "Which directory is your project? (Enter = current directory)"
2. If user picks an existing directory → use it as project root
3. If user types a new path (e.g., `src/my-app` or `projects/new-api`) → create it and use as project root
4. If user skips (Enter) → use current workspace root
5. Once confirmed → set up the project inside that directory (agent/ files, README, .gitignore, etc.) and guide through the full project setup flow

When starting work on a project, scan for `<project>/agent/` directory:

**First — check scan state and show kit status** (see Step 0 in Existing Project Setup below). This runs **once at session start** (when the agent first loads), not on every message.

1. If `agent/` directory is missing → create it **in the confirmed project directory**
2. Check for required files — all pipeline + support files as defined in the current framework version. If any are missing, create from template. If new files were added in a framework update (e.g., REQS.md, RESEARCH.md, DESIGN.md added in v0.5), create them now — the File Creation/Update Rule handles this automatically.
3. Check for required directories — all pipeline subdirs (reqs/, specs/, plans/, design/, tasks/, releases/, research/ with stage subdirs, scripts/) and .portable-spec-kit/skills/. Create any missing directories.
4. **Migration from older versions:**
   - `PLANNING.md` exists but `PLANS.md` doesn't → rename `PLANNING.md` to `PLANS.md` (preserve content)
   - `agent/sync.sh` exists at root → move to `agent/scripts/sync.sh`
   - `agent/plans/` exists but `agent/design/` doesn't → rename `agent/plans/` to `agent/design/`
   - `.portable-spec-kit/reference/` exists → rename to `.portable-spec-kit/skills/`
   - Any old file pattern → migrate to new structure, never delete, always preserve content
5. Apply the **File Creation/Update Rule** to each agent file and `README.md`
4. Read `agent/AGENT.md` + `agent/AGENT_CONTEXT.md` for project context
5. Update `agent/AGENT_CONTEXT.md` at end of every session

---

## Existing Project Setup (IMPORTANT — Guide, Don't Force)

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

   [x] Create agent/ directory with all management files (pre-filled from scan)
   [x] Create WORKSPACE_CONTEXT.md
   [ ] Rename ARD/ → ard/ (to match kit convention)
   [ ] Create .env.example from existing .env
   [ ] Restructure README.md to match template
   [ ] Enable CI/CD (disabled by default — say `enable ci` when ready)

   "Which changes would you like? Select all, some, or none."
   ```
7. **Respect user's choices** — if user says "don't restructure README" or "keep my directory names", follow that
8. **Only create agent/ files by default** — the management files are always safe to add
9. **Never rename, move, or delete existing files** without explicit user approval

**Scan edge cases:**
- **No recognizable stack** (no config files found) → ask: "What stack is this project using?"
- **Multiple stacks detected** (monorepo) → ask which subdirectory to set up first, handle each separately
- **Conflicting signals** (e.g. package.json says React, tsconfig suggests Angular) → flag to user before filling AGENT.md
- **.env file present** → read variable names only to document in AGENT.md; never read or expose values
- **Existing README.md** → read it to supplement scan findings; never overwrite without user approval
- **Very large project** (100+ files) → scan config files and top-level dirs first, then sample src/ structure; don't read every file
- **Team project — agent/ files committed by someone else** → treat as already scanned; read and use existing context, don't overwrite

---

## File Creation/Update Rule (applies to ALL auto-managed files)

This rule applies to: `WORKSPACE_CONTEXT.md`, `README.md`, and all `agent/` files. **Check immediately when version change is detected** — don't wait for next session. When the framework is updated (user pulls new version), restructure immediately in the current conversation.

- **If file does not exist** → create it using the standard template from `.portable-spec-kit/skills/templates.md` (or from embedded templates if skills not cached yet). Fill in known details from project scan.
- **If file exists but doesn't match template structure** → restructure to match current template while **retaining all existing content and key details** — never lose data, only reorganize into standard sections. Add new columns/sections from updated template. Never remove existing columns that have data.
- **If directory does not exist** → create it. Pipeline subdirs and research subdirs are created as defined by the current framework version.
- **If framework was updated** → compare `<!-- Framework Version -->` in portable-spec-kit.md against `**Kit:**` in agent/AGENT_CONTEXT.md. If different, OR if `**Kit:**` field is missing (first time after kit update):
  1. **Do NOT ask** — kit version updates are automatic, not optional. Restructure immediately.
  2. Create any NEW files defined in the updated framework that don't exist yet (use templates)
  3. Create any NEW directories defined in the updated framework that don't exist yet
  4. Restructure all EXISTING agent/ files against current templates — preserve all existing content, add new sections/columns from updated templates
  5. Run migration checks (rename old file patterns to new — see Auto-Scan migration rules)
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

---

## New Project Directory Structure

When creating a **brand new** project, create with ALL of these files and directories:

```
<project>/
│
├── agent/                 ← Project management files (AI reads these)
│   ├── AGENT.md           ← Project-specific AI instructions (stack, rules)
│   ├── AGENT_CONTEXT.md   ← Living project state (updated every session)
│   ├── SPECS.md           ← WHAT to build (requirements, features)
│   ├── PLANS.md           ← HOW to build it (architecture, ADL index)
│   ├── TASKS.md           ← Task tracking (checkboxes)
│   ├── RELEASES.md        ← Version log, deployments, history
│   ├── design/            ← Per-feature design plans (auto-created per feature)
│   │   └── f{N}-feature-name.md
│   └── scripts/           ← All bash scripts (sync, jira, tracker, installer)
│       ├── sync.sh
│       ├── psk-jira-sync.sh
│       ├── psk-tracker.sh
│       ├── install-tracker.sh
│       └── uninstall-tracker.sh
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
