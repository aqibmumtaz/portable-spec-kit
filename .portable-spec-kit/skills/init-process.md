# Skill: Init/Reinit Process

> **Loaded when:** User says `init` or `reinit`.

## "init" — Project Initialization

Explicit trigger for full project scan and agent file setup. Handles any kit status (New, Partial, or already Mapped).

1. Confirm project directory — list visible dirs, ask: "Which directory is your project? (Enter = current)"
2. Show current kit status (Mapped / Partial / New)
3. If already Mapped → show: "Project already initialized (vX.X.X). Running full re-scan to refresh agent files." then continue.
4. Announce: "Scanning project — stack, source files, config, dependencies..."
5. **Deep scan** — read all config files (`package.json`, `requirements.txt`, `pyproject.toml`, `Dockerfile`, `docker-compose.yml`, `tsconfig.json`, `go.mod`, `Cargo.toml`, `build.gradle`, `*.xcodeproj`, `pubspec.yaml`, `README.md`) + all top-level dirs + sample `src/` files. Build a complete picture before touching anything.
6. Create `agent/` dir + all agent files if missing — fill every field from scan. Never leave TBD if the answer is visible in the code.
7. Create `README.md`, `.gitignore`, `.env.example` if missing.
8. Present scan summary + optional changes checklist.
9. Apply selected changes.
10. Show init summary.

## "reinit" — Re-scan and Sync Agent Files

Re-scans the entire project and brings all agent files in sync with the current codebase.

1. Announce: "Re-scanning — syncing agent files to current codebase..."
2. **Upgrade check** — if framework version changed since last scan, run migration: create missing files, create missing directories, rename old patterns. Preserve all existing content.
3. Read current `agent/AGENT.md` + `agent/AGENT_CONTEXT.md` as baseline.
4. **Deep scan** — same scope as `init` step 5.
5. **Update `agent/AGENT.md`** — update only fields that changed.
6. **Rebuild `agent/AGENT_CONTEXT.md`** — rewrite from current codebase state.
7. **SPECS.md staleness check** — count completed tasks vs features in SPECS.md.
8. **PLANS.md vs code** — flag architecture drift.
9. Show reinit summary.

## Hook Installation (auto on init/reinit)

When running init or reinit:
1. Install Claude Code hooks (`.claude/settings.json`) if missing
2. Install git pre-commit hook (`.git/hooks/pre-commit`) if missing — wrap existing hooks
3. Verify all `agent/scripts/*.sh` are executable
4. Run `psk-sync-check.sh --quick` as smoke test
