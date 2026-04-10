# AGENT.md — My App

> **Purpose:** Project-specific AI instructions — stack, rules, brand, key decisions.
> **Role:** Read at start of every session. Rarely changes after setup.

## Project Location
`my-app/`

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
| Layer | Technology | Why |
|-------|-----------|-----|
| Frontend | Next.js 14 + TypeScript + Tailwind | Industry standard, great DX |
| Backend | Next.js API Routes | Same codebase, no separate server |
| Database | Supabase (PostgreSQL) | Free tier, real-time, auth included |
| Auth | Supabase Auth | Built-in, JWT, social login |
| Hosting | Vercel | Auto-deploy from git |

## Brand
- Primary: `#2563EB`
- Accent: `#10B981`
- Fonts: Inter / system-ui

## AI Config
- Provider: OpenAI
- Models: gpt-4.1-mini
- Dev Server Port: 3456

## Key Rules
- All secrets in `.env` only — NEVER commit API keys
- Supabase RLS on all tables
- Test before deploy — all tests must pass

## Deployment
- Vercel auto-deploy from `main` branch
- Preview deployments for PRs
