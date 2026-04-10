# Portable Spec Kit — Spec-Persistent Development

**Spec-Persistent Development — a lightweight, zero-install, personalized framework for AI-assisted engineering.**

> Drop one file into any project. Your AI agent personalizes to you, maintains living specifications throughout development, learns and follows your engineering practices, and preserves context across sessions — specs always exist, always current, never block.

[![Version](https://img.shields.io/badge/version-v0.5.2-blue.svg)](portable-spec-kit.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-848%20passing-brightgreen.svg)](tests/)
[![Changelog](https://img.shields.io/badge/changelog-CHANGELOG.md-lightgrey.svg)](CHANGELOG.md)
<!-- CI badge — CI/CD disabled in .portable-spec-kit/config.md. Enable: say "enable ci"
[![CI](https://github.com/aqibmumtaz/portable-spec-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/aqibmumtaz/portable-spec-kit/actions/workflows/ci.yml)
-->

<table>
<tr>
<td width="25%" align="center"><strong>🪶 Lightweight</strong><br><sub>Single markdown file<br>Zero dependencies<br>Zero install</sub></td>
<td width="25%" align="center"><strong>📦 Portable</strong><br><sub>One file → any repo<br>Works instantly<br>Symlinks for all agents</sub></td>
<td width="25%" align="center"><strong>👤 Personalized</strong><br><sub>GitHub profile auto-detect<br>Adapts to your expertise<br>Tailored AI behavior</sub></td>
<td width="25%" align="center"><strong>📋 Spec-Persistent</strong><br><sub>SPECS → Design → Architect → Build → Release<br>Every feature gets a design plan<br>Your workflow, your choice</sub></td>
</tr>
<tr>
<td width="25%" align="center"><strong>🤖 Agent-Agnostic</strong><br><sub>Claude · Copilot · Cursor<br>Windsurf · Cline<br>One source, all agents sync</sub></td>
<td width="25%" align="center"><strong>🧠 Context-Persistent</strong><br><sub>Remembers across sessions<br>Pick up after weeks<br>Never lose context</sub></td>
<td width="25%" align="center"><strong>🔒 Secure</strong><br><sub>Never expose API keys<br>Strict .env rules<br>Code security enforced</sub></td>
<td width="25%" align="center"><strong>🔄 Non-Blocking</strong><br><sub>Code first, specs later<br>Agent tracks silently<br>Never blocks the developer</sub></td>
</tr>
<tr>
<td width="25%" align="center"><strong>🏗️ Self-Scaffolding</strong><br><sub>Auto-creates 6 agent files<br>8 stack templates built-in<br>Ready to code in seconds</sub></td>
<td width="25%" align="center"><strong>✅ Self-Validating</strong><br><sub>Agent tests everything<br>Fixes before presenting<br>98%+ coverage target</sub></td>
<td width="25%" align="center"><strong>🧪 Automated Test Generation</strong><br><sub>Criteria → stubs instantly<br>Stack-aware formats<br>Stub gate blocks incomplete work</sub></td>
<td width="25%" align="center"><strong>🔁 CI/CD Ready</strong><br><sub>GitHub Actions auto-setup<br>Stack-aware test commands<br>R→F→T gate enforced in CI</sub></td>
</tr>
</table>

> **Inspired by GitHub's [spec-kit](https://github.com/github/spec-kit).** A different philosophy — specs persist alongside your code, maintained by the agent, never blocking. No CLI install, no Python dependency, no package managers. One file — zero friction.

---

## What's New in v0.5

**Jira Cloud integration** — Sync completed tasks to Jira via `psk-jira-sync.sh` (REST API v3). Automatic hours tracking with Track A (agent session) + Track B (psk-tracker OS daemon). 10 new commands. Explicit-only — never syncs automatically.

**Feature Design Pipeline** — Every feature gets a design plan in `agent/design/f{N}.md`. Three triggers: explicit ("plan F3"), auto on SPECS.md, implementation gate. Decisions auto-flow to PLANS.md ADL.

**Auto Code Review** — Two-layer review (psk-code-review.sh + AI judgment) runs after every feature completion. Security anti-patterns, naming, TODO, secrets, architecture compliance. Advisory, not blocking.

**Scope Drift Detection** — 5-dimension drift check (feature drift, requirement gaps, scope creep, architecture drift, plan staleness). Proactive at session start. psk-scope-check.sh with drift score.

**Release pipeline expanded** — Now 9 steps (added code review + scope check). Release summary shows 11 rows.

| What's new | Details |
|------------|---------|
| Jira sync (F63) | `psk-jira-sync.sh`, `psk-tracker.sh`, 10 commands, Track A/B hours, PID lock |
| Feature Design (F64) | `agent/design/` directory, 3 triggers, plan template, ADL Plan Ref column |
| Auto Code Review (F65) | `psk-code-review.sh` + AI layer, advisory, added to release pipeline Step 2 |
| Scope Drift (F66) | `psk-scope-check.sh`, 5 dimensions, drift score, added to release pipeline Step 3 |
| Agent directory structure | `agent/` root = markdown only, `design/` = plans, `scripts/` = bash |
| Orchestration table | 37 items across 8 groups with trigger types (explicit/auto/continuous) |
| **848 tests** (was 781) | Section 51: 28 Jira · Section 52: 15 code review · Section 53: 12 scope drift |

---

## What's New in v0.4

**CI/CD pipeline** — Every project using the kit now gets GitHub Actions CI automatically during setup (Step 7.5). The agent generates `.github/workflows/ci.yml` with stack-aware test commands (Jest, pytest, Go, Bash). The R→F→T validator (`test-release-check.sh`) is always included — specs validation runs in CI, not just locally.

**Spec-based test generation** — When you write acceptance criteria for a feature in SPECS.md, the agent generates test stubs immediately (forward flow only). Per-feature `### F{n}` format keeps criteria next to the feature they describe. The stub completion gate prevents marking a feature done while test stubs are unfilled.

| What's new | Details |
|------------|---------|
| GitHub Actions: `ci.yml` + `release.yml` | Runs all 3 test suites on push/PR; verifies tag on release |
| CI/CD framework rules | `ci.yml` template, Step 7.5 in New Project Setup, stack-aware commands, Existing Project Setup CI checklist item |
| CI & Community Contributions section | CI badge rule, branch protection guidance, PR workflow, contribution validation |
| Spec-based test generation (8 rules) | SPECS origin detection, per-feature criteria format, stub trigger, stack-aware stubs, stub completion gate |
| `check_stub_complete()` in `test-release-check.sh` | Blocks release if test stubs contain unfilled TODO markers |
| Community files | PR template, bug report + feature request issue templates |
| Cross-platform sed fix | `test-spd-benchmarking.sh` now runs on Ubuntu (GitHub Actions) |
| **641 tests** (was 597) | Section 42: 29 CI/CD tests · Section 43: 15 spec-gen tests |

---

## The Methodology: Spec-Persistent Development

**Specs always exist and stay current, but never block.**

Traditional approaches force a choice: write specs first (waterfall) or skip them (agile). Spec-Persistent Development is the first methodology native to the AI era — specifications persist throughout development, maintained by the AI agent, evolving with your code, never gating your work.

| | **Waterfall** | **Agile** | **Spec-First** (spec-kit) | **Spec-Persistent** (this kit) |
|---|:---:|:---:|:---:|:---:|
| **Specs exist?** | Yes, upfront | Often no | Yes, formal | **Always — living documents** |
| **Specs block code?** | Yes | No | Yes | **Never** |
| **When written?** | Before code | Rarely | Before code | **Before, during, or after** |
| **Who maintains?** | Humans | Humans (skip) | Humans | **Agent (90%)** |
| **Context persists?** | In docs | In people's heads | Per-session | **Across sessions, weeks, months** |
| **Your workflow** | Sequential | Iterative | 6-phase | **Your choice — any style** |

### The Framework Doesn't Enforce a Methodology

You choose how you work. The kit adapts:

- **Want waterfall?** Follow SPECS → Design Plans → Architecture → TASKS → RELEASES sequentially. The kit supports it.
- **Want agile?** Jump into coding. The agent tracks tasks, fills specs and plans retroactively.
- **Want a mix?** Write rough specs, start coding, refine as you go. The agent keeps everything in sync — plans included.
- **Want to change mid-project?** Started agile but need specs now? The agent fills them from what's built.

The only constant: **specs persist**. However you work, the agent ensures SPECS.md, PLANS.md, TASKS.md, and RELEASES.md always reflect the current state of your project.

### Critical Scenarios Where This Changes Everything

**New machine, same project.** Clone the repo, open a new AI chat, ask: *"What's the project status?"* The agent reads your spec files and delivers a full briefing — what's built, what's pending, every architectural decision and why. Zero re-explaining. Zero context reconstruction.

| Scenario | Without Kit | With Kit |
|----------|------------|---------|
| New machine / fresh install | Re-explain entire project from scratch | Clone repo → agent reads context → continue instantly |
| Returning after weeks | "Wait, where were we?" — rebuild context manually | Agent reads AGENT_CONTEXT.md → full picture in seconds |
| Forced agent switch | Context lost — Claude → Copilot means starting over | All agents read same files → zero loss |
| Computer crash or wipe | Project context gone | Push to git → pull → fully restored |
| Team member leaves | Knowledge walks out the door | All decisions, reasoning, scope changes preserved in PLANS.md |
| New developer onboards | Weeks of code archaeology | Clone → read agent files → full history understood in minutes |
| Client hands off project | New team guesses at intent | R→F traceability: every requirement → feature → decision recorded |
| Context window fills | Start new chat, lose all context | New chat → agent reads files → continues seamlessly |

---

## The Problem

AI coding agents are powerful but inconsistent. Every new conversation starts from zero — no context, no standards, no memory of decisions. You end up repeating yourself: "use TypeScript", "test everything", "don't commit secrets", "track tasks in markdown"...

**Existing approaches vary.** GitHub's [spec-kit](https://github.com/github/spec-kit) is a comprehensive spec-first solution requiring Python 3.11+, a CLI tool, and package managers. It follows a structured 6-phase workflow. Portable Spec Kit takes a different approach — lighter, more flexible, and personalized.

## The Solution

**One markdown file. Zero dependencies. Zero install. Works with every AI agent.**

### Setup

#### Ask your AI agent (no terminal needed)
Paste this to Claude, Cursor, Copilot, or any AI agent:

**macOS / Linux:**
```
Install the Portable Spec Kit: run `curl -sO https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/portable-spec-kit.md && ln -sf portable-spec-kit.md CLAUDE.md && ln -sf portable-spec-kit.md .cursorrules && ln -sf portable-spec-kit.md .windsurfrules && ln -sf portable-spec-kit.md .clinerules && mkdir -p .github && ln -sf ../portable-spec-kit.md .github/copilot-instructions.md` then read portable-spec-kit.md and set up my project.
```

**Windows:**
```
Install the Portable Spec Kit: run `Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/portable-spec-kit.md" -OutFile "portable-spec-kit.md"; Copy-Item portable-spec-kit.md CLAUDE.md; Copy-Item portable-spec-kit.md .cursorrules; Copy-Item portable-spec-kit.md .windsurfrules; Copy-Item portable-spec-kit.md .clinerules; New-Item -ItemType Directory -Force -Path .github | Out-Null; Copy-Item portable-spec-kit.md .github/copilot-instructions.md` then read portable-spec-kit.md and set up my project.
```

The agent downloads the kit, creates all agent files, reads the framework, and starts your project setup — all in one go.

#### macOS / Linux (one command)
```
curl -sO https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/portable-spec-kit.md && ln -sf portable-spec-kit.md CLAUDE.md && ln -sf portable-spec-kit.md .cursorrules && ln -sf portable-spec-kit.md .windsurfrules && ln -sf portable-spec-kit.md .clinerules && mkdir -p .github && ln -sf ../portable-spec-kit.md .github/copilot-instructions.md
```

#### Windows (PowerShell)
```
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/portable-spec-kit.md" -OutFile "portable-spec-kit.md"; Copy-Item portable-spec-kit.md CLAUDE.md; Copy-Item portable-spec-kit.md .cursorrules; Copy-Item portable-spec-kit.md .windsurfrules; Copy-Item portable-spec-kit.md .clinerules; New-Item -ItemType Directory -Force -Path .github | Out-Null; Copy-Item portable-spec-kit.md .github/copilot-instructions.md
```

**What happens:** Downloads `portable-spec-kit.md` and creates symlinks (Mac/Linux) or copies (Windows) for every supported agent. Edit one file — all agents stay in sync.

**What happens after install — the kit takes over:**

1. **Personalized profile** — fetches your GitHub identity, asks 3 quick preferences, adapts to your expertise
2. **Project setup** — scans your codebase, creates 6 management files in `agent/`, detects your stack
3. **Guided tour** — 4-step interactive walkthrough (under 1 minute): your project, how to work, your settings, getting help
4. **Ready to build** — just describe what you want. The kit tracks specs, plans, tasks, tests, and releases automatically

After setup, the kit stays present:
- **Every session** — greets you by name, shows pending tasks, flags scope issues
- **At every milestone** — acknowledges progress, suggests next steps
- **When you're stuck** — say `"help"` and the kit shows exactly what you can do right now
- **When you need guidance** — say `"how do I...?"` and it walks you through step by step
- **You never memorize commands** — the kit knows what's relevant and surfaces it contextually

---

## How It Compares

| | **spec-kit** (GitHub) | **portable-spec-kit** |
|---|:---:|:---:|
| **Setup** | Python 3.11+, `uv`, CLI install, config | **Drop 1 file** |
| **Dependencies** | Python, uv, templates, extensions | **None** |
| **Install time** | Minutes (download Chromium, Python packages) | **Seconds** (one curl) |
| **Files generated** | 2,500+ lines per feature | **6 lean files** |
| **Learning curve** | Moderate — 6-phase workflow | **Zero** — start coding, agent tracks |
| **Rigidity** | Sequential, spec-before-code | **Flexible** — code first, specs retroactively |
| **Blocking** | Must complete specs before implementation | **Never blocks** — work however you want |
| **AI agents** | 30+ with config per agent | **Any AI** — zero-config symlinks for all |
| **Execution time** | 33+ min agent + hours review | **Instant** — read file, start working |
| **Context persistence** | Per-session | **Cross-session** — AGENT_CONTEXT.md |
| **Portability** | Per-project setup required | **One file across all projects** |
| **Spec overhead** | Thousands of lines of formal spec | **Lightweight specs** — as detailed as you need |

---

## Multi-Agent Support

One source file — `portable-spec-kit.md` — works with every AI coding agent:

| Agent | File Created | How |
|-------|-------------|-----|
| **Claude Code** | `CLAUDE.md` | Symlink → portable-spec-kit.md |
| **GitHub Copilot** | `.github/copilot-instructions.md` | Symlink → portable-spec-kit.md |
| **Cursor** | `.cursorrules` | Symlink → portable-spec-kit.md |
| **Windsurf** | `.windsurfrules` | Symlink → portable-spec-kit.md |
| **Cline** | `.clinerules` | Symlink → portable-spec-kit.md |

Edit `portable-spec-kit.md` once — all agents read the update instantly (via symlinks on Mac/Linux, copies on Windows).

---

## Complete Flow

### Step 1: Install (one command)

See setup commands above (macOS/Linux or Windows). Downloads `portable-spec-kit.md` and creates symlinks for all agents.

**Result:**
```
your-project/
├── portable-spec-kit.md                  ← Source (edit this one)
├── CLAUDE.md → portable-spec-kit.md      ← Claude Code
├── .cursorrules → portable-spec-kit.md   ← Cursor
├── .windsurfrules → portable-spec-kit.md ← Windsurf
├── .clinerules → portable-spec-kit.md    ← Cline
└── .github/copilot-instructions.md → portable-spec-kit.md ← Copilot
```

### Step 2: Open any AI agent — the kit takes you through setup

The agent reads the framework and guides you through everything:

```
✓ Profile setup — GitHub auto-detect + 3 quick preferences
✓ Project scan — detects stack, creates agent/ files, README, .gitignore
✓ Config created — .portable-spec-kit/config.md with defaults
✓ Guided tour — 4-step interactive walkthrough:
    1. Your project (what's set up, what's tracked)
    2. How to work (just talk naturally — the kit handles the rest)
    3. Your settings (what's enabled, how to change)
    4. Getting help (say "help" anytime — the kit guides you)
✓ Ready to build!
```

### Step 3: Just work — the kit stays with you

```
You: "Build me a login page"
Kit: Plans it → builds it → tests it → tracks it → done ✓

You: "What should I do next?"
Kit: Shows your pending tasks and suggests the next action

You: "help"
Kit: Shows exactly what you can do right now, based on your project state

You: "How do I release?"
Kit: Walks you through step by step — one step at a time
```

The kit never gets in your way. It tracks silently, helps when asked, and suggests features when relevant — all derived from your current project state, always up to date.

### Step 4: Context stays current

The agent updates `agent/AGENT_CONTEXT.md` at three natural checkpoints — not on a timer:

```
✓ After significant work (feature built, tests passing)
✓ After committing — commit is a natural checkpoint
✓ Before any push — context must be current before code reaches remote
```

### Step 5: Come back later (days, weeks, months)

```
✓ Agent reads agent/AGENT.md + agent/AGENT_CONTEXT.md
✓ "Here's where we left off — v0.1 has 8/12 tasks done. Next: payment integration."
✓ Continues exactly where you stopped
```

### Step 6: Edit the framework

```
✓ Edit portable-spec-kit.md — all 5 agent symlinks read the update instantly
✓ Your standards evolve with you across all projects
```

---

## The Framework

### The Agent Directory (auto-created in `agent/`)

| File / Dir | Purpose | Updated When |
|------------|---------|-------------|
| `AGENT.md` | Project rules, stack, brand, AI config, Jira config | Stack or config changes |
| `AGENT_CONTEXT.md` | Living state — done, next, decisions, blockers, time tracking | After significant work, after commit, before push |
| `SPECS.md` | Requirements, features, acceptance criteria | Feature added, scope change, feature marked done |
| `PLANS.md` | Architecture summary, ADL index (links to design files) | Architecture or tech decision changes |
| `TASKS.md` | Version-based task tracking with checkboxes | Before every task (add) + after every task (mark done) |
| `RELEASES.md` | Version changelog, test results, deployment log | When all tasks under a version are done |
| `design/` | Per-feature design plans (`f{N}-name.md`) | Auto-created per feature in SPECS.md |
| `scripts/` | All bash scripts (sync, Jira, tracker, installer) | Created during setup or on first use |

### Project Structure

```
your-project/
├── portable-spec-kit.md    ← The framework (source file)
├── .portable-spec-kit/     ← Kit config (committed)
│   ├── config.md           ← Project config (CI/CD, Jira, toggles)
│   └── user-profile/
│       └── user-profile-{username}.md
├── CLAUDE.md               ← Symlink (Claude Code)
├── .cursorrules            ← Symlink (Cursor)
├── WORKSPACE_CONTEXT.md    ← Auto-created (workspace state)
├── README.md               ← Auto-created (standard structure)
│
├── agent/                  ← Auto-created (project management)
│   ├── AGENT.md            ← Project rules, stack, config
│   ├── AGENT_CONTEXT.md    ← Living state (updated every session)
│   ├── SPECS.md            ← Features + requirements
│   ├── PLANS.md            ← Architecture + ADL index
│   ├── TASKS.md            ← Task tracking
│   ├── RELEASES.md         ← Version changelog
│   ├── design/             ← Per-feature design plans
│   │   └── f{N}-name.md
│   └── scripts/            ← All bash scripts
│       ├── sync.sh
│       └── psk-jira-sync.sh  (+ tracker scripts if installed)
│
├── src/                    ← Your code
├── tests/
│   ├── test-release-check.sh ← R→F→T validator (auto-created by kit)
│   └── ...                 ← Your tests
└── ...
```

---

## Development Guidelines

### The Pipeline

```
SPECS.md  →  agent/design/  →  PLANS.md  →  TASKS.md  →  RELEASES.md
 Define       Design            Architect     Build         Release
```

| Step | File | What it does |
|------|------|-------------|
| **Define** | `SPECS.md` | What to build — features, requirements, acceptance criteria |
| **Design** | `agent/design/f{N}.md` | How to build each feature — approach, decisions, edge cases, scope exclusions |
| **Architect** | `PLANS.md` | Project-wide architecture — stack, data model, ADL index (links back to design files) |
| **Build** | `TASKS.md` | Execute — track work, assign owners, mark done |
| **Release** | `RELEASES.md` | Record what shipped — version, changes, test results |

Every decision traceable backwards: Release → Task → Design → Feature → Requirement.

Enter at any point. Start from specs, start from code, or start mid-project — the agent fills whatever's missing.

### Which Agent File Updates When

| File | Updates When |
|------|-------------|
| `agent/AGENT.md` | Stack changes, new project rules, config changes (port, API provider, brand) |
| `agent/AGENT_CONTEXT.md` | After significant work, after committing, before any push |
| `agent/SPECS.md` | New feature added, scope change (DROP/ADD/MODIFY/REPLACE), feature marked done (fill Tests column) |
| `agent/PLANS.md` | Architecture changes — new tech chosen, data model updated, API endpoints added/modified. ADL updated when feature plans record decisions |
| `agent/design/f{N}.md` | Auto-created when feature added to SPECS.md. Filled during design. Marked "Done" when feature complete |
| `agent/TASKS.md` | Before every task (add it first), after every task (mark [x] when done) |
| `agent/RELEASES.md` | When all tasks under a version heading are [x] — entry added immediately, same session |

### Spec Kit Orchestration

Everything the agent does — automatically or on command. All natural language, no slash commands needed.

| Category | Command | What happens | Trigger |
|----------|---------|-------------|---------|
| | | **Setup & Context** | |
| **Project Setup** | `"init"` | Deep scan → create/fill all agent/ files → optional changes checklist | Explicit |
| | `"reinit"` | Re-scan → sync stale agent files → SPECS/PLANS staleness check | Explicit |
| **Config** | `"show config"` / `"config"` | Show all toggles + interactive toggle by number or name | Explicit |
| | `"enable [name]"` / `"disable [name]"` | Quick toggle any setting: ci, jira, code review, scope check | Explicit |
| | | **Define & Design** | |
| **Development** | `"build X"` / `"add feature X"` | Added to TASKS.md → built → tested → marked done | Explicit |
| | `"fix X"` | Added to TASKS.md → fixed → marked done | Explicit |
| | `"what's the status?"` | Reads TASKS.md + AGENT_CONTEXT.md → full progress report | Explicit |
| | `"keep noted"` / `"note this"` | Saved to correct agent/ file — never lost | Explicit |
| **Feature Design** | `"plan F3"` / `"design F3"` | Creates/opens `agent/design/f3-name.md` — fills from conversation | Explicit |
| | *(auto)* Feature added to SPECS.md | Design stub auto-created in `agent/design/f{N}-name.md` | Auto |
| | `"implement F3"` / `"start F3"` | **Gate:** checks design exists → if not, creates + fills first → then builds | Explicit + Gate |
| **Test Generation** | *(auto)* Acceptance criteria written | Test stubs generated from SPECS.md criteria (stack-aware) | Auto |
| | | **Continuous (always running)** | |
| **Task Tracking** | *(auto)* Every user message | No-slip rule: scan for tasks, add to TASKS.md, never let anything slip | Continuous |
| **Time Tracking** | *(auto)* Every agent response | Track A (session time) updated per-response in AGENT_CONTEXT.md | Continuous |
| **Context Updates** | *(auto)* After significant work | AGENT_CONTEXT.md updated: version, phase, what's done, what's next | Auto |
| **Spec Staleness** | *(auto)* On detection | If TASKS.md [x] count > SPECS.md features → update SPECS.md | Auto |
| **ADL Sync** | *(auto)* Design decisions made | Decisions from agent/design/ auto-flow to PLANS.md ADL with Plan Ref | Auto |
| **Rename Check** | *(auto)* During rename/refactor | `grep -r` entire repo for old term → every instance updated | Auto |
| | | **Quality Gates** | |
| **Code Review** | *(auto)* Feature completed | Two-layer review (script + AI) before marking [x] — advisory | Auto |
| | `"review code"` / `"code review"` | Run review manually on current state | Explicit |
| **Scope Check** | *(auto)* Session start | Quick drift check (feature drift + plan staleness) | Auto |
| | `"check scope"` / `"scope check"` | Full 5-dimension drift check on demand | Explicit |
| | | **Progress & Team** | |
| **Dashboard** | `"progress"` / `"dashboard"` / `"burndown"` | Progress dashboard: overall · by version · current tasks · blockers | Explicit |
| **Team Tasks** | `"my tasks"` / `"what do I have"` | Per-user task view filtered by @username | Explicit |
| | `"assign [task] to @username"` | Adds @username tag to task in TASKS.md | Explicit |
| | `"unassign @username from [task]"` | Removes @username tag from task | Explicit |
| | | **Release Pipeline** | |
| **Testing** | `"run tests"` | Run all suites → show failure summary + fix plan. No commits. | Explicit |
| **Release** | `"prepare release"` | 9-step pipeline: tests → code review → scope check → flows → counts → version bump → PDFs → RELEASES → CHANGELOG. **No commit. No push.** | Explicit |
| | `"refresh release"` | Same as prepare release — **no version bump** | Explicit |
| | `"prepare release and push"` | Full pipeline → commit → push → GitHub release. One command. | Explicit |
| | `"refresh release and push"` | Same as above but no version bump | Explicit |
| **Git** | `"commit"` | Stage + commit with descriptive message + `Co-Authored-By` | Explicit |
| | `"push"` | Pre-push gate (runs tests if changes since last release) → push | Explicit |
| | | **Jira Integration (optional)** | |
| **Jira Sync** | `"sync to jira"` | Full 8-step sync: hours confirmation → push to Jira Cloud | Explicit |
| | `"jira status"` | Show tasks pending sync + hours (no API calls, read-only) | Explicit |
| | `"jira setup"` | Test connection, map issue types, configure mappings | Explicit |
| | `"link jira PROJ-123"` | Tag active task with Jira ticket ID | Explicit |
| | `"unlink jira from [task]"` | Remove Jira ticket tag from task | Explicit |
| **Time Tracking** | `"install tracker"` | Install psk-tracker OS daemon + register project | Explicit |
| | `"uninstall tracker"` | Stop daemon, remove OS service (logs preserved) | Explicit |
| | `"tracker status"` | Show daemon running/stopped, last event, today's minutes | Explicit |
| | `"start working on [task]"` | Explicit task-start marker — improves time attribution | Explicit |
| | `"hours summary"` | Show Track A + Track B breakdown for current session | Explicit |

**Every `prepare release` / `refresh release` ends with this summary:**
```
══════════════════════════════════════════════
  RELEASE SUMMARY — v0.N.x
══════════════════════════════════════════════
  1. Tests        Framework: X passed ✅  Benchmarking: X passed ✅
                  R→F→T: X/X features release-ready ✅
                  Total: X/X passing ✅
  2. Code Review  X passed, Y issues (advisory) ✅/⚠
  3. Scope Check  drift score: N ✅/⚠
  4. Flows        docs/work-flows/ current ✅
  5. Counts       README, ARD, RELEASES, CHANGELOG ✅
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
The release is only finalized if all test suites pass. Any failure → show failure summary + fix plan → fix → re-run.

### Key Principles

| Principle | What it means |
|-----------|--------------|
| **Never blocks** | Start coding immediately — specs can be written before, during, or filled retroactively |
| **Context never lost** | `AGENT_CONTEXT.md` tracks what's done, what's next, and every decision. Come back after weeks and pick up instantly |
| **Tasks first** | Every task gets added to TASKS.md before work starts — nothing slips |
| **Self-validating** | Agent writes tests, runs them, fixes failures before presenting results. You should never discover a broken feature |
| **90/10 split** | Agent does 90% — specs, plans, tasks, tests, docs. You review and approve |
| **One file, all projects** | `portable-spec-kit.md` carries your standards across every project. Project-specific rules go in `agent/AGENT.md` |

### File Management Rule

| Scenario | Action |
|----------|--------|
| Agent file doesn't exist | Created from template, known details filled in |
| Agent file exists but wrong structure | Restructured to match template — **all content preserved** |
| Agent file matches template | Left as-is |

Content is never lost. Existing files are reorganized, not overwritten.

---

## What's Inside portable-spec-kit.md

| Section | What It Governs |
|---------|----------------|
| **User Profile** | Personalized AI — GitHub auto-detect, communication style, working pattern, AI delegation |
| **Project Config** | `.portable-spec-kit/config.md` — CI/CD, Jira, code review, scope drift toggles. Disabled-by-default CI. Review anytime. |
| **Git & GitHub** | Commit rules, push rules, critical ops requiring approval |
| **Security** | .env handling, secret management, code security practices |
| **Versioning** | Two-level: framework patches + release milestones, auto-restructure on pull |
| **Task Tracking** | Tasks-first workflow, version-based organization (v0.x headings + backlog) |
| **Feature Planning** | Every feature gets a plan (`agent/design/f{N}.md`), 3 triggers (explicit/auto/gate), decisions auto-flow to ADL, R→F→Plan→ADR→T traceability |
| **Auto Code Review** | Two-layer review (psk-code-review.sh + AI judgment) after feature completion — security, naming, TODO, secrets, architecture compliance; advisory not blocking |
| **Scope Drift Detection** | 5 dimensions (feature drift, requirement gaps, scope creep, architecture drift, plan staleness), drift score, proactive at session start |
| **Testing** | Coverage targets, edge case checklist, mock rules, self-validation |
| **Spec-Based Test Generation** | SPECS origin detection (forward vs retroactive), per-feature acceptance criteria, stub generation, stack-aware formats, stub completion gate |
| **Code Quality** | Review checklist, naming conventions, deployment checklist |
| **Error Handling** | Structured errors, logging, error boundaries, user-friendly messages |
| **Branch & PR** | Feature branches, PR format, squash merge, clean history |
| **CI & Community Contributions** | CI badge rule, branch protection guidance, PR workflow, contribution validation, ci.yml template with stack-aware commands (Jest/pytest/Go/Bash) |
| **Python Environment** | Conda env per project (respects existing venv), environment selection flow, pyproject.toml/environment.yml support, 9 edge cases |
| **Dependencies** | Bundle size checks, lock files, audit, avoid unnecessary deps |
| **Project Templates** | 6 agent files + README + 8 source code structures (Web, Python, Mobile, Android, iOS, Full Stack, Full Stack + Mobile, Document) |
| **Auto-Scan** | Detects projects, creates/restructures files, preserves existing content |
| **Agent Behavior** | Guide don't enforce, silent tracking, retroactive spec-filling |

---

## Customization

### User Profile — Personalized AI Experience

On first session, the agent creates your profile by fetching your GitHub identity and asking 3 quick questions. Press Enter to use recommended, or type your own:

```
Agent: "Welcome, Jane Smith! Let me set up your development profile."

Communication style?
  (a) direct and concise ← RECOMMENDED
  (b) direct, data-driven, comprehensive with tables and evidence
  (c) conversational and collaborative
  (or type your own)
  Press Enter to use recommended (a)

Working pattern?
  (a) iterative — starts brief, expands scope, builds ambitiously ← RECOMMENDED
  (b) plan-first — full specs and architecture before writing code
  (c) prototype-fast — get something working, then refine
  (or type your own)
  Press Enter to use recommended (a)

AI delegation?
  (a) AI does 70%, user guides 30% ← RECOMMENDED
  (b) AI does 90%, user reviews 10%
  (c) 50/50 collaboration
  (or type your own)
  Press Enter to use recommended (a)

Your profile:
┌─────────────────────────────────────┐
│ Jane Smith — B.S. CS. Full-stack.   │
│ Communication: direct and concise   │
│ Working pattern: iterative          │
│ AI delegation: AI does 70%          │
└─────────────────────────────────────┘
Looks good? (Enter = yes, or type changes)
```

**Saved to:**
- `~/.portable-spec-kit/user-profile/user-profile-janesmith.md` (global — asked once)
- `workspace/.portable-spec-kit/user-profile/user-profile-janesmith.md` (committed — persists across pulls)

**On new projects:** profile is shown, keep or customize per project. Customized profiles save to workspace only.

| What You Set | How the Agent Adapts |
|---|---|
| **Your expertise** (e.g., "PhD in AI" vs "first-time coder") | Adjusts technical depth, skips/explains concepts |
| **Communication style** | Uses tables & evidence vs. conversational |
| **Working pattern** | Adapts planning granularity |
| **AI delegation** | Controls autonomy vs. asking for approval |

Skip all questions? Press Enter through everything — recommended defaults applied.

### For Your Projects

Project-specific details go in `agent/AGENT.md` (auto-created per project):

```markdown
## Stack
| Layer | Technology |
|-------|-----------|
| Frontend | Next.js + TypeScript |
| Backend | FastAPI |

## Brand
- Primary: #1B2A4A
- Accent: #4a6fa5
```

---

## Syncing Across Projects

### Pull Latest

```bash
# In any project
curl -sO https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/portable-spec-kit.md
```

### Push Updates Back

When you improve portable-spec-kit.md from any project:

```bash
# Copy to your fork
cp portable-spec-kit.md ~/portable-spec-kit/
cd ~/portable-spec-kit
git add . && git commit -m "Add new testing rule" && git push
```

### For Teams

Fork this repo → customize portable-spec-kit.md for your team → everyone pulls from your fork.

---

## Usage Examples

### New Project Setup

```
You: "Create a new project called my-app"

Agent:
✓ Created my-app/agent/ with 6 files
✓ Created my-app/README.md
✓ Created my-app/.gitignore + .env.example
✓ Created directories: src/, tests/, ard/, docs/

What would you like to build?
```

### Resuming After Weeks

```
You: "Let's continue working on my-app"

Agent: (reads agent/AGENT_CONTEXT.md)
Here's where we left off:
- v0.2 in progress — 3 of 8 tasks complete
- Last session: built auth system, 45 tests passing
- Next: payment integration (blocked on Stripe key)
- Decision pending: PostgreSQL vs MongoDB

Want to continue with payment integration?
```

### Spec-Persistent Flow (When Asked)

```
You: "How should I approach this project?"

Agent:
Let's follow the spec-persistent process:

1. First, let's define WHAT you want in SPECS.md
   → What are the key features? Who's the user?

2. Then I'll plan HOW to build it in PLANS.md
   → Architecture, data model, phases

3. I'll break it into tasks in TASKS.md
   → Module-by-module with checkboxes

4. I'll track everything in RELEASES.md
   → Version history, test results, deployments

Let's start — what's the core problem this project solves?
```

---

## Contributing

Contributions welcome! This framework improves through real-world usage.

1. Fork the repo
2. Customize portable-spec-kit.md for your workflow
3. Submit a PR with improvements that benefit everyone

**What makes a good contribution:**
- New testing patterns or edge case checklists
- Better project templates
- Agent behavior improvements
- Documentation fixes

---

## Example Projects

### [`examples/starter/`](examples/starter/) — Fresh Project (Start Here)

What your project looks like right after setup. The README explains every file, every directory, and why it exists. **Read this first** to understand how the framework works.

```
examples/starter/
├── portable-spec-kit.md    ← Framework file (source)
├── .portable-spec-kit/     ← Kit config (user profiles)
│   └── user-profile/
├── CLAUDE.md               ← Symlink (Claude Code)
├── .cursorrules            ← Symlink (Cursor)
├── WORKSPACE_CONTEXT.md    ← Auto-created workspace state
├── README.md               ← Self-documenting — explains the entire structure
├── agent/
│   ├── AGENT.md           ← Stack: TBD (waiting for your specs)
│   ├── AGENT_CONTEXT.md   ← Status: "Setup — waiting for specs"
│   ├── SPECS.md           ← Empty template — ready for your requirements
│   ├── PLANS.md        ← Empty template — ready for architecture
│   ├── TASKS.md           ← 1/5 tasks done (project initialized)
│   └── RELEASES.md         ← v0.1 placeholder
```

### [`examples/my-app/`](examples/my-app/) — Mid-Development Project

A realistic Next.js + Supabase project with 11/16 tasks complete. Shows what the framework looks like when you're actively building — filled specs, architecture plan, module-based tasks.

```
examples/my-app/
├── portable-spec-kit.md    ← Framework file (source)
├── .portable-spec-kit/     ← Kit config (user profiles)
│   └── user-profile/
│       └── user-profile-alexchen.md
├── WORKSPACE_CONTEXT.md    ← Workspace state
├── agent/
│   ├── AGENT.md           ← Next.js + Supabase + Vercel configured
│   ├── AGENT_CONTEXT.md   ← v0.1 with 11/16 tasks, 24 tests at 92%
│   ├── SPECS.md           ← 8 features with priorities + acceptance criteria
│   ├── PLANS.md        ← Data model, API endpoints, 3 build phases
│   ├── TASKS.md           ← 5 modules, progress summary table
│   └── RELEASES.md         ← v0.1 changelog with categorized changes
```

---

## Flows

Detailed step-by-step diagrams for every work flow:

| # | Flow | When It Triggers |
|---|------|-----------------|
| 01 | **[First Session in New Workspace](docs/work-flows/01-first-session-workspace.md)** | First time in a workspace — environment detection, auto-scan |
| 02 | **[User Profile Setup](docs/work-flows/02-user-profile-setup.md)** | First time using the kit — GitHub fetch + 3 questions |
| 03 | **[New Project Setup](docs/work-flows/03-new-project-setup.md)** | Creating a new project — profile shown, scaffold created |
| 04 | **[Existing Project Setup](docs/work-flows/04-existing-project-setup.md)** | First-time kit onboarding on a codebase that already exists |
| 05 | **[Project Init & Reinit](docs/work-flows/05-project-init.md)** | `init` / `reinit` commands — explicit scan, agent file sync, staleness check |
| 06 | **[CI/CD Setup](docs/work-flows/06-cicd-setup.md)** | ci.yml generation — stack detection, badge, branch protection |
| 07 | **[Returning Session](docs/work-flows/07-returning-session.md)** | Coming back after days/weeks — context loaded, no questions |
| 08 | **[Agent Switching](docs/work-flows/08-agent-switching.md)** | Switching Claude → Cursor → Copilot — zero data loss |
| 09 | **[Profile Customization](docs/work-flows/09-profile-customization.md)** | Different preferences per project — local override |
| 10 | **[File Management](docs/work-flows/10-file-management.md)** | Create/update/restructure rule — never lose content |
| 11 | **[Spec-Persistent Development](docs/work-flows/11-spec-persistent-development.md)** | SPECS → PLAN → TASKS → TRACK — living specs, any workflow |
| 12 | **[Project Lifecycle](docs/work-flows/12-project-lifecycle.md)** | Full lifecycle — client requirements through handoff |
| 13 | **[Release Workflow](docs/work-flows/13-release-workflow.md)** | prepare release — tests, flow docs, counts, version bump, PDFs, RELEASES.md, CHANGELOG.md + summary (no commit/push) |
| 14 | **[Team Collaboration](docs/work-flows/14-team-collaboration.md)** | Multi-agent task tracking, progress dashboard, @username ownership |
| 15 | **[Jira Integration](docs/work-flows/15-jira-integration.md)** | 8-step sync flow — credentials, hours reconciliation, hierarchy creation, confirmation UI |
| 16 | **[Feature Design](docs/work-flows/16-feature-design.md)** | Per-feature design plans, 3 triggers, ADL integration, R→F→Plan→ADR→T traceability |

---

## Documentation

- **[Quick Guide (PDF)](ard/Portable_Spec_Kit_Guide.pdf)** — Visual overview of the framework
- **[Technical Overview (PDF)](ard/Portable_Spec_Kit_Technical_Overview.pdf)** — Architecture reference document
- **[Work Flows](docs/work-flows/)** — 16 step-by-step flow diagrams
- **SPD Concept Paper** — Methodology paper with evaluation *(coming soon)*
- **[Benchmarking Report](tests/spd-benchmarking-report.md)** — 5 projects × 3 methodologies compared
- **[Starter Example](examples/starter/)** — Fresh project with self-documenting README
- **[My App Example](examples/my-app/)** — Mid-development project
- **[portable-spec-kit.md](portable-spec-kit.md)** — The complete framework file

---

## License

MIT License — use it, fork it, customize it, share it.

---

## Author

**Dr. Aqib Mumtaz, Ph.D.**
Specialization: Computer Science — Artificial Intelligence
Research: Multimodal AI, Healthcare AI, Autonomous Surveillance

- [LinkedIn](https://linkedin.com/in/aqibmumtaz)
- [GitHub](https://github.com/aqibmumtaz)
- [Google Scholar](https://scholar.google.com/citations?user=zL4pvBgAAAAJ)

---

<p align="center">
  <strong>Portable Spec Kit — One file. Any project. Your standards. Personalized.</strong><br>
  <em>Spec-Persistent Development — specs always exist, always current, never block</em>
</p>
