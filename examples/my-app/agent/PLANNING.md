> **Purpose:** How to build it — architecture, phases, data model, tech decisions, methodology & research.
> **Role:** Defined before dev starts. Updated when architecture changes or new research informs decisions.

# PLANNING.md — My App

## Stack
| Layer | Technology | Why |
|-------|-----------|-----|
| Frontend | Next.js 14 + TypeScript | SSR, API routes, great DX |
| Styling | Tailwind CSS | Utility-first, fast iteration |
| Database | Supabase PostgreSQL | Free, real-time, RLS |
| Auth | Supabase Auth | Built-in, JWT |
| Hosting | Vercel | Auto-deploy, free tier |

## Architecture
```
Browser → Next.js (Vercel) → Supabase (PostgreSQL + Auth + Realtime)
```

## Directory Structure
```
src/
├── app/
│   ├── page.tsx              ← Dashboard
│   ├── login/page.tsx        ← Auth
│   ├── tasks/page.tsx        ← Task list
│   └── api/                  ← API routes
├── components/
│   ├── ui/                   ← Button, Modal, Input
│   ├── layout/               ← Navbar, Sidebar
│   └── tasks/                ← TaskCard, TaskForm
├── lib/
│   ├── supabase.ts           ← Client
│   └── utils.ts              ← Helpers
└── types/
    └── index.ts              ← Task, User, Team types
```

## Data Model
| Table | Key Fields |
|-------|-----------|
| users | id, email, name, avatar |
| teams | id, name, owner_id, invite_code |
| team_members | team_id, user_id, role |
| tasks | id, title, description, status, assignee_id, team_id, due_date |

## API Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | /api/tasks | List tasks for current team |
| POST | /api/tasks | Create task |
| PATCH | /api/tasks/[id] | Update task |
| DELETE | /api/tasks/[id] | Delete task |
| POST | /api/teams/invite | Generate invite link |

## Security
- Supabase RLS on all tables
- JWT auth on all API routes
- Input validation with Zod

## Build Phases
### Phase 1: Foundation
1. Project setup
2. Supabase tables + RLS
3. Auth (login/signup)
4. Task CRUD

### Phase 2: Collaboration
1. Team workspaces
2. Real-time subscriptions
3. Due date notifications

### Phase 3: Polish
1. Mobile responsive
2. Task comments
3. Performance optimization

## Verification
- `npm test` — all tests pass
- `npm run build` — zero errors
- Manual: create task → appears in real-time for teammate
