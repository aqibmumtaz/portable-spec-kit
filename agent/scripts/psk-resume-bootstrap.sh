#!/bin/bash
# workflow-router: drains retry queue + lists paused phases at session start; no AI invocation
# workflow-decl-exempt: session-helper (one-shot session-start status report; no phase sequence,
#   no .portable-spec-kit/workflows/<name>/phases.yml — PSK034-exempt)
# psk-resume-bootstrap.sh — Session-start resume-bootstrap helper.
#
# Implements §Workflow Fidelity → Resume-on-Session-Start MANDATORY rule
# (portable-spec-kit.md, v0.6.60 HF4). On entering any kit project, the
# first agent action MUST be checking for in-progress workflow state and
# draining the retry queue BEFORE responding to the user. This helper
# performs both checks in one call and writes an audit-log marker that
# PSK029 sync-check rule reads to detect skipped session-start checks.
#
# Usage:
#   bash agent/scripts/psk-resume-bootstrap.sh
#
# Behavior:
#   1. Bootstrap-check (run psk-bootstrap-check.sh --quiet if present).
#   2. Drain retry queue (psk-retry-queue.sh drain).
#   3. List paused workflow phases (psk-workflow-state.sh list-paused).
#   4. Run hung-phase watchdog (psk-workflow-watchdog.sh scan) — HF4b
#      (v0.6.60). Non-blocking — watchdog output is informational; HUNG
#      findings auto-enqueue into the retry queue for the next drain.
#   5. Write marker to agent/.workflow-state/session-audit.log
#      (rotated at 1000 lines).
#   6. Print one-line summary. Always exit 0.
#
# Bypass: PSK_RESUME_BOOTSTRAP_DISABLED=1 — emergency only.
# Exit codes: 0 always (status report, not a gate).

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATE_DIR="$PROJ_ROOT/agent/.workflow-state"
AUDIT_LOG="$STATE_DIR/session-audit.log"

# --- Emergency bypass ---
if [ "${PSK_RESUME_BOOTSTRAP_DISABLED:-0}" = "1" ]; then
  # HF9 (v0.6.60): durable bypass-tamper audit trail.
  _bypass_log_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/psk-bypass-log.sh"
  if [ -x "$_bypass_log_script" ]; then
    bash "$_bypass_log_script" log \
      --env-var "PSK_RESUME_BOOTSTRAP_DISABLED" \
      --command "psk-resume-bootstrap.sh $*" \
      --justification "${PSK_BYPASS_REASON:-not provided}" 2>/dev/null || true
  fi
  echo "Resume-bootstrap: disabled via env var."
  exit 0
fi

# --- Step 1: bootstrap-check (tolerate missing) ---
if [ -x "$PROJ_ROOT/agent/scripts/psk-bootstrap-check.sh" ]; then
  bash "$PROJ_ROOT/agent/scripts/psk-bootstrap-check.sh" --quiet 2>/dev/null || true
fi

# --- Step 2: drain retry queue ---
drain_summary="0 entries drained"
drain_count=0
if [ -x "$PROJ_ROOT/agent/scripts/psk-retry-queue.sh" ]; then
  drain_out=$(bash "$PROJ_ROOT/agent/scripts/psk-retry-queue.sh" drain 2>/dev/null || true)
  # Parse "SPAWN:" lines to count dispatched entries
  drain_count=$(printf '%s\n' "$drain_out" | grep -c '^SPAWN:' || true)
  drain_count=$(printf '%s' "$drain_count" | tr -d ' \n\r')
  [ -z "$drain_count" ] && drain_count=0
  # Echo SPAWN lines so caller (agent) sees the dispatch signal
  if [ "$drain_count" -gt 0 ]; then
    echo "$drain_out" | grep '^SPAWN:'
  fi
  drain_summary="$drain_count retry-queue entries drained"
fi

