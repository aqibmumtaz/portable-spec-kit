# Skill: Kit Self-Help
> Loaded when: User asks for help, says "help", "what can I do?", "show commands", or "how do I...?".

---

## Dynamic Guidance Sources

| What the agent needs to know | Where it reads from |
|------------------------------|---------------------|
| Available commands | Scan this framework file for command tables — extract dynamically |
| Current project state | `agent/AGENT_CONTEXT.md` + `agent/TASKS.md` + `agent/SPECS.md` |
| What's configured | `.portable-spec-kit/config.md` — show only features that are enabled |
| Release process steps | Scan the "prepare release" sequence in this framework — count steps dynamically |
| Test counts | Run or read last test results — never hardcode a number |
| Feature list | Read `agent/SPECS.md` features table — always current |
| Design plan status | Read `agent/design/` directory — list what exists |

## Help Triggers — User Asks, Agent Answers

| User says | Agent does |
|-----------|-----------|
| `"help"` / `"what can I do?"` | Read project state → show only relevant next actions |
| `"how do I [action]?"` | Read the process from framework → walk through step by step |
| `"what's next?"` | Read TASKS.md + AGENT_CONTEXT.md → suggest next pending action |
| `"explain [feature]"` | Explain what it does and how to use it — not how it's built |
| `"show commands"` / `"what can I say?"` | Scan framework for commands relevant to current state + enabled config |

## Contextual Help — Derived from Project State, Not Static

The agent reads current files and shows ONLY what applies:
- No `agent/` → suggest `init`
- SPECS.md empty → suggest defining features
- Features defined, no `agent/design/` plans → suggest `plan F{N}`
- Features designed, TASKS.md empty → suggest building
- Tasks in progress → show progress, suggest `what's the status?`
- All tasks `[x]` → suggest `prepare release`
- Config has Jira disabled + user asks about Jira → suggest `enable jira`
- Config has feature enabled but user hasn't used it → nudge once

## Process Walkthroughs — Read from Framework, Guide Step by Step

When user asks "how do I release?" or "how do I set up Jira?", the agent reads the actual process definition from this framework file and walks through it one step at a time. Never hardcode step counts or content — read the current sequence.

## Command Discovery — Filtered by State + Config

When user asks "what can I say?", the agent scans the framework for all commands, then filters by:
1. **Project state** — don't show release commands if nothing is built
2. **Config state** — don't show Jira commands if Jira is disabled
3. **Relevance** — show general commands (help, progress, config) always

## Proactive Nudges — Derived from Observation, Not a Static List

The agent observes user behavior and suggests kit features when naturally relevant:
- Used a kit feature? → Don't nudge about it
- Hasn't used an enabled feature in a while? → Nudge once
- Doing something manually that the kit automates? → Suggest the automated way
- Config has defaults since setup? → Suggest reviewing config

**Nudge rules:**
- Each nudge shown **once per session** — never repeat
- Only when **naturally relevant** — don't interrupt workflow
- User says "stop suggesting" or "no tips" → stop all nudges for session
- Brief — one line, not a paragraph

## What to NEVER Tell the User

- Framework section numbers, rule names, or internal structure
- How rules are enforced or how the agent checks compliance
- Config Contract, Config Gateway Rule, or enforcement logic
- How tests validate framework rules
- Internal step numbers (say "I'll handle the release steps" not "Step 5 is...")
- Why the framework was designed a certain way
- Script internals or implementation details

## Version Upgrade Resilience

**Version upgrade resilience:** All guidance is derived at runtime from the current framework file. When the kit updates:
- New commands automatically appear in `show commands` (agent re-scans framework)
- New config toggles automatically appear in `show config` (agent reads config.md)
- New pipeline steps automatically appear in process walkthroughs (agent reads sequence)
- New features automatically appear in contextual help (agent reads SPECS.md + config)
- Removed features automatically disappear (not in framework = not shown)
- **No manual guidance updates needed on version upgrade** — the agent reads what's current

## Help Layer Consistency (Enforced at Release)

**Help layer consistency:** The three help layers (local framework, local project files, GitHub repo) must agree. Consistency is checked during prepare release Step 5 (consistency sweep):
- README orchestration table commands must match commands defined in this framework file
- README "What's New" must reflect CHANGELOG entries for the current version
- Config commands shown in `show config` must match toggles in `.portable-spec-kit/config.md`
- Flow doc count in README must match actual count in `docs/work-flows/`
- Any new framework feature must be discoverable via `help` (agent reads it from this file)

**Self-help is NOT a separate system.** It's the agent reading THIS file + project files + config. If the framework is correct, self-help is correct. If the framework is stale, self-help is stale — the consistency sweep catches this.

## Always Track Silently

Even if the user doesn't follow the process:
- User says "build me X" → add to TASKS.md, then build it
- User says "fix this bug" → add to TASKS.md, fix it, mark done
- User says "what's the status?" → show from TASKS.md and AGENT_CONTEXT.md
- User says "progress", "dashboard", or "burndown" → read TASKS.md and generate a progress dashboard (see Progress Dashboard below)
- User comes back after weeks → read AGENT_CONTEXT.md, summarize where they left off
- User says "keep noted" or "note this" → add to the appropriate agent/ file (TASKS.md for future work, PLANS.md for decisions, AGENT_CONTEXT.md for current state) — never to external memory systems
