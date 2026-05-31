# 30 — Kit Fidelity (8th Reliability Layer)

> **Purpose:** Force every kit-command invocation into its canonical default form, and reframe every friction-point as a kit bug to fix rather than a workaround target. Without this layer, agents quietly substitute convenient command variants for canonical ones (same trust-based failure mode §Spawn Fidelity already closed for sub-agent spawns, repeated one level up at the operator-command surface).

> **Role:** 8th reliability layer. Built in v0.6.64 after recurring agent failure 2026-05-30/31 where the agent picked `reflex/run.sh single` instead of canonical autoloop, then empty marker commit instead of `prepare release`, then stopped after DENIED single-pass instead of iterating.

---

## Overview

The framework's `§Kit Fidelity` section (in `portable-spec-kit.md`) defines two principles applied universally to every kit command:

1. **Canonical default form** — every command runs in its canonical default form unless the user explicitly authorizes a deviation. Deviations require `--rationale "<text>"` (≥20 chars) and land in `agent/.kit-deviation-log` as a committed audit trail.

2. **Friction = kit bug** — when a canonical kit command has friction (precondition fail, version bump unwanted, gate blocks, missing feature), the agent MUST NOT work around it. The friction is the spec for a kit improvement. The agent files a `KIT-GAP-*` entry in `agent/.kit-gap-log`, then either (a) fixes the kit inline + proceeds canonically, or (b) escalates to user with proposed fix.

This layer is enforced structurally, not by trust.

## Flow Diagram

The flow is sequential with one conditional branch in the middle. Each stage is described as a step rather than a box-art diagram to keep the doc renderable in any markdown viewer.

