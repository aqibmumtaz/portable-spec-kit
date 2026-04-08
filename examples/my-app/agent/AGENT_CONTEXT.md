# AGENT_CONTEXT.md — My App

> **Purpose:** Living project state — what's done, what's next, key decisions, blockers.
> **Role:** Read at session start. Updated after significant work, after commits, and before any push.

## Current Status
- **Version:** v0.1.0
- **Kit:** v0.4.11
- **Phase:** Foundation
- **Status:** Core features in progress

## What's Done
- [x] Project setup (Next.js 14 + Tailwind + TypeScript)
- [x] Supabase project created with tables
- [x] Auth (login/signup/session)
- [x] Task CRUD (create, read, update, delete)
- [x] 24 tests passing, 92% coverage

## What's Next
- [ ] Real-time updates via Supabase subscriptions
- [ ] Team workspaces
- [ ] Due date tracking with notifications
- [ ] Mobile responsive layout

## Key Decisions
| Decision | Choice | Why |
|----------|--------|-----|
| Database | Supabase | Free tier, real-time, auth included |
| Styling | Tailwind CSS | Utility-first, fast iteration |
| Auth | Supabase Auth | Built-in JWT, social login ready |
| State | React Server Components | Less client JS, faster loads |

## Blockers
None

## File Structure
```
my-app/
├── agent/                   ← Project management
├── src/
│   ├── app/                 ← Pages
│   ├── components/          ← UI components
│   ├── lib/                 ← Supabase client, utils
│   └── types/               ← TypeScript types
├── tests/
└── public/
```

## Last Updated
- **Date:** 2026-03-31
- **Summary:** Auth + Task CRUD complete. Starting real-time features next.
