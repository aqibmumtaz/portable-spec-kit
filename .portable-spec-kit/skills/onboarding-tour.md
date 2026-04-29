# Skill: Onboarding Tour & Contextual Presence
> Loaded when: First session (no `tour_completed` in config), or user says "tour" / "show tour". Contextual Presence loaded alongside for session greeting, milestones, transitions, and error recovery.

---

## Onboarding Tour (First Session Only)

After profile setup + project scan completes on the VERY FIRST session, the agent gives a brief interactive tour. This is the user's introduction to the kit — make it welcoming, practical, and quick. The tour is NOT a documentation dump. It's a guided walkthrough that gets the user productive in under 2 minutes.

**Tour trigger:** First session ever (no `agent/AGENT_CONTEXT.md` exists yet, or its `Last Updated` field is empty). Once the tour completes, the agent writes `tour_completed: true` to `.portable-spec-kit/config.md`. Tour never runs again.

**Tour flow (agent shows one step at a time, waits for user between steps):**

```
═══════════════════════════════════════════════
  Welcome to Portable Spec Kit, {Name}! 🎉
  Quick tour — 4 steps, takes about 1 minute.
  (Skip anytime: say "skip tour")
═══════════════════════════════════════════════

Step 1 of 4: YOUR PROJECT
  Your project is set up with all management files in agent/.
  The kit tracks your specs, plans, tasks, and releases automatically.
  → Say "what's the status?" anytime to see where you are.
  (Enter to continue)

Step 2 of 4: HOW TO WORK
  Just talk naturally. Say things like:
    "build a login page"  →  I'll plan, build, test, and track it
    "fix the auth bug"    →  I'll add it to tasks, fix it, mark done
    "what's next?"        →  I'll show your pending work
  I handle the tracking — you focus on building.
  (Enter to continue)

Step 3 of 4: YOUR SETTINGS
  Your project config (.portable-spec-kit/config.md):
    Code review:  enabled (I'll review after each feature)
    Scope check:  enabled (I'll check alignment at session start)
    CI/CD:        disabled (enable anytime: "enable ci")
    Jira:         disabled (enable anytime: "enable jira")
  → Say "show config" to change any setting.
  (Enter to continue)

Step 4 of 4: GETTING HELP
  At any point, just ask:
    "help"         →  I'll show what you can do right now
    "how do I...?" →  I'll walk you through step by step
    "show config"  →  Review and change your settings
  I'll also suggest features when they're relevant.
  (Enter to finish tour)

═══════════════════════════════════════════════
  Tour complete. Ready to build!
  Start by describing what you want to create,
  or say "help" if you need guidance.
═══════════════════════════════════════════════
```

**Tour rules:**
- **Show one step at a time.** Wait for user to press Enter or respond before showing next step.
- **User says "skip tour" at any point** → stop immediately, mark tour_completed in config.
- **Steps adapt to config state.** Step 3 reads actual config values — not hardcoded. If Jira is already enabled (from global config), show "Jira: enabled".
- **Steps adapt to project state.** If project already has features in SPECS.md (existing project with kit added), Step 1 says "I found X existing features" instead of "start by describing what to build".
- **Brief, not comprehensive.** 4 steps maximum. Each step is 4-5 lines. Total tour under 1 minute of reading. Deep details come from `help` later.
- **Never repeat.** Once `tour_completed: true` is in config, tour never runs again — even across sessions, machines, or agent switches.

**Tour edge cases:**
- Existing project (has code, agent/ exists) → skip Step 1 project intro, show "Your project is already tracked" instead
- User immediately starts giving tasks before tour finishes → stop tour, handle the task, mark tour completed
- Agent context window too small for full tour → show abbreviated 2-step version (just Steps 2 + 4)
- Team project (another user already ran tour) → config has tour_completed → skip for this user. BUT if this user has no profile → run profile setup, skip tour, show: "Project already configured. Say 'help' for a quick overview."
- User says "tour" or "show tour" → re-run tour even if completed (for refresher)

---

## Contextual Presence (Always-On Help)

After the tour, the kit stays present throughout the development journey. NOT by interrupting, but by being contextually aware and responsive at every touchpoint.

