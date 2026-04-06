# Flow: Requirements to Delivery

> **When:** A project goes through its full lifecycle — from client requirements through specification, development, scope changes, context breaks, and final delivery. Shows how SPD handles every phase and what happens to specifications at each transition.

## The Full Lifecycle

```
Client Requirements → Specifications → Build → Scope Change → Break → Resume → Release → Handoff
     (human)           (agent)        (agent)    (agent)      (persist) (agent) (agent)  (anyone)
```

## Running Example: TaskFlow — Task Management App

A client hires a developer to build a task management app called **TaskFlow**. This example follows the project through all phases — including multiple rounds of client changes — to show exactly what SPD does at each step.

---

## Phase 1: Client Gives Requirements

```
CLIENT: "I need a task management app with login,
         dashboard, and export to PDF"
    │
    ▼
Developer receives requirements
    │
    ▼
Developer tells agent: "Build a task management app called TaskFlow"
    + shares client requirements
    │
    ▼
AGENT DOES:

    1. SPECS.md → adds requirements (client language)
       ┌──────────────────────────────────────────────────────┐
       │ ## Requirements (Client)                              │
       │ - R1: Users can log in                                │
       │ - R2: Dashboard shows tasks                           │
       │ - R3: Export to PDF                                   │
       │                                                       │
       │ ## Features (Implementation → traces to requirements) │
       │ | # | Feature                    | Traces To | Status │
       │ | F1| Email + password auth      | R1        | [ ]    │
       │ | F2| React dashboard w/ filters | R2        | [ ]    │
       │ | F3| PDF generation (WeasyPrint)| R3        | [ ]    │
       │                                                       │
       │ ## Scope                                              │
       │ - In: auth, dashboard, PDF export                     │
       │ - Out: calendar, notifications, teams, mobile app     │
       └──────────────────────────────────────────────────────┘

    2. PLANS.md → architecture decisions
       ┌──────────────────────────────────────────────────────┐
       │ ## Stack                                              │
       │ | Layer    | Technology  | Why                      | │
       │ | Frontend | Next.js 14  | SSR, React, fast         | │
       │ | Backend  | FastAPI     | Async, typed, Python     | │
       │ | Database | PostgreSQL  | Relational, tasks + users| │
       │ | PDF      | WeasyPrint  | HTML → PDF, Python-native| │
       │ | Hosting  | Vercel + Railway | Easy deploy         | │
       │                                                       │
       │ ## Data Model                                         │
       │ | Table  | Key Fields                               | │
       │ | users  | id, email, password_hash, name           | │
       │ | tasks  | id, user_id, title, status, due_date     | │
       │ | exports| id, user_id, format, created_at          | │
       │                                                       │
       │ ## API Endpoints                                      │
       │ | Method | Path               | Description         | │
       │ | POST   | /api/auth/signup   | Create account      | │
       │ | POST   | /api/auth/login    | Get JWT token       | │
       │ | GET    | /api/tasks         | List user tasks     | │
       │ | POST   | /api/tasks         | Create task         | │
       │ | GET    | /api/export/pdf    | Generate PDF        | │
       │                                                       │
       │ ## Build Phases                                       │
       │ Phase 1: Auth (email + password, JWT)                 │
       │ Phase 2: Dashboard (task CRUD, filters, status)       │
       │ Phase 3: PDF export (WeasyPrint, task list → PDF)     │
       └──────────────────────────────────────────────────────┘

    3. TASKS.md → work breakdown (traces to features → requirements)
       ┌──────────────────────────────────────────────────────┐
       │ ## v0.1 — Current                                     │
       │ - [ ] Build auth: signup + validation (F1 → R1)       │
       │ - [ ] Build auth: login + JWT generation (F1 → R1)    │
       │ - [ ] Build dashboard: task CRUD endpoints (F2 → R2)  │
       │ - [ ] Build dashboard: React UI + filters (F2 → R2)   │
       │ - [ ] Build PDF export: WeasyPrint integration(F3→R3) │
       │ - [ ] Build PDF export: task list template (F3 → R3)  │
       └──────────────────────────────────────────────────────┘

    4. AGENT_CONTEXT.md → current state
       ┌──────────────────────────────────────────────────────┐
       │ Version: v0.1                                         │
       │ Phase: Development                                    │
       │ Status: Starting — 0/3 features done                  │
       │                                                       │
       │ Key Decisions:                                        │
       │ | Decision  | Choice     | Why                      | │
       │ | Framework | Next.js 14 | SSR + React              | │
       │ | API       | FastAPI    | Async, typed             | │
       │ | DB        | PostgreSQL | Relational task data     | │
       │ | PDF       | WeasyPrint | HTML→PDF, Python-native  | │
       └──────────────────────────────────────────────────────┘
    │
    ▼
✓ Client requirements (R1, R2, R3)
  → translated to features (F1, F2, F3)
  → architecture planned
  → tasks broken down with traceability
  Developer can start coding immediately.
```

