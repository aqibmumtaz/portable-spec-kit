# Starter Project

> This project was scaffolded using **[Portable Spec Kit](https://github.com/aqibmumtaz/portable-spec-kit)** — a lightweight, zero-install spec-persistent development framework for AI-assisted engineering.

## What Happened When You Set Up This Project

When you installed `portable-spec-kit.md` and started your first AI session, the framework automatically:

1. **Detected your environment** — OS, Node.js, Python, installed tools
2. **Created `WORKSPACE_CONTEXT.md`** — workspace state (environment, projects found)
3. **Created `agent/` directory** — with 6 project management files
4. **Created this `README.md`** — structured for your project

No install. No config. No CLI. Just one file → everything scaffolded.

## Project Structure

```
starter/
│
├── portable-spec-kit.md     ← The framework file (source — edit this one)
│                              Contains: git rules, security, testing,
│                              naming conventions, project templates.
│
├── CLAUDE.md                ← Symlink → portable-spec-kit.md (Claude Code)
├── .cursorrules             ← Symlink → portable-spec-kit.md (Cursor)
├── .windsurfrules           ← Symlink → portable-spec-kit.md (Windsurf)
├── .clinerules              ← Symlink → portable-spec-kit.md (Cline)
├── .github/
│   └── copilot-instructions.md ← Symlink → portable-spec-kit.md (Copilot)
│
├── WORKSPACE_CONTEXT.md        ← Auto-created workspace state
│                              Your environment, tools detected.
│                              Created once, rarely updated.
│
├── README.md                ← This file (auto-created)
│
├── agent/                   ← Project management (AI reads + updates these)
│   │
│   ├── AGENT.md             ← YOUR project's rules
│   │                          Stack, brand colors, AI config, key rules.
│   │                          Set once during setup. Rarely changes.
│   │
│   ├── AGENT_CONTEXT.md     ← Living state of YOUR project
│   │                          What's done, what's next, decisions, blockers.
│   │                          Updated EVERY session automatically.
│   │                          Come back weeks later — AI picks up here.
│   │
│   ├── SPECS.md             ← WHAT you're building
│   │                          Requirements, features, acceptance criteria.
│   │                          Written before coding. Refined as you go.
│   │
│   ├── PLANS.md          ← HOW you're building it
│   │                          Architecture, data model, API endpoints,
│   │                          build phases, security considerations.
│   │
│   ├── TASKS.md             ← Task tracking
│   │                          Module-based checkboxes. Every request
│   │                          becomes a tracked task. Nothing lost.
│   │
│   └── RELEASES.md           ← Version history
│                              Changelog per version, test results,
│                              deployment log. Written at release time.
│
├── src/                     ← Your source code goes here
├── tests/                   ← Your test files
├── docs/                    ← Additional documentation
├── ard/                     ← Architecture Reference Documents (HTML + PDF)
├── input/                   ← Drop files here for AI to process
├── output/                  ← Generated files (PDFs, exports)
├── cache/                   ← Temporary files (in .gitignore)
│
├── .gitignore               ← Standard ignores
└── .env.example             ← Environment variable template (no real keys)
```

## The Development Flow

```
SPECS.md  →  PLANS.md  →  TASKS.md  →  Build + Test  →  RELEASES.md
  What         How            Track         Execute           Log
```

**You don't have to follow this in order.** The AI agent adapts:

- Jump straight into coding → agent tracks tasks in the background
- Ask "what should I do next?" → agent walks you through the flow
- Come back after weeks → agent reads AGENT_CONTEXT.md, tells you where you left off

## How to Use

### Starting Fresh
```
You: "I want to build a task management app"
Agent: Writes SPECS.md → recommends stack → writes PLANS.md → creates TASKS.md → starts building
```

### Jumping Into Code
```
You: "Build me a login page"
Agent: Adds to TASKS.md → builds it → tests it → marks done
```

### Checking Status
```
You: "What's the status?"
Agent: Shows TASKS.md progress + AGENT_CONTEXT.md summary
```

### Resuming Later
```
You: (opens project after 2 weeks)
Agent: "Here's where we left off — v0.1 has 8/12 tasks done. Next up: payment integration."
```

## Learn More

- **[Portable Spec Kit](https://github.com/aqibmumtaz/portable-spec-kit)** — The framework
- **[Quick Guide (PDF)](https://github.com/aqibmumtaz/portable-spec-kit/blob/main/ard/Portable_Spec_Kit_Guide.pdf)** — Visual overview
- **[portable-spec-kit.md](portable-spec-kit.md)** — The complete framework file (CLAUDE.md, .cursorrules, .windsurfrules, .clinerules → all symlink here)
