# AGENT.md — Starter

> **Purpose:** Project-specific AI instructions — stack, rules, brand, key decisions.
> **Role:** Read at start of every session. Rarely changes after setup.

## Project Location
`starter/`

## On Every Session Start:
1. Read `agent/AGENT_CONTEXT.md` — project state
2. Read `agent/TASKS.md` — current tasks
3. Read `agent/PLANS.md` — architecture

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
- Provider: TBD
- Models: TBD
- Dev Server Port: 3456

## Key Rules
- All secrets in `.env` only — NEVER commit API keys
- Test before deploy — all test cases must pass

## Deployment
<!-- Added at release time -->