---

## Phase 2: Building Features

```
DEVELOPER: "ok build auth first"
    │
    ▼
AGENT DOES:
    - Builds email + password signup, login, JWT
    - Writes 14 tests → all passing
    - TASKS.md → [x] Build auth: signup + validation (F1 → R1)
    - TASKS.md → [x] Build auth: login + JWT generation (F1 → R1)
    - SPECS.md → F1 status: [x]
    - AGENT_CONTEXT.md → 1/3 features done, 14 tests passing
    │
    ▼
DEVELOPER: "now dashboard"
    │
    ▼
AGENT DOES:
    - Builds task CRUD, React dashboard, filters, status columns
    - Writes 22 tests → all passing
    - TASKS.md → [x] Build dashboard: task CRUD endpoints (F2 → R2)
    - TASKS.md → [x] Build dashboard: React UI + filters (F2 → R2)
    - SPECS.md → F2 status: [x]
    - AGENT_CONTEXT.md → 2/3 features done, 36 tests passing
    │
    ▼
STATE AFTER AUTH + DASHBOARD:
    ┌──────────────────────────────────────────────────────┐
    │ SPECS.md                                              │
    │ | F1| Email + password auth      | R1 | [x] |        │
    │ | F2| React dashboard w/ filters | R2 | [x] |        │
    │ | F3| PDF generation (WeasyPrint)| R3 | [ ] |        │
    │                                                       │
    │ TASKS.md                                              │
    │ - [x] Build auth: signup + validation (F1 → R1)       │
    │ - [x] Build auth: login + JWT generation (F1 → R1)    │
    │ - [x] Build dashboard: task CRUD endpoints (F2 → R2)  │
    │ - [x] Build dashboard: React UI + filters (F2 → R2)   │
    │ - [ ] Build PDF export: WeasyPrint integration(F3→R3) │
    │ - [ ] Build PDF export: task list template (F3 → R3)  │
    │                                                       │
    │ AGENT_CONTEXT.md                                      │
    │ Phase: Development                                    │
    │ Done: Auth (14 tests), Dashboard (22 tests)           │
    │ Next: PDF export                                      │
    │ Tests: 36 passing, 93% coverage                       │
    └──────────────────────────────────────────────────────┘
```

---

## Phase 3: Client Changes Requirements Mid-Project

