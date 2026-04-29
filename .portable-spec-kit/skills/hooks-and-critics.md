# Skill: Hooks & Critics — Reliability Architecture

> **Loaded when:** Agent interacts with psk-release.sh, psk-sync-check.sh, or critic protocol.

## Reliability Model — dual critic at the end of each workflow

A workflow runs its steps normally. At the end it enters a single **validation gate** that pairs two critics. Both must pass for the workflow to complete. This is not "critic at every step" and not "critic only at Step 9 of release" — it is **dual at the end of each workflow**.

**All six executable workflows covered by a single helper — `psk-validate.sh`:**

| Workflow | Command | Critic template |
|----------|---------|-----------------|
| Release (Step 9) | `psk-validate.sh release` | `STEP_9_VALIDATION` |
| Feature completion | `psk-validate.sh feature-complete` | `FEATURE_COMPLETE` |
| Init | `psk-validate.sh init` | `INIT` |
| Reinit | `psk-validate.sh reinit` | `REINIT` |
| New project setup | `psk-validate.sh new-setup` | `NEW_SETUP` |
| Existing project setup | `psk-validate.sh existing-setup` | `EXISTING_SETUP` |

The same helper runs both critics identically across workflows. Each critic template has workflow-specific checks (e.g. `FEATURE_COMPLETE` verifies R→F→T and ADL; `INIT` verifies all 9 agent/* files populated from code; `REINIT` verifies no content was lost during re-sync).

**Exit codes from psk-validate.sh:**
- `0` — both gates passed; workflow complete
- `1` — bash critic failed; fix mismatches, re-run
- `2` — `AWAITING_CRITIC`; agent spawns sub-agent, writes result, re-runs
- `3` — sub-agent critic found `STALE:` lines; fix flagged items, clear result, re-run
- `4` — usage error (unknown workflow)

## Overview

The kit uses three layers to prevent agents from skipping steps or shipping stale content:

1. **Layer 2A — Bash Critic (`psk-sync-check.sh`):** deterministic, always on. Runs 11 structural checks across all files. Returns specific mismatches with file:line references and PSK error codes. Fires during workflow steps and again at the final validation gate.

2. **Layer 2B — Sub-Agent Critic (`psk-critic-spawn.sh`):** semantic, at workflow end. At the final validation gate, the workflow script writes a task file and exits AWAITING_CRITIC. The agent spawns a fresh sub-agent via Task tool — no inherited context from the main session. The sub-agent reads files independently and writes `critic-result.md` with `CURRENT:` / `STALE:` verdicts. Only on agents that expose a sub-agent spawn tool (Claude Code, Cursor Task mode). Degrades gracefully elsewhere via `PSK_CRITIC_DISABLED=1`.

3. **Layer 3 — Hooks:** PostToolUse warns on every Write/Edit (silent on clean). PreCommit BLOCKS bad commits. Both fire automatically — agent cannot skip them.

## psk-sync-check.sh Usage

```bash
bash agent/scripts/psk-sync-check.sh --quick                   # version + test count (<500ms)
bash agent/scripts/psk-sync-check.sh --full                     # all 11 checks
bash agent/scripts/psk-sync-check.sh --ci                       # non-interactive exit 1 on issues
bash agent/scripts/psk-sync-check.sh --mode kit                 # override auto-detection
bash agent/scripts/psk-sync-check.sh --verify-refactor <term>   # find stragglers after rename
bash agent/scripts/psk-sync-check.sh --help                     # show error codes
```

Error codes: PSK001 (version), PSK002 (test count), PSK003 (flow count), PSK004 (feature count — cross-file), PSK004B (SPECS staleness vs TASKS), PSK005 (R→F→T), PSK006 (script perms), PSK007 (required dirs), PSK008 (CHANGELOG/RELEASES content — version + ≥3 items), PSK009 (ARD content — minor version section exists), PSK010 (AGENT.md Stack — matches package.json/requirements.txt), PSK011 (secrets detected — API keys, private keys, tokens in tracked files).

Emergency bypass: `PSK_SYNC_CHECK_DISABLED=1` (bash critic), `PSK_CRITIC_DISABLED=1` (sub-agent critic), `git commit --no-verify` (PreCommit hook). Each bypass breaks a gate and should be explicit.

## psk-install-hooks.sh Usage

```bash
bash agent/scripts/psk-install-hooks.sh           # install hooks (wraps existing)
bash agent/scripts/psk-install-hooks.sh --force    # reinstall even if present
bash agent/scripts/psk-install-hooks.sh --status   # check what's installed
```

Detects and wraps existing hooks (Husky, pre-commit framework, custom). Never overwrites.

## Critic Protocol (Sub-Agent) — at the final validation gate

When a workflow's final validation step runs, the dual gate fires in this order:

1. **Bash critic first.** Script runs `psk-sync-check.sh --full`. Exit 1 → script reports specific file:line mismatches and halts. Agent fixes, re-runs. No sub-agent is spawned while bash fails — no point asking a sub-agent to read content that is mechanically inconsistent.
2. **Sub-agent critic second.** Once bash passes, script writes `agent/.release-state/critic-task.md` and exits AWAITING_CRITIC.
3. **Main agent MUST:**
   - Read `agent/.release-state/critic-task.md`
   - Spawn sub-agent via Task tool (Explore type, read-only) with the exact prompt from that file
   - Write sub-agent response to `agent/.release-state/critic-result.md`
   - Re-run the workflow `next` command (not `done` — the gate re-reads the result file and advances itself)
4. **Script verifies the critic result:**
   - Freshness: `critic-result.md` mtime ≥ RUN_ID (prevents stale file from prior workflow run satisfying this gate)
   - Structure: file must contain at least one `CURRENT:` or `STALE:` line (empty file fails)
   - Verdict: zero `STALE:` lines → gate passes; any `STALE:` → gate fails, agent fixes flagged issues, iterates
5. **Iteration cap:** 5 sub-agent spawns per gate. After that, the release halts and requires explicit user intervention.
6. **On `prepare`**, prior `critic-task.md`, `critic-result.md`, and iteration counter are deleted so each run starts with a clean state.

**Critic result format:**
```
CURRENT: 01-first-session-workspace.md
CURRENT: 02-user-profile-setup.md
STALE: 13-release-workflow.md:47 — "Step 4: SYSTEM VALIDATION" but current has validation at Step 9
CURRENT: 14-team-collaboration.md
```

**Iteration cap:** 5 attempts per step. After 5 failures → escalates to human review.

**Non-Claude-Code fallback:** Skip critic, show warning: "Semantic check skipped — not running on Claude Code. Manual review recommended."

## Critic Spawn Points in Release Flow

| Step | What critic verifies |
|------|---------------------|
| 4. Flow Docs | "Does each flow doc describe the CURRENT process?" |
| 8. RELEASES + CHANGELOG | "Does the prose match what actually shipped (git log)?" |
| 9. Final Validation | "Comprehensive sweep — anything earlier critics missed?" |

## For End Users (Customization)

### Custom sync checks

Create `.portable-spec-kit/sync-check-config.md`:
```markdown
# Sync Check Config — My App

## Checks to run
- version: README.md, package.json, src/version.ts
- test-count: README.md badge
```

### Custom critic prompts

Create files in `.portable-spec-kit/critics/`:
```yaml
---
step: STEP_4_FLOW_DOCS
---
You are a flow-docs verification critic.
Read every file in docs/work-flows/.
For each, verify it describes the CURRENT 10-step release process.
Report: CURRENT or STALE with file:line and reason.
```