# --- Step 3: list paused workflow phases ---
paused_count=0
paused_summary="0 paused phases"
if [ -x "$PROJ_ROOT/agent/scripts/psk-workflow-state.sh" ]; then
  paused_out=$(bash "$PROJ_ROOT/agent/scripts/psk-workflow-state.sh" list-paused 2>/dev/null || true)
  if [ -n "$paused_out" ]; then
    paused_count=$(printf '%s\n' "$paused_out" | grep -c . || true)
    paused_count=$(printf '%s' "$paused_count" | tr -d ' \n\r')
    [ -z "$paused_count" ] && paused_count=0
    if [ "$paused_count" -gt 0 ]; then
      echo "$paused_out"
    fi
    paused_summary="$paused_count paused phases listed"
  fi
fi

# --- Step 4: run hung-phase watchdog (HF4b) — non-blocking informational ---
watchdog_summary=""
if [ -x "$PROJ_ROOT/agent/scripts/psk-workflow-watchdog.sh" ]; then
  wd_out=$(bash "$PROJ_ROOT/agent/scripts/psk-workflow-watchdog.sh" scan 2>&1 || true)
  if [ -n "$wd_out" ]; then
    echo "$wd_out"
    # Count any [WATCHDOG] HUNG / STALE / WARN lines for the summary
    wd_count=$(printf '%s\n' "$wd_out" | grep -c '^\[WATCHDOG\]' || true)
    wd_count=$(printf '%s' "$wd_count" | tr -d ' \n\r')
    [ -z "$wd_count" ] && wd_count=0
    if [ "$wd_count" -gt 0 ]; then
      watchdog_summary=", $wd_count watchdog findings"
    fi
  fi
fi

# --- Step 5: write audit-log marker (rotate at 1000 lines) ---
mkdir -p "$STATE_DIR"
marker_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "$marker_ts session-start-resume-check ran" >> "$AUDIT_LOG"

# --- Step 5b (cycle-19 HF11 — QA-D22-02-RESIDUAL-AUTODETECT): task-tool-available marker.
# reflex/lib/spawn-qa.sh auto-detect reads this marker. mtime ≤ 24h ⇒ Task
# surface affirmed; mtime > 24h or absent ⇒ assume Task may be absent → fire
# SPAWN_SURFACE_ABSENT gate. Resume-bootstrap is the canonical session-start
# surface, so refreshing the marker here ties Task-availability to "session
# is alive in a Claude Code instance that could spawn sub-agents". Operators
# in external dispatchers should set CLAUDE_TASK_TOOL_AVAILABLE=1 directly
# instead of relying on this marker.
echo "$marker_ts" > "$STATE_DIR/task-tool-available" 2>/dev/null || true

# Rotate: keep only the most recent 1000 lines
if [ -f "$AUDIT_LOG" ]; then
  line_count=$(wc -l < "$AUDIT_LOG" 2>/dev/null | tr -d ' ')
  if [ -n "$line_count" ] && [ "$line_count" -gt 1000 ]; then
    tmp=$(mktemp)
    tail -1000 "$AUDIT_LOG" > "$tmp" 2>/dev/null && mv "$tmp" "$AUDIT_LOG"
  fi
fi

# --- Step 5c (QA-D15-01-CYC26 — stale RUNNING repair): reconcile any
# `.iter-status.yml` entries that say RUNNING/PENDING but whose pass dir
# carries a terminal verdict.md. Idempotent best-effort — silent on clean,
# never blocks resume.
if [ -x "$PROJ_ROOT/reflex/lib/heal-iter-status.sh" ]; then
  bash "$PROJ_ROOT/reflex/lib/heal-iter-status.sh" --apply --quiet >/dev/null 2>&1 || true
fi

# --- Step 6: one-line summary ---
if [ "$drain_count" -eq 0 ] && [ "$paused_count" -eq 0 ] && [ -z "$watchdog_summary" ]; then
  echo "Resume-bootstrap: clean (no in-progress work)."
else
  echo "Resume-bootstrap: $drain_summary, $paused_summary${watchdog_summary}."
fi

exit 0
