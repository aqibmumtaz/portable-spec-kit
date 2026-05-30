# Skill: Init Process (idempotent — folds reinit)

> **Loaded when:** User says `init` (or `reinit`, which is folded into `init`).

## "init" — idempotent project conformance (CREATE-or-REFRESH)

Explicit trigger that conforms the project to current kit standards. State-detected and idempotent: it CREATEs the pipeline on an empty project and REFRESHes (conforms, content-loss-protected) an existing one. Registry-driven via the conformance engine (`psk-conformance.sh`) — dimension-agnostic. Re-running on a conformant project is a fast no-op. Handles any kit status (New, Partial, or already Mapped).

1. Confirm project directory — list visible dirs, ask: "Which directory is your project? (Enter = current)"
2. Show current kit status (Mapped / Partial / New) → determines CREATE vs REFRESH.
3. **CREATE mode (empty project):** announce "Scanning project — stack, source files, config, dependencies...", then **deep scan** — read all config files (`package.json`, `requirements.txt`, `pyproject.toml`, `Dockerfile`, `docker-compose.yml`, `tsconfig.json`, `go.mod`, `Cargo.toml`, `build.gradle`, `*.xcodeproj`, `pubspec.yaml`, `README.md`) + all top-level dirs + sample `src/` files. Create `agent/` dir + all agent files — fill every field from scan, never leave TBD when the answer is visible. Create `README.md`, `.gitignore`, `.env.example` if missing.
4. **REFRESH mode (existing project):** announce "Re-scanning — conforming agent files to current kit standards...". Snapshot `agent/*.md` byte counts (content-loss guard). **Upgrade check** — if the kit version changed, the conformance engine creates missing files/dirs and conforms patterns while preserving all existing content. Update only fields that changed; rebuild `agent/AGENT_CONTEXT.md` from current state; run SPECS.md staleness check + PLANS.md-vs-code drift check.
5. Run the conformance engine (`psk-conformance.sh --conform`) — iterate the registry (detect → fix → re-detect) across every standard.
6. **Content-loss check (REFRESH)** — flag any `agent/*.md` that shrank >20% vs snapshot.
7. Present scan/conformance summary + optional changes checklist; apply selected changes.
8. Show init summary.

**`reinit` is folded into `init` (v0.6.62+).** The trigger word is still recognized but runs the same idempotent `init` (REFRESH on an existing project). There is no separate re-scan procedure. `psk-reinit.sh` is a thin alias that forwards to `psk-init.sh`.

## Hook Installation (auto on init)

When running init:
1. Install Claude Code hooks (`.claude/settings.json`) if missing
2. Install git pre-commit hook (`.git/hooks/pre-commit`) if missing — wrap existing hooks
3. Verify all `agent/scripts/*.sh` are executable
4. Run `psk-sync-check.sh --quick` as smoke test
