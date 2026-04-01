# Portable Spec Kit — AI Agentic Specification-Driven Development

> **Purpose:** The single source of truth for how the user works — dev practices, coding standards, testing rules, project setup procedures, and AI interaction guidelines. Read this FIRST on every session.
>
> **Role:** Portable across all projects. Drop this file into any repo and the AI agent follows these standards immediately. Project-specific rules go in `agent/AGENT.md`. Workspace state goes in `WORKSPACE_CONTEXT.md` (auto-created on first session).

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

On first session, the agent also auto-creates:
- `WORKSPACE_CONTEXT.md` — workspace environment and project listing
- `agent/` directory in each project — with 6 management files (AGENT.md, AGENT_CONTEXT.md, SPECS.md, PLANNING.md, TASKS.md, TRACKER.md)
- `README.md` — structured project overview

---

## User Profile

> **Purpose:** Tells the AI agent WHO it's working with — expertise level, communication preferences, and autonomy expectations. The agent uses this to tailor response depth, technical language, analogies, and how much it does autonomously vs. asks for confirmation.
>
> **Location:** `.user-profile.md` (auto-created on first session, never committed to git)

### First Session — Profile Setup
If `.user-profile.md` does not exist:
1. Fetch GitHub profile via `gh api user` (if gh CLI is available and authenticated — if not, ask user manually)
2. Greet user by full name: "Welcome, {Name}! Let me set up your personalized development profile."
3. Ask 3 preference questions with options:

   **Communication style?**
   - (a) direct, data-driven, prefers comprehensive analysis with tables and evidence
   - (b) direct and concise, prefers short answers with bullet points and minimal explanation
   - (c) conversational and collaborative, prefers discussing ideas and thinking through problems together

   **Working pattern?**
   - (a) iterative — starts brief, expands scope, builds ambitiously over time
   - (b) plan-first — defines full specs and architecture before writing any code
   - (c) prototype-fast — gets something working quickly, then refines and polishes

   **AI delegation?**
   - (a) AI does 90%, user reviews 10% — present ready-to-act outputs, not questions
   - (b) AI does 70%, user guides 30% — AI proposes approach, user approves before execution
   - (c) 50/50 collaboration — discuss and decide together before each major step

4. Write `.user-profile.md` with results. User can also type custom answers instead of picking a/b/c.

**If user skips** ("skip" / "later" / "default") → write default profile:
```
- **{GitHub name or "Developer"}** — {GitHub bio or "Software Developer"}
- Communication style: direct and concise, prefers short answers with bullet points and minimal explanation
- Working pattern: iterative — starts brief, expands scope, builds ambitiously over time
- AI delegation: AI does 70%, user guides 30% — AI proposes approach, user approves before execution
```

**Edge cases:**
- GitHub name empty → use GitHub username as fallback
- GitHub bio empty → ask user for education and expertise
- `.user-profile.md` exists but empty → treat as missing, run setup
- `.user-profile.md` exists with content → read and use, don't recreate
- Agent can't write files → show profile content, ask user to create file manually

### Every Session
- Read `.user-profile.md` for user context
- Address user by name
- Adapt response depth, language, and autonomy to their preferences

