# Flow: First Session in New Workspace

> **When:** User opens an AI agent in a workspace for the first time — no WORKSPACE_CONTEXT.md exists yet.

## Trigger
Agent reads framework → detects `WORKSPACE_CONTEXT.md` does not exist.

## Flow

```
Agent reads framework
    │
    ▼
Check user profile:
    1. workspace/.portable-spec-kit/user-profile/user-profile-{username}.md → not found
    2. ~/.portable-spec-kit/user-profile/user-profile-{username}.md
        │
        ├─ Found → load profile, show, keep/customize
        └─ Not found → run User Profile Setup flow first
    │
    ▼
Create WORKSPACE_CONTEXT.md:
    │
    ├── Auto-detect environment:
    │   OS, Node version, Python version, tools installed
    │
    ├── Scan workspace for existing projects/directories:
    │   Populate Workspace Overview table
    │
    └── Create agent/ dirs for any projects found without them
    │
    ▼
WORKSPACE_CONTEXT.md created with sections:
    - Workspace Overview (table of projects)
    - Environment & Tools
    - Key Conventions
    - Last Updated
    │
    ▼
For each project found without agent/ dir:
    Create agent/ with 6 template files
    Apply File Creation/Update Rule to README.md
    │
    ▼
✓ Workspace ready
```

## WORKSPACE_CONTEXT.md Rules
- Created **once** on first session — never overwritten unless user explicitly asks
- Not for project-specific state — that goes in each project's `agent/AGENT_CONTEXT.md`
- Only update when user explicitly requests it

## Files Created
- `WORKSPACE_CONTEXT.md` (workspace root)
- `agent/` directories for projects found without them
