# Portable Spec Kit

**A lightweight, zero-install specification-driven development framework for AI-assisted engineering.**

> Drop one file into any project. Your AI agent instantly follows your engineering standards, manages specifications, tracks tasks, writes tests, and maintains context across sessions.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<table>
<tr>
<td width="25%" align="center"><strong>🪶 Lightweight</strong><br><sub>Single markdown file<br>Zero dependencies</sub></td>
<td width="25%" align="center"><strong>📦 Portable</strong><br><sub>Drop into any repo<br>Works instantly</sub></td>
<td width="25%" align="center"><strong>🤖 Agent-Agnostic</strong><br><sub>Claude, Copilot, Cursor<br>Any AI that reads markdown</sub></td>
<td width="25%" align="center"><strong>🔄 Non-Blocking</strong><br><sub>Code first, specs later<br>Agent adapts to you</sub></td>
</tr>
</table>

> **The lightweight portable alternative to GitHub's [spec-kit](https://github.com/github/spec-kit).** No CLI install, no Python dependency, no package managers. One file — same spec-driven methodology — zero friction.

---

## The Problem

AI coding agents are powerful but inconsistent. Every new conversation starts from zero — no context, no standards, no memory of decisions. You end up repeating yourself: "use TypeScript", "test everything", "don't commit secrets", "track tasks in markdown"...

**Existing solutions are heavy.** GitHub's [spec-kit](https://github.com/github/spec-kit) requires Python 3.11+, a CLI tool, package managers, and generates thousands of lines of specification markdown per feature. It enforces a rigid 6-phase waterfall-like workflow that blocks you from coding until specs are formally complete.

## The Solution

**One markdown file. Zero dependencies. Zero install.**

```bash
# That's it. You're done.
curl -sO https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/CLAUDE.md
```

Your AI agent reads `CLAUDE.md` and immediately:
- Creates project management files (`agent/` directory with 6 structured files)
- Follows your coding standards, testing rules, security practices
- Tracks every task, decision, and version
- Maintains context across sessions — pick up weeks later seamlessly
- Guides you through spec-driven development **without blocking you**

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
| **AI agents** | 30+ with config per agent | **Any AI** that reads markdown |
| **Execution time** | 33+ min agent + hours review | **Instant** — read file, start working |
| **Context persistence** | Per-session | **Cross-session** — AGENT_CONTEXT.md |
| **Portability** | Per-project setup required | **One file across all projects** |
| **Spec overhead** | Thousands of lines of formal spec | **Lightweight specs** — as detailed as you need |

---

## Quick Start

### 1. Add to any project

```bash
curl -sO https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/CLAUDE.md
```

### 2. Start a conversation with your AI agent

The agent reads `CLAUDE.md` and automatically:

```
✓ Detects your environment (OS, Node, Python, tools)
✓ Creates CLAUDE_CONTEXT.md (workspace state)
✓ Scans for projects → creates agent/ directories
✓ Creates 6 management files from templates
✓ Creates/restructures README.md
✓ Ready to work — following YOUR standards
```

### 3. Start working

```
You: "Build me a login page"
Agent: Added to TASKS.md → building → testing → done ✓

You: "What should I do next?"
Agent: Based on SPECS.md, these features are pending...

You: "What's the status?"
Agent: Shows progress from TASKS.md + AGENT_CONTEXT.md
```

---

## The Framework

### Development Pipeline

```
SPECS.md        →  PLANNING.md      →  TASKS.md        →  TRACKER.md
What to build      How to build it     Track progress      Log results
```

### The 6 Agent Files (auto-created in `agent/`)

| File | Purpose | Updated |
|------|---------|:-------:|
| `AGENT.md` | Project rules, stack, brand, AI config | Setup |
| `AGENT_CONTEXT.md` | Living state — done, next, decisions, blockers | Every session |
| `SPECS.md` | Requirements, features, acceptance criteria | Before dev |
| `PLANNING.md` | Architecture, API endpoints, data model, phases | Before dev |
| `TASKS.md` | Module-based task tracking with checkboxes | During dev |
| `TRACKER.md` | Version changelog, test results, deployment log | End of version |