**Step 1 — Operator intent.** Operator (or agent on operator's behalf) wants to run a canonical kit command: `run reflex`, `prepare release`, `init`, `orchestrate`, etc.

**Step 2 — Wrapper invocation.** Per §Kit Fidelity, the command MUST route through `bash agent/scripts/psk-kit-cmd.sh <cmd> [args] [--rationale "<text>"]`. The wrapper reads `.portable-spec-kit/kit-commands.yml` and classifies argv against the canonical default for that command.

**Step 3 — Three-way branch on classification.**

- **(a) CANONICAL** — argv matches the canonical default form. Wrapper exec's the underlying script directly. No log entry needed. Most common path.
- **(b) NON-CANONICAL with `--rationale "<text>"`** — argv contains a variant flag AND user-authored rationale is provided (≥20 chars). Wrapper logs the deviation to `agent/.kit-deviation-log` (TSV: `ts CMD FLAG hash text`), then exec's the underlying script.
- **(c) NON-CANONICAL without `--rationale`** — argv contains a variant flag and no rationale. Wrapper writes `AWAITING_RATIONALE` to stderr with the matched variant + reason + two forward paths (run canonical OR provide rationale), then exits 2. There is no inline-fallback.

**Step 4 — Friction-as-feedback path (separate from above).** When the agent hits friction with a canonical command (gate fail, precondition block, missing feature), the agent's first action is to log a `KIT-GAP-NNNN` entry via `bash agent/scripts/psk-kit-cmd.sh --log-gap <cmd> <friction> <fix>`. This appends one TSV row to `agent/.kit-gap-log` with an auto-incremented gap id. After logging, the agent either (i) fixes the kit inline and re-runs the canonical command, or (ii) escalates to the user with the proposed fix. Workarounds are forbidden even with `--rationale`.

**Step 5 — Post-commit defense-in-depth.** PSK040 sync-check rule (in `agent/scripts/psk-sync-check.sh`) audits the git log since the §Kit Fidelity introduction commit. For every commit whose subject matches a `marker_commit_pattern` from the inventory, PSK040 verifies a matching entry exists in `agent/.kit-deviation-log` (by author-date). Missing entries surface as ADVISORY in `--quick` (PostToolUse hook) and ERROR in `--full` (PreCommit hook — blocks). This catches the case where the agent bypasses the wrapper but commits anyway.

## Components

| Component | File | What it does |
|---|---|---|
| Behavioral rule | `portable-spec-kit.md` §Kit Fidelity | Two principles + 6 enforcement mechanisms + friction-detection examples |
| Wrapper script | `agent/scripts/psk-kit-cmd.sh` | Routes every canonical kit command; pauses on non-canonical without `--rationale` |
| Canonical inventory | `.portable-spec-kit/kit-commands.yml` | Data file listing every command + its canonical default + non-canonical variants |
| Deviation log | `agent/.kit-deviation-log` (committed) | Append-only TSV: `ts CMD FLAG hash text` per `--rationale` invocation |
| Kit-gap log | `agent/.kit-gap-log` (committed) | Append-only TSV: `ts KIT-GAP-NNNN CMD FRICTION FIX` per friction-detected gap |
| Sync-check rule | `agent/scripts/psk-sync-check.sh` `check_psk040_kit_fidelity_coverage()` | Audits git log for marker commits without matching deviation entries |
| Skill | `.portable-spec-kit/skills/kit-fidelity.md` | JIT-loaded protocol guide for agents at AWAITING_RATIONALE |

## Key Rules

### Canonical-command inventory (initial v0.6.64)

| Command | Canonical default | Non-canonical variants (require --rationale) |
|---|---|---|
| `bash reflex/run.sh` | autoloop until convergence | `single`, `--single`, marker-commit shortcuts |
| `bash agent/scripts/psk-release.sh prepare` | full 10-phase ceremony with version bump | `refresh` (no-bump), bypass env vars |
| `bash agent/scripts/psk-init.sh` | registry-driven CREATE-or-REFRESH | partial init |
| `bash agent/scripts/psk-orchestrate.sh build` | full 10-phase orchestration | early-exit phases |
| `bash agent/scripts/psk-feature-complete.sh` | dual-gate critic validation | gate-skip |
| `bash agent/scripts/psk-new-setup.sh` | full setup (Step 0 env-select + 8 steps) | env-skip |
| `bash agent/scripts/psk-existing-setup.sh` | guide-don't-force scan + checklist | force-overwrite |
| `bash agent/scripts/psk-run-plan.sh start <slug>` | schema-validated phase execution | compat-mode |
| `git commit` | regular commit (signed by hook) | `--no-verify`, `--amend` on pushed |
| `git push` | regular push to origin | `--force`, `--force-with-lease`, `--no-verify` |

Operators extend by editing `.portable-spec-kit/kit-commands.yml` directly. PSK040 reads the same file so new entries propagate to detection.

### Friction-detection workflow

When you (or an agent on your behalf) hit friction with a canonical kit command:

1. **STOP.** Do not work around.
2. **Log the friction** via `bash agent/scripts/psk-kit-cmd.sh --log-gap "<cmd>" "<friction>" "<proposed-fix>"`. This appends a `KIT-GAP-NNNN` entry to `agent/.kit-gap-log`.
3. **Then choose**:
   - (a) Fix the kit inline (preferred) — implement the proposed fix, commit it, then proceed canonically with the now-improved command, OR
   - (b) Escalate to user — surface the KIT-GAP id + proposed fix; let user decide whether to implement now or queue for later.

Workarounds are forbidden even with `--rationale` — the rationale flag is for legitimate deviations (debug single-pass, explicit no-bump), not for sidestepping kit gaps.

### Friction-detection examples

| Friction | Wrong response (workaround) | Right response (kit-fidelity) |
|---|---|---|
| `reflex/run.sh` autoloop's iter-1 prep-release would bump v0.6.63 → v0.6.64 too soon | Switch to `single` mode | Log `KIT-GAP: autoloop iter-1 bump cadence too aggressive after manual release`. Propose: add `--bump-after-grant` flag |
| `psk-release.sh prepare` Phase 1 tests fail on a clock-bound test | Bypass via `PSK_SYNC_CHECK_DISABLED=1` | Log `KIT-GAP-N69: optimize age-escalation overrides deferred state`. Fix the underlying test logic |
| Reflex preconditions HEAD-pattern check blocks because HEAD is a chore commit | Empty marker commit `v0.6.X: marker` | Log `KIT-GAP: HEAD-pattern check should accept post-release chore commits`. Either widen the check or escalate |
| `psk-run-plan.sh start` refuses because plan lacks `phases:` schema | Edit plan to add fake `phases:` array | Log `KIT-GAP: narrative plans need explicit compat-mode path`. Improve compat-mode UX |
| `psk-init.sh` re-creates a file user manually customized | Skip via env var | Log `KIT-GAP: init content-loss protection should detect user customization`. Harden the snapshot check |

### Wrapper subcommands

```bash
# Canonical invocation (no rationale needed)
bash agent/scripts/psk-kit-cmd.sh reflex
bash agent/scripts/psk-kit-cmd.sh prepare-release
bash agent/scripts/psk-kit-cmd.sh init

# Non-canonical (rationale required)
bash agent/scripts/psk-kit-cmd.sh reflex single --rationale "operator approved single-pass for cycle-22 debug"
bash agent/scripts/psk-kit-cmd.sh prepare-release --rationale "user explicitly requested no-bump per ADR-NNN"

# Inspection
bash agent/scripts/psk-kit-cmd.sh --list             # show canonical inventory
bash agent/scripts/psk-kit-cmd.sh --check reflex single   # dry-run: would this require rationale?

# Friction logging (file a KIT-GAP without running)
bash agent/scripts/psk-kit-cmd.sh --log-gap "reflex" \
  "autoloop bumps version too aggressively after manual release" \
  "add --bump-after-grant flag so version bump moves to convergence-final ceremony"
```

### Emergency bypass

`PSK_KIT_FIDELITY_DISABLED=1 bash agent/scripts/psk-kit-cmd.sh ...` skips wrapper enforcement on a single invocation and logs to `.bypass-log` per PSK027. For genuine emergencies only — repeated bypassing surfaces as ERROR in sync-check.

`PSK_PSK040_DISABLED=1` skips the sync-check rule (same emergency-only semantics).

## Integration with other reliability layers

| Layer | How §Kit Fidelity relates |
|---|---|
| 2A — Bash Critic (`psk-sync-check.sh`) | PSK040 is a new rule in this critic — defense-in-depth alongside the wrapper |
| 2B — Sub-Agent Critic | Unchanged; §Kit Fidelity operates at command-invocation, not workflow-end |
| 3 — Hooks (PostToolUse + PreCommit) | PSK040 fires in both via the standard hook routing — ADVISORY in --quick (Post), ERROR in --full (Pre) |
| 4 — §Workflow Fidelity | Complementary: §Workflow Fidelity governs HOW a workflow's phases execute; §Kit Fidelity governs HOW a workflow gets INVOKED in the first place |
| 5 — §Plan Execution | Complementary: §Plan Execution is one inventory entry (`run-plan`) in §Kit Fidelity's command list |
| 6 — §Spawn Fidelity | Mirror pattern: §Spawn Fidelity = no inline-fallback for sub-agent spawns; §Kit Fidelity = no workaround for kit-command invocations |
| 7 — §Workflow Declaration | Complementary: §Workflow Declaration data-drives WHAT a workflow's phases are; §Kit Fidelity data-drives WHAT a kit-command's canonical form is |

## Edge cases

1. **Bootstrapping.** Implementing §Kit Fidelity itself required kit commands. PSK040 grandfathers all commits before the §Kit Fidelity introduction commit (detected dynamically via `git log -S '^## Kit Fidelity '` on `portable-spec-kit.md`).

2. **--rationale text quality.** The wrapper rejects rationales <20 chars. Stub rationales ("test", "todo") would defeat the audit-trail purpose.

3. **Multi-deviation in single command.** E.g. `reflex/run.sh single --no-bump` has two deviations. The wrapper detects the FIRST matching variant and pauses on it. After rationale is provided + logged, if execution surfaces a second deviation in argv, the wrapper re-pauses for that one too (per-deviation rationale).

4. **Wrapper not in PATH.** If agent invokes `bash reflex/run.sh single` directly (bypassing `psk-kit-cmd.sh`), PSK040 catches it post-commit via the marker-commit-pattern audit. Wrapper for prevention; PSK040 for detection.

5. **New commands added after v0.6.64.** Every new kit command MUST register its canonical default form in `.portable-spec-kit/kit-commands.yml` in the same commit that ships the command. This is enforced by §Kit Fidelity's "Covered surfaces" clause in the framework.

## Bypass log (PSK027 integration)

`PSK_KIT_FIDELITY_DISABLED=1` and `PSK_PSK040_DISABLED=1` invocations are logged to `agent/.bypass-log`. PSK027 sync-check rule already surfaces bypass-log entries from the last 24h as ADVISORY warnings; repeated bypass-abuse escalates to ERROR.

## See also

- `portable-spec-kit.md` §Kit Fidelity — the canonical rule
- `.portable-spec-kit/skills/kit-fidelity.md` — JIT-loaded protocol guide
- `agent/scripts/psk-kit-cmd.sh` — wrapper implementation
- `.portable-spec-kit/kit-commands.yml` — canonical inventory (extensible)
- `agent/.kit-deviation-log` — committed audit trail
- `agent/.kit-gap-log` — friction-as-feedback ledger
- `agent/scripts/psk-sync-check.sh` `check_psk040_kit_fidelity_coverage()` — defense-in-depth detection
- `docs/work-flows/25-workflow-fidelity.md` — sibling layer (process shape)
- `docs/work-flows/26-plan-execution-protocol.md` — sibling layer (plan shape)
- `docs/work-flows/28-spawn-fidelity.md` — sibling layer (spawn shape — same no-inline-fallback pattern)
- `docs/work-flows/29-workflow-declaration-schema.md` — sibling layer (workflow shape)