```
════════════════════════════════════════════════════════
  CLIENT CHANGES 3 THINGS AT ONCE
════════════════════════════════════════════════════════

CLIENT: "Actually, drop PDF export.
         Add calendar view instead.
         And login should support Google SSO."
    │
    ▼
Developer tells agent the 3 scope changes
    │
    ▼
AGENT HANDLES EACH CHANGE SEPARATELY:

    ┌─────────────────────────────────────────────────┐
    │ CHANGE 1: Drop PDF export                        │
    │                                                  │
    │ SPECS.md:                                        │
    │   R3 moved to "Out of scope (client decision)"   │
    │   F3 removed from active features                │
    │                                                  │
    │ TASKS.md:                                        │
    │   "Build PDF export" tasks → DESCOPED             │
    │                                                  │
    │ PLANS.md:                                        │
    │   WeasyPrint removed from stack                  │
    │   exports table removed from data model           │
    │   Decision: "Dropped PDF — client priority change" │
    └─────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────┐
    │ CHANGE 2: Add calendar view                      │
    │                                                  │
    │ SPECS.md:                                        │
    │   R4: Calendar view of tasks (NEW)                │
    │   F4: FullCalendar component → traces to R4       │
    │                                                  │
    │ TASKS.md:                                        │
    │   [ ] Build calendar view (F4 → R4)               │
    │                                                  │
    │ PLANS.md:                                        │
    │   Stack: ADD FullCalendar library                 │
    │   Decision: "Added calendar — client request"     │
    └─────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────┐
    │ CHANGE 3: Modify login to support Google SSO     │
    │                                                  │
    │ SPECS.md:                                        │
    │   R1 updated: "Users can log in WITH GOOGLE SSO"  │
    │   F1 updated: "Email + password + Google OAuth2"  │
    │                                                  │
    │ TASKS.md:                                        │
    │   [ ] Add Google SSO to auth (F1 → R1 modified)   │
    │                                                  │
    │ PLANS.md:                                        │
    │   Stack: ADD Google OAuth2 library                │
    │   Decision: "Added Google SSO — client requirement"│
    └─────────────────────────────────────────────────┘
    │
    ▼
STATE AFTER ALL 3 CHANGES:
    ┌──────────────────────────────────────────────────────┐
    │ SPECS.md                                              │
    │                                                       │
    │ ## Requirements (Client)                              │
    │ - R1: Users can log in WITH GOOGLE SSO (modified)     │
    │ - R2: Dashboard shows tasks (unchanged)               │
    │ - R3: Export to PDF → OUT OF SCOPE (client dropped)   │
    │ - R4: Calendar view of tasks (NEW)                    │
    │                                                       │
    │ ## Features (Implementation)                          │
    │ | F1| Email + password + Google OAuth2 | R1  | [x] |  │
    │ | F2| React dashboard with filters     | R2  | [x] |  │
    │ | F3| PDF generation → REMOVED (R3 descoped)        |  │
    │ | F4| FullCalendar component           | R4  | [ ] |  │
    │                                                       │
    │ ## Scope                                              │
    │ - In: auth (+ Google SSO), dashboard, calendar        │
    │ - Out: PDF export (client dropped), notifications     │
    └──────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────┐
    │ PLANS.md — Key Decisions                              │
    │ | Decision          | Choice           | Why                  | │
    │ | Drop PDF          | Removed F3       | Client priority change| │
    │ | Add calendar      | Added F4         | Client request        | │
    │ | Add Google SSO    | Modified F1      | Client requirement    | │
    └──────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────┐
    │ TASKS.md                                              │
    │ - [x] Build auth: signup + validation (F1 → R1)       │
    │ - [x] Build auth: login + JWT generation (F1 → R1)    │
    │ - [x] Build dashboard: task CRUD endpoints (F2 → R2)  │
    │ - [x] Build dashboard: React UI + filters (F2 → R2)   │
    │ - [x] Build PDF export → DESCOPED (client dropped R3) │
    │ - [ ] Add Google SSO to auth (F1 → R1 modified)       │
    │ - [ ] Build calendar view (F4 → R4)                   │
    └──────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────┐
    │ AGENT_CONTEXT.md                                      │
    │ Status: 2/4 features done (was 2/3, scope changed)    │
    │ Decisions: 3 scope changes recorded                   │
    │ Next: Google SSO, then calendar view                  │
    └──────────────────────────────────────────────────────┘
    │
    ▼
✓ Every change recorded with REASON and DATE
  3 types of change handled: DROP (R3), ADD (R4), MODIFY (R1)
  Nothing lost — PDF history preserved in "Out of scope"
  Every feature still traces to a client requirement
```

---

## Phase 4: Developer Takes a Break (2 Weeks)