### Project Structure

```
your-project/
├── CLAUDE.md              ← The framework (portable)
├── CLAUDE_CONTEXT.md      ← Auto-created (workspace state)
├── README.md              ← Auto-created (standard structure)
│
├── agent/                 ← Auto-created (project management)
│   ├── AGENT.md
│   ├── AGENT_CONTEXT.md
│   ├── SPECS.md
│   ├── PLANNING.md
│   ├── TASKS.md
│   └── TRACKER.md
│
├── src/                   ← Your code
├── tests/                 ← Your tests
└── ...
```

---

## Core Principles

### 1. Never Block the Developer

The agent adapts to how YOU want to work:

- **Want to follow the full spec-driven flow?** Agent walks you through it step by step.
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

`CLAUDE.md` is project-agnostic. It contains:
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

## What's Inside CLAUDE.md

| Section | What It Governs |
|---------|----------------|
| **Git & GitHub** | Commit rules, push rules, critical ops requiring approval |
| **Security** | .env handling, secret management, code security practices |
| **Versioning** | v0.1 → v1.0 numbering, changelog standards |
| **Task Tracking** | Tasks-first workflow, module-based organization |
| **Testing** | Coverage targets, edge case checklist, mock rules, self-validation |
| **Code Quality** | Review checklist, naming conventions, deployment checklist |
| **Error Handling** | Structured errors, logging, error boundaries, user-friendly messages |
| **Branch & PR** | Feature branches, PR format, squash merge, clean history |
| **Dependencies** | Bundle size checks, lock files, audit, avoid unnecessary deps |
| **Project Templates** | 6 agent files + README, all with standard structure |
| **Auto-Scan** | Detects projects, creates/restructures files, preserves existing content |
| **Agent Behavior** | Guide don't enforce, silent tracking, retroactive spec-filling |

---

## Customization

### For Your Profile

Lines 10-13 contain the user profile. Update with your details:

```markdown
## About the User
- **Your Name** — your background and expertise
- Communication style: how you prefer to communicate
- Working pattern: how you approach projects
- AI delegation: what % of work you want AI to handle
```

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
curl -sO https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/CLAUDE.md
```

### Push Updates Back

When you improve CLAUDE.md from any project:

```bash
# Copy to your fork
cp CLAUDE.md ~/portable-spec-kit/
cd ~/portable-spec-kit
git add . && git commit -m "Add new testing rule" && git push
```

### For Teams

Fork this repo → customize CLAUDE.md for your team → everyone pulls from your fork.

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

## Examples

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

### Spec-Driven Flow (When Asked)

```
You: "How should I approach this project?"

Agent:
Let's follow the spec-driven process:

1. First, let's define WHAT you want in SPECS.md
   → What are the key features? Who's the user?

2. Then I'll plan HOW to build it in PLANNING.md
   → Architecture, data model, phases

3. I'll break it into tasks in TASKS.md
   → Module-by-module with checkboxes

4. I'll track everything in TRACKER.md
   → Version history, test results, deployments

Let's start — what's the core problem this project solves?
```

---

## Contributing

Contributions welcome! This framework improves through real-world usage.

1. Fork the repo
2. Customize CLAUDE.md for your workflow
3. Submit a PR with improvements that benefit everyone

**What makes a good contribution:**
- New testing patterns or edge case checklists
- Better project templates
- Agent behavior improvements
- Documentation fixes

---

## Documentation

- **[Quick Guide (PDF)](docs/Portable_Spec_Kit_Guide.pdf)** — Visual overview of the framework
- **[CLAUDE.md](CLAUDE.md)** — The complete framework file (readable as documentation)

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
  <strong>Portable Spec Kit — One file. Any project. Your standards.</strong><br>
  <em>The lightweight alternative to spec-kit for AI-assisted engineering</em>
</p>
