# Flow: File Management

> **When:** Agent encounters any auto-managed file (WORKSPACE_CONTEXT.md, README.md, agent/ files) and needs to decide whether to create, update, or leave it.

## The Rule

One rule governs ALL auto-managed files:

| Scenario | Action |
|----------|--------|
| **File does not exist** | Create from standard template, fill in known details |
| **File exists but wrong structure** | Restructure to match template — **retain all existing content** |
| **File matches template** | Leave as-is |

**Content is never lost.** When restructuring an existing file, every detail, decision, and note is preserved — just reorganized into standard sections.

## Decision Flow

```
┌─────────────────────────────────────────────────────────────┐
│  ENCOUNTER A MANAGED FILE                                   │
│  (WORKSPACE_CONTEXT.md / README.md / agent/* files)         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Does file exist?                                           │
│     ├─ NO  → CREATE from template                           │
│     │        Fill in known details (project name, stack)    │
│     └─ YES → Does file match template?                      │
│              ├─ YES → LEAVE AS-IS — no changes              │
│              └─ NO  → RESTRUCTURE:                          │
│                       Read ALL content                      │
│                       Map to template sections              │
│                       Reorganize structure                  │
│                       RETAIN every detail                   │
└─────────────────────────────────────────────────────────────┘
```

## Kit Version Update — Full Scan Flow

When kit version changes (`<!-- Framework Version -->` in portable-spec-kit.md ≠ `**Kit:**` in AGENT_CONTEXT.md):

```
┌─────────────────────────────────────────────────────────────┐
│  1. RESTRUCTURE AGENT/ FILES                                │
│     Compare each file to current template                   │
│     Reorganize structure, retain all existing content       │
│     Update **Kit:** field to new version                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. STALE FIELD NAME SWEEP                                  │
│     grep -r "Framework versions:" → rename to "Kit:"        │
│     grep -r "**Framework:**" → rename to "**Kit:**"         │
│     Check ALL files: agent/, docs/, examples/, templates    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. SCAN PROJECT CODEBASE                                   │
│     Read source files, config files, directory structure    │
│     (package.json, requirements.txt, Dockerfile, etc.)      │
│     Update AGENT.md: stack, tech, ports — from actual code  │
│     Update AGENT_CONTEXT.md: phase, done, next — from state │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. SHOW COMBINED SUMMARY                                   │
│     "Portable Spec Kit updated to vX.X."                    │
│     "Your project: [stack] · [phase] · [X tasks pending]"   │
│     "Agent files updated: AGENT.md, AGENT_CONTEXT.md"       │
│     "What's new in vX.X: [CHANGELOG entries]"               │
│     Continue conversation — zero interruption               │
└─────────────────────────────────────────────────────────────┘
```

**Scan edge cases:**
| Scenario | Action |
|----------|--------|
| New/empty project (no source files) | Skip deep scan, note: "context will populate when dev starts" |
| Very large project (100+ files) | Scan config files + top-level dirs, sample src/ |
| AGENT.md already accurate (no TBD fields) | Still refresh AGENT_CONTEXT.md phase/status |
| Document/research project (no code) | Scan plan/, docs/, research/ for current state |
| Kit updated but no project dir confirmed | Skip scan, run on next project entry |

## Files This Applies To
| File | Template Source |
|---|---|
| `WORKSPACE_CONTEXT.md` | Framework: First Session in New Workspace |
| `README.md` | Framework: README.md Template |
| `agent/AGENT.md` | Framework: Agent File Templates |
| `agent/AGENT_CONTEXT.md` | Framework: Agent File Templates |
| `agent/SPECS.md` | Framework: Agent File Templates |
| `agent/PLANS.md` | Framework: Agent File Templates |
| `agent/TASKS.md` | Framework: Agent File Templates |
| `agent/RELEASES.md` | Framework: Agent File Templates |

## Auto-Scan Trigger
This rule is applied during:
1. **First session in new workspace** — scans all projects
2. **Entering any project** — checks for missing agent/ files
3. **New project setup** — creates all files from templates
4. **Kit version changed** — restructure + stale field sweep + codebase scan