```
Developer finishes Google SSO, closes laptop. 2 weeks pass.
    │
    ▼
All TaskFlow context preserved in agent/ files:
    ┌──────────────────────────────────────────────────────┐
    │ AGENT_CONTEXT.md (last updated before break)          │
    │                                                       │
    │ Version: v0.1                                         │
    │ Phase: Development                                    │
    │ Status: In Progress — 3/4 features done               │
    │                                                       │
    │ What's Done:                                          │
    │ - F1: Auth with email + password + Google SSO (R1)    │
    │ - F2: Dashboard with task CRUD + filters (R2)         │
    │                                                       │
    │ What's Next:                                          │
    │ - F4: Calendar view with FullCalendar (R4)            │
    │                                                       │
    │ Scope Changes:                                        │
    │ - R3/F3 descoped (PDF export — client dropped)        │
    │ - R4/F4 added (calendar view — client request)        │
    │ - R1/F1 modified (Google SSO — client requirement)    │
    │                                                       │
    │ Key Decisions:                                        │
    │ - PDF dropped (client priority change)                │
    │ - Calendar added (client request)                     │
    │ - Google SSO added (client requirement)               │
    │ - PostgreSQL chosen over MongoDB (relational data)    │
    │                                                       │
    │ Tests: 52 passing, 91% coverage                       │
    └──────────────────────────────────────────────────────┘
    │
    ▼
Nothing lost. Nothing stale. Agent reads this on return.
```

---

## Phase 5: Developer Returns

```
════════════════════════════════════════════════════════
  DEVELOPER COMES BACK AFTER 2 WEEKS
════════════════════════════════════════════════════════

DEVELOPER: "hi"
    │
    ▼
Agent reads all TaskFlow files:
    1. portable-spec-kit.md — framework rules
    2. .portable-spec-kit/user-profile/ — developer preferences
    3. agent/AGENT.md — TaskFlow stack (Next.js, FastAPI, PostgreSQL)
    4. agent/AGENT_CONTEXT.md — 3/4 done, calendar is next
    5. agent/TASKS.md — 5/7 tasks complete (2 descoped)
    6. agent/PLANS.md — architecture, decisions, scope changes
    │
    ▼
AGENT SAYS:
    "Welcome back! Here's where we left off on TaskFlow:
     - v0.1: 3/4 features done
     - Auth (with Google SSO) ✓, Dashboard ✓
     - Client changed scope: dropped PDF, added calendar + Google SSO
     - Next: Build calendar view (F4 → R4)
     - 3 decisions recorded in PLANS.md
     - 52 tests passing, 91% coverage
     Ready to build the calendar view?"
    │
    ▼
DEVELOPER: "yes, build the calendar"
    │
    ▼
Agent starts immediately — knows the stack, data model,
all scope changes, and exactly where to pick up
    │
    ▼
Zero re-explanation. Zero "what was I doing?" moments.
Zero "what's the tech stack?" or "why is PDF not here?"
```

---

## Phase 6: Agent/Tool Switch Mid-Project

```
Developer was using Claude for TaskFlow. Switches to Cursor.
    │
    ▼
Cursor reads the SAME TaskFlow files:
    portable-spec-kit.md → via .cursorrules symlink
    │
    ├─ agent/AGENT.md:
    │   Stack: Next.js 14 + FastAPI + PostgreSQL
    │   Port: 3000 (frontend), 8000 (backend)
    │
    ├─ agent/SPECS.md:
    │   Requirements: R1 (login+SSO), R2 (dashboard), R4 (calendar)
    │   Descoped: R3 (PDF — client dropped)
    │   Features: F1 ✓, F2 ✓, F4 pending
    │
    ├─ agent/PLANS.md:
    │   Stack, data model, API endpoints
    │   3 scope change decisions with reasons
    │
    ├─ agent/TASKS.md:
    │   5/7 tasks done, 1 remaining (calendar view)
    │   2 descoped tasks preserved with notes
    │
    └─ agent/AGENT_CONTEXT.md:
        3/4 features done, calendar next
        52 tests passing, 91% coverage
    │
    ▼
Cursor has IDENTICAL context — knows TaskFlow's full history:
    - What was built (auth + SSO, dashboard)
    - What was descoped and why (PDF → client dropped)
    - What was added and why (calendar → client request)
    - What was modified and why (auth → Google SSO added)
    - What's next (calendar view)
    │
    ▼
✓ Zero data loss on agent switch
  Context lives in files, not in any agent's memory
```

