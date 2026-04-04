# Portable Spec Kit — Spec-Persistent Development

**Spec-Persistent Development — a lightweight, zero-install, personalized framework for AI-assisted engineering.**

> Drop one file into any project. Your AI agent personalizes to you, maintains living specifications throughout development, learns and follows your engineering practices, and preserves context across sessions — specs always exist, always current, never block.

[![Version](https://img.shields.io/badge/version-v0.3.3-blue.svg)](portable-spec-kit.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-443%20passing-brightgreen.svg)](tests/)

<table>
<tr>
<td width="25%" align="center"><strong>🪶 Lightweight</strong><br><sub>Single markdown file<br>Zero dependencies<br>Zero install</sub></td>
<td width="25%" align="center"><strong>📦 Portable</strong><br><sub>One file → any repo<br>Works instantly<br>Symlinks for all agents</sub></td>
<td width="25%" align="center"><strong>👤 Personalized</strong><br><sub>GitHub profile auto-detect<br>Adapts to your expertise<br>Tailored AI behavior</sub></td>
<td width="25%" align="center"><strong>📋 Spec-Persistent</strong><br><sub>SPECS → PLANS → TASKS → RELEASES<br>Specs persist alongside your code<br>Your workflow, your choice</sub></td>
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
</tr>
</table>

> **Inspired by GitHub's [spec-kit](https://github.com/github/spec-kit).** A different philosophy — specs persist alongside your code, maintained by the agent, never blocking. No CLI install, no Python dependency, no package managers. One file — zero friction.

---

## The Methodology: Spec-Persistent Development

**Specs always exist and stay current, but never block.**

Traditional approaches force a choice: write specs first (waterfall) or skip them (agile). Spec-Persistent Development is a third path — specifications persist throughout development, maintained by the AI agent, evolving with your code, never gating your work.

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

- **Want waterfall?** Follow SPECS → PLANS → TASKS → RELEASES sequentially. The kit supports it.
- **Want agile?** Jump into coding. The agent tracks tasks and fills specs retroactively.
- **Want a mix?** Write rough specs, start coding, refine as you go. The agent keeps everything in sync.
- **Want to change mid-project?** Started agile but need specs now? The agent fills them from what's built.

The only constant: **specs persist**. However you work, the agent ensures SPECS.md, PLANS.md, TASKS.md, and RELEASES.md always reflect the current state of your project.

---

## The Problem

AI coding agents are powerful but inconsistent. Every new conversation starts from zero — no context, no standards, no memory of decisions. You end up repeating yourself: "use TypeScript", "test everything", "don't commit secrets", "track tasks in markdown"...

**Existing approaches vary.** GitHub's [spec-kit](https://github.com/github/spec-kit) is a comprehensive spec-first solution requiring Python 3.11+, a CLI tool, and package managers. It follows a structured 6-phase workflow. Portable Spec Kit takes a different approach — lighter, more flexible, and personalized.

## The Solution

**One markdown file. Zero dependencies. Zero install. Works with every AI agent.**

### Setup

#### macOS / Linux (one command)
```bash
curl -sO https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/portable-spec-kit.md \
  && ln -sf portable-spec-kit.md CLAUDE.md \
  && ln -sf portable-spec-kit.md .cursorrules \
  && ln -sf portable-spec-kit.md .windsurfrules \
  && ln -sf portable-spec-kit.md .clinerules \
  && mkdir -p .github && ln -sf ../portable-spec-kit.md .github/copilot-instructions.md
```

#### Windows (PowerShell)
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/portable-spec-kit.md" -OutFile "portable-spec-kit.md"
Copy-Item portable-spec-kit.md CLAUDE.md
Copy-Item portable-spec-kit.md .cursorrules
Copy-Item portable-spec-kit.md .windsurfrules
Copy-Item portable-spec-kit.md .clinerules
New-Item -ItemType Directory -Force -Path .github | Out-Null
Copy-Item portable-spec-kit.md .github/copilot-instructions.md
```

**What happens:** Downloads `portable-spec-kit.md` and creates symlinks (Mac/Linux) or copies (Windows) for every supported agent. Edit one file — all agents stay in sync.

Your AI agent reads the framework and on first session:
- **Sets up your personalized profile** — fetches your GitHub identity, asks your preferences, saves to `.portable-spec-kit/user-profile/`
- Creates project management files (`agent/` directory with 6 structured files)
- Follows your coding standards, testing rules, security practices
- Tracks every task, decision, and version
- Maintains context across sessions — pick up weeks later seamlessly
- Addresses you by name, adapts to your expertise and working style

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

### Step 2: Open any AI agent — personalizes and scaffolds your project

The agent reads the framework and automatically sets everything up:

```
✓ Sets up your profile (.portable-spec-kit/user-profile/ — GitHub auto-detect + preferences)
✓ Detects your environment (OS, Node, Python, tools)
✓ Creates WORKSPACE_CONTEXT.md (workspace state)
✓ Creates agent/ directory with 6 management files:
    agent/AGENT.md           ← Project rules, stack, brand
    agent/AGENT_CONTEXT.md   ← Living state (updated every session)
    agent/SPECS.md           ← Requirements & features
    agent/PLANS.md        ← Architecture, methodology & research
    agent/TASKS.md           ← Task tracking
    agent/RELEASES.md         ← Version history
✓ Creates project directories (src/, tests/, docs/, ard/, input/, output/)
✓ Creates README.md with standard structure
✓ Creates .gitignore + .env.example
✓ Ready to work — following YOUR standards
```

### Step 3: Work however you want

The agent adapts to you — not the other way around:

```
You: "Build me a login page"
Agent: Added to TASKS.md → builds → tests → done ✓

You: "What should I do next?"
Agent: Walks you through SPECS → PLANS → TASKS flow

You: "Fix this bug"
Agent: Added to TASKS.md → fixes → marks done ✓

You: "What's the status?"
Agent: Shows progress from TASKS.md + AGENT_CONTEXT.md
```

### Step 4: Session ends

```
✓ Agent updates agent/AGENT_CONTEXT.md — progress, decisions, what's next
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

### Development Pipeline

```
SPECS.md        →  PLANS.md      →  TASKS.md        →  RELEASES.md
What to build      How to build it     Track progress      Log results
```

### The 6 Agent Files (auto-created in `agent/`)

| File | Purpose | Updated |
|------|---------|:-------:|
| `AGENT.md` | Project rules, stack, brand, AI config | Setup |
| `AGENT_CONTEXT.md` | Living state — done, next, decisions, blockers | Every session |
| `SPECS.md` | Requirements, features, acceptance criteria | Before dev |
| `PLANS.md` | Architecture, data model, phases, methodology & research | Before dev |
| `TASKS.md` | Module-based task tracking with checkboxes | During dev |
| `RELEASES.md` | Version changelog, test results, deployment log | End of version |

### Project Structure

```
your-project/
├── portable-spec-kit.md    ← The framework (source file)
├── .portable-spec-kit/     ← Kit config (user profiles, per-user, committed)
│   └── user-profile/
│       └── user-profile-{username}.md
├── CLAUDE.md               ← Symlink (Claude Code)
├── .cursorrules            ← Symlink (Cursor)
├── WORKSPACE_CONTEXT.md    ← Auto-created (workspace state)
├── README.md               ← Auto-created (standard structure)
│
├── agent/                  ← Auto-created (project management)
│   ├── AGENT.md
│   ├── AGENT_CONTEXT.md
│   ├── SPECS.md
│   ├── PLANS.md
│   ├── TASKS.md
│   └── RELEASES.md
│
├── src/                    ← Your code
├── tests/                  ← Your tests
└── ...
```

---

## Core Principles

### 1. Never Block the Developer

The agent adapts to how YOU want to work:

- **Want to follow the full spec-persistent flow?** Agent walks you through it step by step.
- **Want to jump straight into coding?** Agent tracks everything in the background.
- **Want to give direct tasks?** Agent adds to TASKS.md and executes immediately.
- **Forgot to write specs?** Agent fills them retroactively from what's been built.

### 2. Context Never Lost

`AGENT_CONTEXT.md` is updated every session with:
- What was done
- What's next
- Key decisions and why
- Current blockers

Come back weeks later — the agent reads this and picks up exactly where you left off.

### 3. Self-Validating

The agent doesn't just build — it validates:
- Writes tests for every feature
- Runs tests, shows coverage (backend 98%+, frontend 98%+, UI 85%+)
- Fixes failures before presenting results
- You should **never** discover a broken feature

### 4. One File, All Projects

`portable-spec-kit.md` is project-agnostic. It contains:
- Git/GitHub rules
- Security practices
- Testing standards
- Naming conventions
- Project templates
- Code review checklist

Project-specific details (stack, brand, API endpoints) go in `agent/AGENT.md`.

### 5. 90/10 Work Split

Agent does 90% — writes specs, plans, tasks, tests, docs.
You do 10% — review and approve.

---

## What's Inside portable-spec-kit.md

| Section | What It Governs |
|---------|----------------|
| **User Profile** | Personalized AI — GitHub auto-detect, communication style, working pattern, AI delegation |
| **Git & GitHub** | Commit rules, push rules, critical ops requiring approval |
| **Security** | .env handling, secret management, code security practices |
| **Versioning** | Two-level: framework patches + release milestones, auto-restructure on pull |
| **Task Tracking** | Tasks-first workflow, module-based organization |
| **Testing** | Coverage targets, edge case checklist, mock rules, self-validation |
| **Code Quality** | Review checklist, naming conventions, deployment checklist |
| **Error Handling** | Structured errors, logging, error boundaries, user-friendly messages |
| **Branch & PR** | Feature branches, PR format, squash merge, clean history |
| **Python Environment** | Conda env per project, environment selection flow, edge case handling, requirements.txt management |
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

## File Management Rule

One rule governs all auto-managed files:

| Scenario | Action |
|----------|--------|
| File doesn't exist | Create from template, fill in known details |
| File exists but wrong structure | Restructure to match template — **retain all content** |
| File matches template | Leave as-is |

**Content is never lost.** Existing files are reorganized, not overwritten.

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
✓ Committed: "Initialize my-app — v0.1 setup"

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

Detailed step-by-step diagrams for every system flow:

| Flow | When It Triggers |
|------|-----------------|
| **[User Profile Setup](docs/system-flows/user-profile-setup.md)** | First time using the kit — GitHub fetch + 3 questions |
| **[New Project Setup](docs/system-flows/new-project-setup.md)** | Creating a new project — profile shown, scaffold created |
| **[Returning Session](docs/system-flows/returning-session.md)** | Coming back after days/weeks — context loaded, no questions |
| **[Agent Switching](docs/system-flows/agent-switching.md)** | Switching Claude → Cursor → Copilot — zero data loss |
| **[Profile Customization](docs/system-flows/profile-customization.md)** | Different preferences per project — local override |
| **[Spec-Persistent Development](docs/system-flows/spec-persistent-development.md)** | SPECS → PLAN → TASKS → TRACK — living specs, any workflow |
| **[First Session Workspace](docs/system-flows/first-session-workspace.md)** | First time in a workspace — environment detection, auto-scan |
| **[Requirements to Delivery](docs/system-flows/requirements-to-delivery.md)** | Full lifecycle — client requirements through handoff |
| **[File Management](docs/system-flows/file-management.md)** | Create/update/restructure rule — never lose content |

---

## Documentation

- **[Quick Guide (PDF)](ard/Portable_Spec_Kit_Guide.pdf)** — Visual overview of the framework
- **[Technical Overview (PDF)](ard/Portable_Spec_Kit_Technical_Overview.pdf)** — Architecture reference document
- **[System Flows](docs/system-flows/)** — 9 step-by-step flow diagrams
- **[SPD Concept Paper](docs/research/spd-concept-paper-draft.pdf)** — Methodology paper with evaluation
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