### .user-profile.md Format
```
# User Profile
> Auto-created on first session. Edit anytime. Never committed to git.

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

- Start at **v0.1** (not v1.0)
- Increment by **0.1** for each release: v0.1 → v0.2 → v0.3
- **v1.0** reserved for production/SaaS launch
- Update changelog in ARD docs at end of each version

---

## Development Practices

### Task Tracking (MANDATORY)
- **When user assigns new tasks, add them to TASKS.md FIRST before starting work**
- **Every task the user requests** must be tracked in the project's `TASKS.md`
- Add tasks when requested, mark `[x]` as soon as completed
- Group related tasks under descriptive headings (e.g., "Scoring System", "UI Polish", "Testing")
- Design decisions and architectural plans go in `PLANNING.md` — not in separate plan files
- If a feature needs a detailed plan, add it as a section in `PLANNING.md` (not a new `*_PLAN.md` file)
- Keep `TASKS.md` and `PLANNING.md` in sync — update both when work is completed
- Test UI pages live under `/test-ui/` route with an index page listing all test modules

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
- **Self-validate before presenting to user** — run tests yourself, fix failures, only present stable results
- **Comprehensive test suite** — unit tests for all pure functions, integration tests for API routes, component tests for UI
- **Self-validate before presenting** — run full test suite after any change, fix all failures, only present stable results to user. User should NEVER discover broken features — that's your job
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

### Code Review (Before Commit)
- No `console.log` left in production code (dev debugging only)
- No `TODO` or `FIXME` left unresolved — either fix it or create a task in TASKS.md
- No commented-out code blocks — delete or move to a branch
- No hardcoded secrets, URLs, or credentials — use environment variables
- No unused imports or variables
- All functions have clear, self-evident names — add comments only where logic isn't obvious

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

### Dependencies
- Prefer well-maintained, widely-used packages
- Check bundle size impact before adding frontend dependencies
- Lock file (`package-lock.json` / `requirements.txt`) must be committed
- Run `npm audit` / `pip audit` periodically
- Avoid adding dependencies for things that can be done in <20 lines of code

### Context Management
- Read `.user-profile.md` at start of every conversation — adapt to user's preferences
- Read project's `agent/AGENT.md` + `agent/AGENT_CONTEXT.md` at start of every conversation
- Update project's `agent/AGENT_CONTEXT.md` at end of every conversation
- **Update the root framework file** whenever a new general guideline or development practice decision is made — these are shared across all projects
- Root framework file = development practices (portable). Project `agent/AGENT.md` = project-specific rules.
- User preferences stored in agent memory/preference files
- Context continuity is critical — user works across weeks/months

---

## Document Generation (ARD / Technical Docs)

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

This rule applies to: `WORKSPACE_CONTEXT.md`, `README.md`, and all `agent/` files.

- **If file does not exist** → create it using the standard template, fill in known details
- **If file exists but doesn't match template structure** → restructure to match template while **retaining all existing content and key details** — never lose data, only reorganize into standard sections
- **If file already matches template** → leave as-is

### First Session in New Workspace

If `WORKSPACE_CONTEXT.md` does not exist:
1. If `.user-profile.md` does not exist → run First Session Profile Setup (see User Profile section above)
2. Create `WORKSPACE_CONTEXT.md` using the File Creation/Update Rule above
3. Sections: Workspace Overview (table), Environment & Tools, Key Conventions, Last Updated
4. Auto-detect environment (OS, Node, Python, tools installed) → populate Environment
5. Scan workspace for existing projects/directories → populate Workspace Overview table
6. Create `agent/` dirs for any projects found without them

**WORKSPACE_CONTEXT.md rules:**
- Only created once on first session — never overwritten unless user explicitly asks
- Not for project-specific state — that goes in each project's `agent/AGENT_CONTEXT.md`
- Only update when user explicitly requests it

### Auto-Scan (On Entering Any Project)

When starting work on a project, scan for `<project>/agent/` directory:
1. If `agent/` directory is missing → create it
2. Check for required files: `AGENT.md`, `AGENT_CONTEXT.md`, `SPECS.md`, `PLANNING.md`, `TASKS.md`, `TRACKER.md`
3. Apply the **File Creation/Update Rule** to each agent file and `README.md`
4. Read `agent/AGENT.md` + `agent/AGENT_CONTEXT.md` for project context
5. Update `agent/AGENT_CONTEXT.md` at end of every session

### New Project Setup (MANDATORY)

When creating a new project, create with ALL of these files and directories:

```
<project>/
│
├── agent/                 ← Project management files (AI reads these)
│   ├── AGENT.md           ← Project-specific AI instructions (stack, rules)
│   ├── AGENT_CONTEXT.md   ← Living project state (updated every session)
│   ├── SPECS.md           ← WHAT to build (requirements, features)
│   ├── PLANNING.md        ← HOW to build it (architecture, phases)
│   ├── TASKS.md           ← Task tracking (checkboxes)
│   └── TRACKER.md         ← Version log, deployments, history
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
| `agent/AGENT.md` | Project-specific AI instructions — stack, tools, project rules | Setup, rarely changes |
| `agent/AGENT_CONTEXT.md` | Living state — what's done, what's next, key decisions, blockers | **Every session** |
| `agent/SPECS.md` | Requirements, features, acceptance criteria | Before dev |
| `agent/PLANNING.md` | Architecture, tech decisions, data model, phases, methodology & research | Before dev |
| `agent/TASKS.md` | Task board — `[ ]` todo, `[x]` done | During dev |
| `agent/TRACKER.md` | Version changelog, deployments, test results | End of version |
| `ard/` | Generated docs — technical overview (HTML+PDF), presentation (HTML+PDF) | End of each version |

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
SPECS.md (define)  →  PLANNING.md (architect)  →  TASKS.md (execute)  →  TRACKER.md (record)
   What to build        How to build it           Track progress          Log what happened