---

## Phase 7: Client Changes Again After Feature Delivery

```
════════════════════════════════════════════════════════
  SECOND ROUND OF CLIENT CHANGES
════════════════════════════════════════════════════════

Agent delivers calendar view. Developer shows client.

CLIENT: "The calendar is too slow.
         Change to a simple list view instead."
    │
    ▼
AGENT DOES:
    SPECS.md:
    ├─ R4 updated: "List view of tasks" (was: calendar view)
    ├─ F4 updated: "Task list component with sorting" (was: FullCalendar)
    └─ Feature still traces to R4 — requirement intent preserved

    TASKS.md:
    ├─ [x] Build calendar view → REPLACED
    └─ [ ] Replace calendar with list view (F4 → R4 modified)

    PLANS.md:
    ├─ Stack: REMOVE FullCalendar library
    ├─ Decision log:
    │   | Replace calendar with list | Client feedback: performance | 2026-04-10 |
    └─ Previous calendar decision still visible in history

    AGENT_CONTEXT.md:
    └─ Decision: "Calendar → list view (client: performance concern)"
    │
    ▼
NOTHING IS LOST:
    - Original requirement (calendar) → still visible in PLANS.md decisions
    - Why it changed → "performance concern"
    - Who decided → "client feedback"
    - What replaced it → "task list component with sorting"
    - The requirement R4 persists — only the implementation changed
```

---

## Phase 8: Release v0.1

```
════════════════════════════════════════════════════════
  ALL FEATURES DONE — RELEASE
════════════════════════════════════════════════════════

List view complete. All TaskFlow v0.1 features done:
    F1: Auth + Google SSO ✓ | F2: Dashboard ✓ | F4: List View ✓
    │
    ▼
Agent updates all pipeline files:

    TASKS.md:
    ┌──────────────────────────────────────────────────────┐
    │ ## v0.1 — Done                                        │
    │ - [x] Build auth: signup + validation (F1 → R1)       │
    │ - [x] Build auth: login + JWT generation (F1 → R1)    │
    │ - [x] Build dashboard: task CRUD endpoints (F2 → R2)  │
    │ - [x] Build dashboard: React UI + filters (F2 → R2)   │
    │ - [x] Build PDF export → DESCOPED (client dropped R3) │
    │ - [x] Add Google SSO to auth (F1 → R1 modified)       │
    │ - [x] Build calendar view → REPLACED with list view   │
    │ - [x] Build list view with sorting (F4 → R4 modified) │
    │                                                       │
    │ ## v0.2 — Current                                     │
    │ - [ ] Notifications (backlog promoted)                │
    │ - [ ] Team workspaces                                 │
    └──────────────────────────────────────────────────────┘

    RELEASES.md:
    ┌──────────────────────────────────────────────────────┐
    │ ## v0.1 — TaskFlow MVP (2026-04-20)                   │
    │ Kit: v0.3.1                                           │
    │                                                       │
    │ ### Delivered (meets client requirements)              │
    │ - R1: Login with email + Google SSO ✓ (F1)            │
    │ - R2: Dashboard with task filters ✓ (F2)              │
    │ - R4: Task list view with sorting ✓ (F4)              │
    │                                                       │
    │ ### Descoped (client approved)                        │
    │ - R3: PDF export (client dropped — priority change)   │
    │                                                       │
    │ ### Changes During Development                        │
    │ - PDF dropped → calendar added → calendar replaced    │
    │   with list view (performance concern)                │
    │ - Google SSO added to auth (client requirement)       │
    │ - All changes client-approved, recorded in PLANS.md   │
    │                                                       │
    │ ### Traceability                                      │
    │ Every feature traces back to a client requirement     │
    │ Every change has a recorded reason                    │
    │ Every decision has approval status                    │
    │                                                       │
    │ ### Tests                                             │
    │ - 68 tests passing, 94% coverage                      │
    │                                                       │
    │ ### Deployment                                        │
    │ - Frontend: https://taskflow.vercel.app               │
    │ - API: https://taskflow-api.railway.app               │
    └──────────────────────────────────────────────────────┘

    AGENT_CONTEXT.md:
    ├─ Version: v0.2
    ├─ Phase: Planning
    └─ Summary: v0.1 released — 3 features, 68 tests, deployed

    SPECS.md:
    └─ All v0.1 features marked [x]
    │
    ▼
✓ Complete release record with full traceability
  Client can see: what was delivered, what was dropped, what changed, and why
```

