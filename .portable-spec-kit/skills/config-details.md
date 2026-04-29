# Skill: Config Contract, Commands & Edge Cases
> Loaded when: Config is accessed, `show config`, `enable/disable` commands, or config-dependent actions.

---

## Config Contract (Single Source of Truth)

This table is the **exhaustive** list of what each toggle controls. If an action is not in this table, it runs unconditionally. If it IS in this table, the agent must check config before running it.

| Toggle | Action | Where it runs | If disabled |
|--------|--------|---------------|-------------|
| `CI/CD.Enabled` | Create `.github/workflows/ci.yml` | Project setup Step 7.5 | Skip — no workflow files |
| `CI/CD.Enabled` | Create/update CI workflow | `enable ci` command | N/A — command enables it |
| `CI/CD.Badge in README` | Show CI badge | README generation, consistency sweep | Hide in HTML comment |
| `Jira.Enabled` | `sync to jira` (full 8-step flow) | Explicit command | "Jira disabled. Enable: `enable jira`" |
| `Jira.Enabled` | `jira status` | Explicit command | Same message |
| `Jira.Enabled` | `jira setup` | Explicit command | Allow — this is how you enable it |
| `Jira.Enabled` | `link jira` / `unlink jira` | Explicit command | "Jira disabled." |
| `Jira.Enabled` | Track B from psk-tracker logs | Hours reconciliation | Fall back to git/mtime |
| `Code Review.Auto on feature completion` | Run `psk-code-review.sh` + AI review | After feature marked done, before [x] | Skip — feature marked [x] without review |
| `Code Review.In release pipeline` | Run `psk-code-review.sh` | Prepare release Step 2 | Skip — show "disabled in config" in summary |
| `Code Review.In release pipeline` | Run `psk-code-review.sh` | Refresh release Step 2 | Skip — same |
| `Code Review.In release pipeline` | Run `psk-code-review.sh` | **Any future pipeline that includes code review** | Skip — same |
| `Scope Drift.Auto on session start` | Run `psk-scope-check.sh --quick` | Session start | Skip silently |
| `Scope Drift.Auto on session start` | Run `psk-scope-check.sh` | Before `sync to jira` | Skip silently |
| `Scope Drift.In release pipeline` | Run `psk-scope-check.sh` | Prepare release Step 3 | Skip — show "disabled in config" in summary |
| `Scope Drift.In release pipeline` | Run `psk-scope-check.sh` | Refresh release Step 3 | Skip — same |
| `Scope Drift.In release pipeline` | Run `psk-scope-check.sh` | **Any future pipeline that includes scope check** | Skip — same |

**Manual commands always work regardless of config.** `"review code"`, `"check scope"`, `"hours summary"` — these run when the user explicitly asks, even if the toggle is off. Config controls **automatic** behavior, not what you can ask for.

**Future-proofing:** The rows marked "Any future pipeline" mean: if code review or scope check gets added to a new trigger (e.g., push gate, PR creation), it MUST check the same config toggle. The contract is the authority — not the individual step.

---

## Config Commands

**One command for all config — generic, works for any toggle:**

| Command | What it does |
|---------|-------------|
| `"show config"` / `"config"` | Show all toggles + interactive toggle by number or name |
| `"enable [name]"` / `"disable [name]"` | Quick toggle any setting: `enable ci`, `disable jira`, etc. |

**`show config` interactive flow:**
```
══════════════════════════════════════════
  PROJECT CONFIG
══════════════════════════════════════════
  #  Setting                  Status
  ─  ───────────────────────  ──────
  1  CI/CD                    disabled
  2  CI Badge in README       disabled
  3  Jira Integration         disabled
  4  Code Review (auto)       enabled
  5  Code Review (pipeline)   enabled
  6  Scope Check (auto)       enabled
  7  Scope Check (pipeline)   enabled
──────────────────────────────────────────
  Toggle: type number or name. Done: Enter
══════════════════════════════════════════
```
User types `1` → toggled → show updated table. Types `4` → toggled. Enter → done. Side effects applied automatically (CI enabled → workflow created; CI disabled → workflow removed).

**Quick toggle:** `"enable ci"`, `"disable scope check"` — agent matches name to config field, toggles, confirms. Same as interactive but faster for one change.

**Generic — new configs auto-appear.** Agent reads all fields from `.portable-spec-kit/config.md`. Adding a new field to config.md automatically makes it show in `show config`. No new command needed.

**All toggles take effect immediately.** No restart. Agent reads config before every config-dependent action.

---

## Edge Cases

**Config file:**
- Config file missing → create with defaults, no questions
- Config file empty → treat as missing, recreate
- Config has unknown fields → preserve them (user may have custom settings)
- Config file corrupted (not valid markdown) → recreate with defaults, warn user

**Timing:**
- Setting changed mid-session → takes effect at next config-dependent action (not retroactive)
- Toggle enabled mid-session after session-start trigger already fired → won't re-run session-start check. User can run manually: `"check scope"`
- Toggle changed during multi-step pipeline (prepare release) → each step reads fresh config. Later steps see the change.
- Long-running operation already in progress (sync, release) → completes with the config that was active when it started. Config change affects next operation, not current one.

**Remote state:**
- CI disabled locally but remote still has ci.yml → red X continues until next push. Agent warns: "CI disabled locally. Push to remove workflow from remote: `push`"
- CI enabled locally but not yet pushed → workflow only active after push

**Safety warnings:**
- All safety steps disabled (code review + scope check both off) at prepare release → agent warns before Step 4: "⚠ Code review and scope check are both disabled. Releasing without quality gates. Continue? (y/n/enable)"
- Single safety step disabled → show "disabled in config" in release summary (no prompt, just visibility)

**Team:**
- Team member has different config preference → config is per-project not per-user; discuss and agree
- Config committed by one team member, pulled by another → takes effect immediately for the puller
- CI enabled but no billing → workflow created but checks fail; agent detects and suggests: "CI checks failing — disable CI until billing fixed? (`disable ci`)"

---

## Config Format

Project config template (`.portable-spec-kit/config.md`):

```markdown
# Project Config
> Auto-created on first session. Edit anytime.
> Review: say "show config" or "review config"

## CI/CD
- **Enabled:** false
- **Provider:** github-actions
- **Badge in README:** false

## Jira Integration
- **Enabled:** false

## Time Tracking
- **psk-tracker installed:** false

## Code Review
- **Auto on feature completion:** true
- **In release pipeline:** true

## Scope Drift Detection
- **Auto on session start:** true
- **In release pipeline:** true

## Onboarding
- **Tour completed:** false
```

### Config Defaults (all new projects)
| Setting | Default | Why |
|---------|---------|-----|
| CI/CD enabled | `false` | Requires GitHub Actions billing; user enables when ready |
| CI badge in README | `false` | No badge until CI is actually working |
| Jira enabled | `false` | Optional feature; needs credentials first |
| psk-tracker installed | `false` | Optional; updated automatically by install-tracker.sh |
| Code review auto | `true` | Advisory, non-blocking — safe default |
| Code review in pipeline | `true` | Advisory — adds value at no cost |
| Scope drift auto | `true` | Advisory, non-blocking — safe default |
| Scope drift in pipeline | `true` | Advisory — adds value at no cost |