```

### Agent Guidance Behavior

The agent is a **helpful guide, not a strict enforcer**. Follow these principles:

**Don't block the user.** The user can start anywhere — jump into coding, give direct tasks, ask questions, or follow the full spec-driven flow. All valid. The agent adapts to how the user wants to work, not the other way around. Track everything in the background regardless.

**Guide when asked.** If the user asks "what should I do next?" or "how should I approach this?" — walk them through the spec-driven process:
1. "Let's start by defining what you want in SPECS.md — what are the key features?"
2. "Now let's plan the architecture in PLANNING.md — what stack do you want?"
3. "I'll break this into tasks in TASKS.md — here's the module breakdown"
4. "I'll track everything as we go and log it in TRACKER.md at the end"

**Always mention project name when reporting.** When confirming tasks, status, or actions — always include which project it applies to (e.g. "Noted in **ProjectName** agent/TASKS.md").

**Always track silently.** Even if the user doesn't follow the process:
- User says "build me X" → add to TASKS.md, then build it
- User says "fix this bug" → add to TASKS.md, fix it, mark done
- User says "what's the status?" → show from TASKS.md and AGENT_CONTEXT.md
- User comes back after weeks → read AGENT_CONTEXT.md, summarize where they left off

**Fill gaps proactively.** If SPECS.md is empty but the user has been building for a while:
- Don't complain — retroactively fill SPECS.md from what's been built
- Same for PLANNING.md — document the architecture that emerged from the code
- Keep everything in sync without burdening the user

**Surface the process naturally:**
- "I've added this to TASKS.md" (shows you're tracking)
- "Updating AGENT_CONTEXT.md so we can pick up here next time" (shows context persistence)
- "Based on SPECS.md, we still have these features pending" (shows spec-driven awareness)
- "PLANNING.md shows we planned X — should I update it?" (shows plan awareness)

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
1. Read `.user-profile.md` — user preferences (adapt behavior)
2. Read `agent/AGENT_CONTEXT.md` — project state
3. Read `agent/TASKS.md` — current tasks
4. Read `agent/PLANNING.md` — architecture

## On Every Session End:
1. Update `agent/AGENT_CONTEXT.md` — progress, decisions

## Stack
| Layer | Technology |
|-------|-----------|
| Frontend | TBD |
| Backend | TBD |
| Database | TBD |
| Hosting | TBD |

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
> **Role:** Read at session start. Updated at session end.

## Current Status
- **Version:** v0.1
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
| # | Feature | Priority | Status |
|---|---------|----------|--------|
| 1 | | High | [ ] |
| 2 | | Medium | [ ] |

## Scope
- **In scope:**
- **Out of scope (future):**

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

**agent/PLANNING.md:**
```markdown
# PLANNING.md — <Project Name>

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

> **Purpose:** Task tracking — checkboxes for todo/done, organized by module/sprint.
> **Role:** Updated during development. Add tasks FIRST, then work.

## v0.1 — Current

### Module 1: Setup
| # | Task | Status |
|---|------|:------:|
| 1.1 | Project setup | [x] |
| 1.2 | ... | [ ] |

### Blocked
<!-- Tasks waiting on external dependencies -->

### Bug Fixes & Polish
| # | Task | Status | Notes |
|---|------|:------:|-------|
| | | | |

## Progress Summary
| Version | Tasks Done | Tests | Status |
|---------|:----------:|:-----:|--------|
| v0.1 | 0 | 0 | In Progress |
```

**agent/TRACKER.md:**
```markdown
# TRACKER.md — <Project Name>

> **Purpose:** Version history — changelog, deployments, test results, decisions.
> **Role:** Updated at end of each version release.

## v0.1 — Title (Date)

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

### New Project Setup Procedure

When user asks to create a new project, follow these steps IN ORDER:

**Step 1: Create Directory Structure + All Agent Files (DO THIS IMMEDIATELY — no questions)**
```bash
mkdir -p <project>/{agent,ard,input,output,cache,src,tests,docs}
```
Create all 6 agent files using the templates above.
- `README.md` — project overview (see README template below)
- `.gitignore` — general ignores (node_modules, .env, cache/, __pycache__, .next, etc.)
- `.env.example` — empty placeholder

**Step 2: First Commit**
- Stage all files
- Commit with message: "Initialize <project-name> — v0.1 setup"
- Do NOT push (wait for user to say "push")

**Step 3: Report to User**
- Show: directory structure created, files list
- Do NOT ask questions — user will start specs discussion when ready

**Then (when user is ready):**

**Step 4:** Specs discussion → write `agent/SPECS.md`

**Step 5:** Recommend tech stack → user approves

**Step 6:** Write `agent/PLANNING.md` — architecture, phases. Deployment deferred to release time.

**Step 7:** Initialize stack — install deps, update `.gitignore`, assign dev server port automatically

**Step 8:** Start development — update `agent/TASKS.md`, begin building