---

## Phase 9: Project Handoff (6 Months Later)

```
Original developer moves to another project.
New developer "Sarah" inherits TaskFlow.
    │
    ▼
Sarah opens her agent, reads TaskFlow agent/ files:

    SPECS.md → what was built and why:
    ├─ R1: Auth with Google SSO ✓ (originally email-only, SSO added per client)
    ├─ R2: Dashboard with filters ✓ (unchanged from original)
    ├─ R3: PDF export → Out of scope (client dropped, priority change)
    ├─ R4: List view ✓ (was calendar, changed for performance)
    └─ Each feature traces to a client requirement

    PLANS.md → how it's built + full decision history:
    ├─ Stack: Next.js 14 + FastAPI + PostgreSQL
    ├─ 5 key decisions with reasons:
    │   - PostgreSQL over MongoDB (relational task data)
    │   - PDF dropped (client priority change)
    │   - Calendar added then replaced with list (performance)
    │   - Google SSO added (client requirement)
    │   - WeasyPrint removed, FullCalendar removed (scope changes)
    └─ Data model: users, tasks (no exports table — PDF descoped)

    TASKS.md → full history:
    ├─ v0.1: 8 tasks (including descoped + replaced, with notes)
    ├─ v0.2: notifications + team workspaces (in progress)
    └─ Every task traces: F# → R#

    RELEASES.md → what shipped:
    ├─ v0.1 — TaskFlow MVP (April 20, 2026)
    ├─ 3 features delivered, 1 descoped, 2 scope changes
    ├─ 68 tests, 94% coverage
    └─ Deployed: taskflow.vercel.app + taskflow-api.railway.app

    AGENT_CONTEXT.md → current state:
    ├─ Version: v0.2, Phase: Development
    ├─ v0.2 working on notifications
    └─ No blockers
    │
    ▼
Sarah understands TaskFlow in minutes:
    - What it does (task management with auth, dashboard, list view)
    - What was built and what was descoped (PDF dropped, with reason)
    - What changed mid-project (calendar → list, email → email+SSO)
    - WHY each change happened (client decisions, performance concern)
    - How it's architected (and why those choices were made)
    - What's done (v0.1) and what's pending (v0.2: notifications, teams)
    │
    ▼
✓ Knowledge transfer without meetings
  The specs ARE the documentation
  Sarah's agent greets her: "Welcome to TaskFlow! Here's the current state..."
```

---

## Traceability Chain

Every TaskFlow decision flows through the pipeline with reason and timestamp:

