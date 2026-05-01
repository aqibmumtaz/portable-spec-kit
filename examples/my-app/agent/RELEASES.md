> **Purpose:** Version history — changelog, deployments, test results.
> **Role:** Updated at end of each version release.

# RELEASES.md — My App

## v0.1 — Foundation (March 2026)
Kit: v0.6.27

### Summary
Core app with auth + task CRUD. Foundation for real-time collaboration.

### Changes
- **Frontend:** Login/signup pages, task list, create/edit/delete forms
- **Backend:** Supabase tables with RLS, API routes for tasks
- **Auth:** Email signup, session management, protected routes
- **Infrastructure:** Next.js 14 setup, Tailwind, TypeScript

### Tests
- 24 tests passing, 92% coverage

### Deployment
- Deployed to: Vercel (preview)
- Date: 2026-03-31

### Known Issues
- No real-time yet — requires page refresh to see teammate changes
