# Flow: File Management

> **When:** Agent encounters any auto-managed file (WORKSPACE_CONTEXT.md, README.md, agent/ files) and needs to decide whether to create, update, or leave it.

---

## Overview

| Field | Value |
|---|---|
| **Trigger** | Agent encounters any auto-managed file on session start, new project setup, existing project onboarding, or kit version update |
| **Inputs** | All `agent/` files, `WORKSPACE_CONTEXT.md`, `README.md`; template definitions from `portable-spec-kit.md`; `<!-- Framework Version -->` comment in kit vs `**Kit:**` in `AGENT_CONTEXT.md` |
| **Outputs** | Created or restructured `agent/` files, `WORKSPACE_CONTEXT.md`, `README.md`; updated `**Kit:**` field on version change |
| **Script** | `agent/scripts/psk-sync-check.sh --full` (structural validation); `grep -r` for stale field names on kit update |
| **Gate** | Content is NEVER lost — restructure retains every detail; stale field sweep runs after every kit version update |
| **When blocked** | Kit version mismatch and user has unsaved changes → commit or stash first; file unwritable → agent displays content and asks user to create file manually |

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  ENCOUNTER A MANAGED FILE (automated)                       │
│  (WORKSPACE_CONTEXT.md / README.md / agent/* files)         │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────▼──────────────┐
         │  DECISION: File exists?     │
         ├─ NO  → CREATE from template │
         │        fill known details   │
         └─ YES → check structure      │
         └────────────────────────────┘
                       │
         ┌─────────────▼──────────────┐
         │  DECISION: Matches template?│
         ├─ YES → LEAVE AS-IS          │
         └─ NO  → RESTRUCTURE:         │
         │        read ALL content     │
         │        map to template      │
         │        reorganize sections  │
         │        RETAIN every detail  │
         └────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  KIT VERSION CHECK (automated — on session start)           │
│  <!-- Framework Version --> vs **Kit:** in AGENT_CONTEXT.md │
│  ├─ Same    → no action                                     │
│  └─ Different → run Kit Version Update flow (below)         │
└─────────────────────────────────────────────────────────────┘
```

---

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

---

## Key Rules

- **Content is never lost.** When restructuring an existing file, every detail, decision, and note is preserved — only the structure is reorganized to match the current template.
- **Create only missing files.** When `agent/` has some files but not others, create only the missing files — never overwrite existing ones.
- **Stale field sweep is mandatory on kit update.** After every kit version change, `grep -r` all `agent/`, `docs/`, `examples/`, and `templates/` for renamed fields (e.g., `"Framework versions:"` → `"Kit:"`). No stragglers allowed.
- **The three-scenario rule is exhaustive.** Every auto-managed file encounter resolves to exactly one of: CREATE / LEAVE AS-IS / RESTRUCTURE. There is no fourth outcome.
- **`WORKSPACE_CONTEXT.md` is created once, never overwritten.** It is only updated when the user explicitly requests it — not on subsequent sessions or kit updates.
- **PostToolUse hook validates after every Write/Edit.** `psk-sync-check.sh --quick` fires automatically after any file write — silent on clean, warns on structural drift. The pre-commit hook runs `--full` and blocks bad commits.
- **Table-of-Contents drift-guard (PSK045, v0.6.83).** `portable-spec-kit.md` carries an auto-generated TOC between `<!-- TOC-START -->` / `<!-- TOC-END -->`. `bash agent/scripts/psk-toc.sh --generate` rebuilds it from the real `## ` headers (fence-aware — headers inside code/example blocks are skipped); `--verify` checks the committed TOC matches. Sync-check rule PSK045 runs the verify in `--full` mode so the TOC can never silently rot when sections are added, renamed, or removed. Bypass: `PSK_PSK045_DISABLED=1`.
