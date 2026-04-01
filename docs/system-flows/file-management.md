# Flow: File Management

> **When:** Agent encounters any auto-managed file (WORKSPACE_CONTEXT.md, README.md, agent/ files) and needs to decide whether to create, update, or leave it.

## The Rule

One rule governs ALL auto-managed files:

| Scenario | Action |
|----------|--------|
| **File does not exist** | Create from standard template, fill in known details |
| **File exists but wrong structure** | Restructure to match template — **retain all existing content** |
| **File matches template** | Leave as-is |

## Key Principle
**Content is never lost.** When restructuring an existing file, every detail, decision, and note is preserved — just reorganized into standard sections.

## Flow

```
Agent encounters a managed file
    │
    ▼
Does file exist?
    │
    ├─ NO → Create from template
    │   │
    │   ▼
    │   Use the standard template for that file type
    │   Fill in any known details (project name, stack, etc.)
    │   │
    │   ▼
    │   ✓ File created
    │
    └─ YES → Check structure
        │
        ▼
    Does file match the template structure?
        │
        ├─ YES → Leave as-is (no changes)
        │
        └─ NO → Restructure
            │
            ▼
        Read ALL existing content
        Map content to standard template sections
        Reorganize into standard structure
        RETAIN every detail — never lose data
            │
            ▼
        ✓ File restructured (content preserved)
```

## Files This Applies To
| File | Template Source |
|---|---|
| `WORKSPACE_CONTEXT.md` | Framework: First Session in New Workspace |
| `README.md` | Framework: README.md Template |
| `agent/AGENT.md` | Framework: Agent File Templates |
| `agent/AGENT_CONTEXT.md` | Framework: Agent File Templates |
| `agent/SPECS.md` | Framework: Agent File Templates |
| `agent/PLANNING.md` | Framework: Agent File Templates |
| `agent/TASKS.md` | Framework: Agent File Templates |
| `agent/TRACKER.md` | Framework: Agent File Templates |

## Auto-Scan Trigger
This rule is applied during:
1. **First session in new workspace** — scans all projects
2. **Entering any project** — checks for missing agent/ files
3. **New project setup** — creates all files from templates
4. **Framework version changed** — compare `<!-- Framework Version -->` in portable-spec-kit.md against `**Framework:**` in AGENT_CONTEXT.md. If different → restructure all agent/ files to match new templates, retain content, update Framework version in AGENT_CONTEXT.md