**Session greeting (every session, not just first):**
After reading agent files at session start, show a brief one-liner:
```
"Welcome back, {Name}. Working on {project} (v0.N). {X tasks pending}. Say 'help' anytime."
```
- Derived from AGENT_CONTEXT.md + TASKS.md — always current
- One line only — never a wall of text
- If scope drift detected at session start → append: "Heads up: scope check found {N} items to review."

**Milestone acknowledgments:**
When the user hits natural milestones, the agent acknowledges briefly:
- First feature marked [x] → "First feature complete! The kit is tracking your progress."
- First `prepare release` → "First release! Your CHANGELOG and version history are building."
- 10th task completed → "10 tasks done. Say 'progress' to see your dashboard."
- All tasks in a version done → "All v0.N tasks complete. Ready to release?"

**Transition guidance (between phases):**
When the user finishes one phase and the next phase is unclear:
- All features defined, none designed → "Features defined. Ready to design? Say 'plan F1' to start."
- All designed, none built → "Designs ready. Say 'implement F1' to start building."
- All built, no release → "All tasks done. Say 'prepare release' when ready."
- Post-release → "v0.N released. What's next? Describe new features or check the backlog."

**Error recovery help:**
When something goes wrong, the agent helps without exposing internals:
- Test failures → "N tests failed. I'll show the failures and suggest fixes."
- Push fails → "Push blocked — tests haven't run since last change. Say 'run tests' first."
- Config issue → "This feature needs configuration. Say 'show config' to set it up."

**Performance rule:** All contextual presence reads from already-loaded agent files (which the agent reads at session start anyway). No extra file reads, no extra computation. The agent already knows the project state — it just surfaces relevant information at the right moment.

---

## AI-Powered Onboarding

**Commit `agent/` for team and open-source projects (MANDATORY):** For any project with multiple contributors or a public GitHub repo — commit the `agent/` directory to git. Never add `agent/` to `.gitignore` for team or open-source projects.

When a contributor clones the repo, their agent reads the 6 spec files and is fully briefed without any verbal handoff, onboarding call, or wiki hunt:
1. Agent detects `agent/` exists → reads all agent files (Mapped state)
2. Shows: "✅ Spec Kit: Project mapped (vX.X.X) — briefed from spec files"
3. Presents: stack, current version, phase, top pending tasks
4. Contributor starts working immediately — fully context-aware

This is the Persistent Memory Architecture applied to contributor onboarding. Any agent (Claude, Cursor, Copilot, Cline) reads the same files — briefing is agent-agnostic.

**What stays gitignored (unchanged):** `.env`, `cache/`, `output/`, `logs/` — these are still excluded. The 6 `agent/` management files contain project structure, not secrets.

**Solo project exception:** If definitively single-developer and private, `agent/` may be gitignored. But if in doubt — commit it. Cost of committing: near zero. Cost of not committing when a collaborator joins: full manual re-onboarding.

**CONTRIBUTING.md guidance for open-source projects:** Add this note:
> "This project uses Portable Spec Kit. Your AI agent will be briefed automatically when you clone — open a session and it will read `agent/` to understand the project state, current version, and pending tasks."

**Sensitive content check:** Before committing `agent/`, verify no sensitive data has been added (passwords, API keys, personal info). Agent files contain project structure — not secrets. If secrets found in an agent file → remove them and add to `.env` instead.

**`.gitignore` default on new project setup:**
- Team/open-source detected → `.gitignore` does NOT include `agent/`; tell user: "Committing `agent/` enables AI-powered onboarding — contributors briefed automatically on clone."
- Solo/private → add comment: `# agent/ — commit this for team projects`

**`agent/` already gitignored warning:** If existing project has `agent/` in `.gitignore` and the project has contributors → warn: "agent/ is gitignored — contributors won't be briefed on clone. Remove from .gitignore for team projects?"

**AI-Powered Onboarding edge cases:**
- New contributor uses different AI agent → all agents read same files (Cursor, Copilot, Cline, Claude) — briefing works regardless
- Forked open-source project → forker clones with `agent/` → briefed on upstream project state; can diverge from there
- User wants agent files private → valid for private projects; explain trade-off
- Mono-repo with multiple `agent/` dirs → each subproject decides independently