```
CLIENT says "drop PDF export" (March 25)
    │
    ├─ SPECS.md → R3 moved to "Out of scope: client priority change"
    ├─ SPECS.md → F3 removed from active features
    ├─ PLANS.md → WeasyPrint removed, exports table removed, decision logged
    ├─ TASKS.md → PDF tasks marked DESCOPED with note
    └─ AGENT_CONTEXT.md → Decision: "PDF descoped — client priority change"

CLIENT says "add calendar view" (March 25)
    │
    ├─ SPECS.md → R4 added, F4: FullCalendar → R4
    ├─ PLANS.md → FullCalendar added to stack, decision logged
    ├─ TASKS.md → "Build calendar view (F4 → R4)" added
    └─ AGENT_CONTEXT.md → Decision: "Calendar added — client request"

CLIENT says "add Google SSO" (March 25)
    │
    ├─ SPECS.md → R1 updated, F1 updated with OAuth2
    ├─ PLANS.md → OAuth2 library added to stack, decision logged
    ├─ TASKS.md → "Add Google SSO (F1 → R1 modified)" added
    └─ AGENT_CONTEXT.md → Decision: "Google SSO — client requirement"

CLIENT says "calendar too slow, use list view" (April 10)
    │
    ├─ SPECS.md → R4 updated, F4 changed to list component
    ├─ PLANS.md → FullCalendar removed, previous decision preserved, new logged
    ├─ TASKS.md → Calendar REPLACED, list view task added (F4 → R4 modified)
    └─ AGENT_CONTEXT.md → Decision: "Calendar → list (performance concern)"

Developer returns after 2-week break (April 5)
    │
    ├─ AGENT_CONTEXT.md → full state: 3/4 done, all scope changes visible
    ├─ TASKS.md → 5/7 tasks done, clear trail of what happened
    ├─ SPECS.md → R1-R4 status at a glance, R3 out of scope
    └─ Agent summarizes everything → developer picks up instantly

Developer switches Claude → Cursor (April 8)
    │
    ├─ All agent/ files → identical context for new agent
    ├─ .cursorrules symlink → same framework rules
    └─ Zero re-explanation needed
```

---

## What SPD Handles vs. What It Doesn't

| Responsibility | Handled By | TaskFlow Example |
|---|---|---|
| Client requirements gathering | Human (developer/PM) | Client says "login, dashboard, PDF export" |
| Requirements → specifications | Agent | R1/R2/R3 → F1/F2/F3 with traceability |
| Architecture decisions | Agent + developer | Agent proposes Next.js + FastAPI + PostgreSQL, developer approves |
| Building features | Agent | Builds auth, dashboard, list view — tests each one |
| Scope change: DROP | Agent | Client drops PDF → R3 to "Out of scope", F3 removed, WeasyPrint removed |
| Scope change: ADD | Agent | Client adds calendar → R4 + F4 added, FullCalendar added to stack |
| Scope change: MODIFY | Agent | Client adds Google SSO → R1 updated, F1 expanded, OAuth2 added |
| Scope change: REPLACE | Agent | Calendar too slow → F4 changed to list view, FullCalendar removed |
| Context preservation | Agent | 2-week break → agent reads AGENT_CONTEXT.md → full resume |
| Agent switching | Framework | Claude → Cursor → same files, same context, zero loss |
| Release tracking | Agent | v0.1 in RELEASES.md: delivered, descoped, changes, tests, deploy URLs |
| Project handoff | Agent files | Sarah reads agent/ → understands TaskFlow in minutes |
| Requirements validation | Human | Developer verifies specs match what client actually wants |
| Client sign-off | Human | Outside SPD scope — team/process responsibility |

## Key Guarantee

**From first requirement to final delivery, every decision is traceable.**

No context lost on breaks. No knowledge lost on handoff. No specs drifting silently. Every change recorded with reason, date, and impact across all pipeline files.

In TaskFlow's case: the project went through 4 scope changes (drop PDF, add calendar, add SSO, replace calendar with list), a 2-week developer break, an agent switch, and a handoff — and every decision, reason, and outcome is preserved in the agent/ files. Six months later, Sarah reads them and understands everything without a single meeting.

## Files Involved

| File | Role in TaskFlow's Lifecycle |
|---|---|
| `agent/SPECS.md` | R1-R4 requirements → F1-F4 features → traceability → scope changes logged |
| `agent/PLANS.md` | Stack decisions → data model → API design → 5 scope change decisions with reasons |
| `agent/TASKS.md` | 8 tasks tracked → descoped/replaced tasks preserved with notes → version history |
| `agent/RELEASES.md` | v0.1: delivered vs descoped vs changed → tests → deployment URLs |
| `agent/AGENT_CONTEXT.md` | Living state → context across breaks → all scope changes visible |
| `agent/AGENT.md` | Project rules → stack config → dev server ports |
