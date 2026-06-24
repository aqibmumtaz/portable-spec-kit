#!/bin/bash
# mechanical-script: deterministic phase-mtime probe; no AI invocation
# psk-workflow-watchdog.sh — Hung-phase detector for workflow state machine.
#
# Implements §Workflow Fidelity HF4b (portable-spec-kit.md / v0.6.60). Scans
# agent/.workflow-state/*.state files for phases that have been stuck in
# AWAITING:* status longer than configurable thresholds. Reports findings
# and, for HUNG phases, persists them to the HF3 retry queue so durable
# storage takes over even when psk-spawn.sh did not enqueue.
#
# Not a daemon — designed to be invoked on demand (by psk-resume-bootstrap.sh,
# operator manually, or CI).
#
# Commands:
#   scan (default)          — walk state files, classify by age, print findings
#   list                    — print every paused phase regardless of age
#   kick <workflow> <phase> — force re-emit SPAWN signal for the named phase
#   --health                — one-line health summary
#
# Threshold tiers (env-configurable):
#   0-15 min                normal       (not flagged)
#   15-60 min (WARN_AFTER)  WARN         log + stdout
#   60+ min   (HUNG_AFTER)  HUNG         log + stderr + enqueue
#   24+ hours (STALE_AFTER) STALE        log + stderr + manual-recovery hint
#
# Env vars (defaults shown):
#   PSK_WATCHDOG_WARN_AFTER_SEC   = 900     (15 min)
#   PSK_WATCHDOG_HUNG_AFTER_SEC   = 3600    (60 min)
#   PSK_WATCHDOG_STALE_AFTER_SEC  = 86400   (24 h)
#   PSK_WATCHDOG_LOG_MAX_LINES    = 5000
#
# Output format (per paused phase):
#   [WATCHDOG] <status> · workflow=<name> · phase=<phase-id> · paused_for=<dur> · reason=<reason>
#
# Exit codes:
#   0  no hung phases (all WARN-or-below)
#   1  at least one HUNG (60+ min)
#   2  at least one STALE (24+ h)
#   3  scan error (state file unreadable)

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATE_DIR="$PROJ_ROOT/agent/.workflow-state"
LOG_FILE="$STATE_DIR/watchdog.log"
RETRY_QUEUE_SCRIPT="$PROJ_ROOT/agent/scripts/psk-retry-queue.sh"
SPAWN_SCRIPT="$PROJ_ROOT/agent/scripts/psk-spawn.sh"

WARN_AFTER_SEC="${PSK_WATCHDOG_WARN_AFTER_SEC:-900}"
HUNG_AFTER_SEC="${PSK_WATCHDOG_HUNG_AFTER_SEC:-3600}"
STALE_AFTER_SEC="${PSK_WATCHDOG_STALE_AFTER_SEC:-86400}"
LOG_MAX_LINES="${PSK_WATCHDOG_LOG_MAX_LINES:-5000}"

_now_epoch() { date -u +%s; }
_now_iso()   { date -u +%Y-%m-%dT%H:%M:%SZ; }

_log_entry() {
  # <ISO-8601-UTC> <status> workflow=<name> phase=<phase> paused_for_sec=<N> reason=<short>
  local status="$1" wf="$2" phase="$3" elapsed="$4" reason="$5"
  mkdir -p "$STATE_DIR"
  echo "$(_now_iso) $status workflow=$wf phase=$phase paused_for_sec=$elapsed reason=$reason" >> "$LOG_FILE"
  # Rotation — cap log size
  if [ -f "$LOG_FILE" ]; then
    local n
    n=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d ' ')
    if [ -n "$n" ] && [ "$n" -gt "$LOG_MAX_LINES" ]; then
      local tmp; tmp=$(mktemp)
      tail -"$LOG_MAX_LINES" "$LOG_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$LOG_FILE"
    fi
  fi
}

_fmt_duration() {
  # Convert seconds to "Nh Mm" / "Mm Ss" string for readability
  local s="$1"
  if [ "$s" -ge 86400 ]; then
    local d=$(( s / 86400 ))
    local h=$(( (s % 86400) / 3600 ))
    echo "${d}d${h}h"
  elif [ "$s" -ge 3600 ]; then
    local h=$(( s / 3600 ))
    local m=$(( (s % 3600) / 60 ))
    echo "${h}h${m}m"
  elif [ "$s" -ge 60 ]; then
    local m=$(( s / 60 ))
    local sec=$(( s % 60 ))
    echo "${m}m${sec}s"
  else
    echo "${s}s"
  fi
}

# Parse STARTED=<ISO> from a state file into epoch seconds. Returns 0 on error.
_state_started_epoch() {
  local sf="$1"
  local iso
  iso=$(grep '^STARTED=' "$sf" 2>/dev/null | head -1 | cut -d= -f2-)
  [ -z "$iso" ] && { echo 0; return; }
  python3 -c "
import re, calendar, sys
m = re.match(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z\$', '''$iso'''.strip())
if not m:
    print(0); sys.exit(0)
p = [int(x) for x in m.groups()]
print(calendar.timegm((p[0], p[1], p[2], p[3], p[4], p[5], 0, 0, 0)))
" 2>/dev/null || echo 0
}

# Find the most-recent GATE_PASSED_<phase>=<epoch> marker in a state file
# (any phase). Used as a fresher lower-bound on "when did this phase start
# waiting?" than the workflow-level STARTED= when prior phases have closed.
_state_last_gate_epoch() {
  local sf="$1"
  grep '^GATE_PASSED_' "$sf" 2>/dev/null \
    | awk -F= '{print $2}' \
    | sort -n \
    | tail -1
}

# Pause-anchor epoch: max(STARTED, latest GATE_PASSED_*). Fallback to 0.
_pause_anchor_epoch() {
  local sf="$1"
  local started; started=$(_state_started_epoch "$sf")
  local gated;   gated=$(_state_last_gate_epoch "$sf")
  [ -z "$started" ] && started=0
  [ -z "$gated" ] && gated=0
  if [ "$gated" -gt "$started" ]; then
    echo "$gated"
  else
    echo "$started"
  fi
}

# Classify elapsed seconds → status
_classify() {
  local elapsed="$1"
  if [ "$elapsed" -ge "$STALE_AFTER_SEC" ]; then
    echo "STALE"
  elif [ "$elapsed" -ge "$HUNG_AFTER_SEC" ]; then
    echo "HUNG"
  elif [ "$elapsed" -ge "$WARN_AFTER_SEC" ]; then
    echo "WARN"
  else
    echo "OK"
  fi
}

# Check whether (workflow, phase) already has a retry-queue entry.
_already_queued() {
  local wf="$1" phase="$2"
  [ -x "$RETRY_QUEUE_SCRIPT" ] || return 1
  bash "$RETRY_QUEUE_SCRIPT" list 2>/dev/null \
    | awk -v w="$wf" -v p="$phase" '
        # Header lines start with "ID " or "---"; skip
        NR <= 2 { next }
        {
          # Columns are space-separated; columns 2 and 3 are workflow and phase
          # (psk-retry-queue list uses fixed-width columns; collapse multi-spaces)
          gsub(/  +/, "\t")
          n = split($0, f, "\t")
          if (f[2] == w && f[3] == p) { found = 1; exit }
        }
        END { exit (found ? 0 : 1) }
      '
}

# Enqueue a HUNG finding into the retry queue. Best-effort — psk-retry-queue.sh
# enforces idempotency on (wf, phase, target).
_enqueue_hung() {
  local wf="$1" phase="$2"
  [ -x "$RETRY_QUEUE_SCRIPT" ] || return 0
  # Resolve prompt + artifact paths from the spawn request, if present.
  local req="$STATE_DIR/spawn/${wf}.${phase}.request"
  local prompt_file="unknown" artifact_file="unknown"
  if [ -f "$req" ]; then
    prompt_file=$(grep '^PROMPT_FILE=' "$req" 2>/dev/null | head -1 | cut -d= -f2-)
    artifact_file=$(grep '^RESULT_ARTIFACT=' "$req" 2>/dev/null | head -1 | cut -d= -f2-)
    [ -z "$prompt_file" ]   && prompt_file="unknown"
    [ -z "$artifact_file" ] && artifact_file="unknown"
  fi
  # Classify spawn_target by workflow naming
  local target="subagent"
  case "$wf" in
    *critic*)         target="critic-agent" ;;
    reflex|*reflex*)
      case "$phase" in
        qa*|*qa*)   target="qa-agent" ;;
        dev*|*dev*) target="dev-agent" ;;
        *)          target="subagent" ;;
      esac ;;
    *orchestrate*)    target="orchestrate-phase" ;;
    run-plan-*)       target="plan-phase-agent" ;;
    *feature*)        target="feature-spawn" ;;
  esac
  bash "$RETRY_QUEUE_SCRIPT" add "$wf" "$phase" "$target" \
    "$prompt_file" "$artifact_file" "watchdog: HUNG detected" >/dev/null 2>&1 || true
}

# Walk every <workflow>.state file. Emit one row per AWAITING:* phase, with
# status classification + elapsed seconds.
# Output rows on stdout: <status>\t<wf>\t<phase>\t<elapsed>\t<reason>
_collect_paused() {
  [ -d "$STATE_DIR" ] || return 0
  local f wf phase status val anchor now elapsed cls reason
  now=$(_now_epoch)
  for f in "$STATE_DIR"/*.state; do
    [ -f "$f" ] || continue
    wf=$(basename "$f" .state)
    # Completed reflex passes retain vestigial PHASE_qa=AWAITING:SUBAGENT_SPAWN in
    # their .state files even after the pass finished (the pass writes verdict.md
    # but does not rewrite the phase markers). Cross-check verdict.md so a finished
    # pass is not mis-flagged as STALE/HUNG. Workflow name reflex-pass-cycle-NN-pass-NNN
    # maps to reflex/history/cycle-NN/pass-NNN/verdict.md.
    case "$wf" in
      reflex-pass-cycle-*-pass-*)
        local rel verdict passdir
        rel="${wf#reflex-pass-}"          # cycle-NN-pass-NNN
        rel="${rel/-pass-//pass-}"        # cycle-NN/pass-NNN
        verdict="$PROJ_ROOT/reflex/history/$rel/verdict.md"
        passdir="$PROJ_ROOT/reflex/history/$rel"
        [ -f "$verdict" ] && continue     # pass finished — not a hung phase
        # KIT-GAP (QA-D30-STALE-STATE-ACCUMULATION-01): when history-retention
        # prunes an old pass dir, its agent/.workflow-state/*.state file is NOT
        # pruned with it. The verdict.md guard above then fails (verdict.md was
        # pruned with the dir), so the watchdog mis-classifies a SUPERSEDED pass
        # as HUNG and re-enqueues its vestigial AWAITING phases on every session
        # start — the retry queue accumulates stale prior-cycle entries forever.
        # Generic fix: a reflex pass whose history dir no longer exists is pruned/
        # superseded, not hung. Skip it AND retire its orphan .state so the queue
        # self-cleans. Applies to ANY kit project running multiple reflex cycles.
        if [ ! -d "$passdir" ]; then
          if [ "${WATCHDOG_DRY_RUN:-0}" != "1" ]; then
            mv -f "$f" "${f}.superseded" 2>/dev/null || true
          fi
          continue
        fi
        ;;
    esac
    anchor=$(_pause_anchor_epoch "$f")
    [ "$anchor" -le 0 ] && anchor=$now    # no anchor → treat as just-paused
    elapsed=$(( now - anchor ))
    [ "$elapsed" -lt 0 ] && elapsed=0
    while IFS='=' read -r key val; do
      case "$key" in
        PHASE_*)
          phase="${key#PHASE_}"
          case "$val" in
            AWAITING:*|AWAITING_SUBAGENT_RETRY:*)
              reason="${val#AWAITING:}"
              reason="${reason#AWAITING_SUBAGENT_RETRY:}"
              cls=$(_classify "$elapsed")
              printf '%s\t%s\t%s\t%s\t%s\n' "$cls" "$wf" "$phase" "$elapsed" "$reason"
              ;;
            in_progress|in-progress|IN_PROGRESS|running|RUNNING)
              # G25 (QA-D26-001): a phase stuck `in_progress` past the hung threshold is a
              # hung phase too — not only AWAITING:* spawn-pauses. Legacy / run-plan state
              # machines mark active phases `in_progress`; without this branch a phase stuck
              # in_progress for weeks (e.g. workflow-fidelity-plan PHASE_B_v0657, ~29d) is
              # never surfaced or auto-enqueued. Filter cls=OK so a freshly-started, healthy
              # in_progress phase is not spuriously listed — only WARN/HUNG/STALE surface.
              cls=$(_classify "$elapsed")
              case "$cls" in
                OK) ;;
                *) printf '%s\t%s\t%s\t%s\t%s\n' "$cls" "$wf" "$phase" "$elapsed" "in_progress" ;;
              esac
              ;;
          esac
          ;;
      esac
    done < "$f" 2>/dev/null || { return 3; }
  done
}

cmd_scan() {
  local rows
  rows=$(_collect_paused)
  local scan_rc=$?
  if [ "$scan_rc" -eq 3 ]; then
    echo "[WATCHDOG] scan error reading state files" >&2
    return 3
  fi
  if [ -z "$rows" ]; then
    return 0
  fi
  local worst=0    # 0=OK 1=WARN 2=HUNG 3=STALE
  local cls wf phase elapsed reason
  while IFS=$'\t' read -r cls wf phase elapsed reason; do
    [ -z "$cls" ] && continue
    if [ "$cls" = "OK" ]; then
      continue
    fi
    local dur; dur=$(_fmt_duration "$elapsed")
    local line="[WATCHDOG] $cls · workflow=$wf · phase=$phase · paused_for=$dur · reason=$reason"
    case "$cls" in
      WARN)
        echo "$line"
        _log_entry WARN "$wf" "$phase" "$elapsed" "$reason"
        [ "$worst" -lt 1 ] && worst=1
        ;;
      HUNG)
        echo "$line" >&2
        _log_entry HUNG "$wf" "$phase" "$elapsed" "$reason"
        # Idempotent enqueue
        if ! _already_queued "$wf" "$phase"; then
          _enqueue_hung "$wf" "$phase"
        fi
        [ "$worst" -lt 2 ] && worst=2
        ;;
      STALE)
        echo "$line" >&2
        echo "  → STALE: recommend manual operator intervention (>24h paused)" >&2
        _log_entry STALE "$wf" "$phase" "$elapsed" "$reason"
        if ! _already_queued "$wf" "$phase"; then
          _enqueue_hung "$wf" "$phase"
        fi
        worst=3
        ;;
    esac
  done <<EOF
$rows
EOF
  case "$worst" in
    0) return 0 ;;
    1) return 0 ;;     # WARN-only → still exit 0 (informational)
    2) return 1 ;;     # HUNG
    3) return 2 ;;     # STALE
  esac
}

cmd_list() {
  local rows
  rows=$(_collect_paused)
  local rc=$?
  if [ "$rc" -eq 3 ]; then
    echo "[WATCHDOG] scan error reading state files" >&2
    return 3
  fi
  if [ -z "$rows" ]; then
    echo "(no paused phases)"
    return 0
  fi
  printf '%-7s  %-32s  %-22s  %-10s  %s\n' "STATUS" "WORKFLOW" "PHASE" "PAUSED_FOR" "REASON"
  printf '%s\n' "-------  --------------------------------  ----------------------  ----------  ------"
  local cls wf phase elapsed reason
  while IFS=$'\t' read -r cls wf phase elapsed reason; do
    [ -z "$cls" ] && continue
    local dur; dur=$(_fmt_duration "$elapsed")
    printf '%-7s  %-32s  %-22s  %-10s  %s\n' "$cls" "$wf" "$phase" "$dur" "$reason"
  done <<EOF
$rows
EOF
  return 0
}

cmd_kick() {
  local wf="${1:-}" phase="${2:-}"
  if [ -z "$wf" ] || [ -z "$phase" ]; then
    echo "usage: psk-workflow-watchdog.sh kick <workflow> <phase>" >&2
    return 2
  fi
  local sf="$STATE_DIR/${wf}.state"
  if [ ! -f "$sf" ]; then
    echo "no state file for workflow '$wf' ($sf)" >&2
    return 1
  fi
  # Confirm the phase is currently paused
  local val
  val=$(grep "^PHASE_${phase}=" "$sf" 2>/dev/null | head -1 | cut -d= -f2-)
  case "$val" in
    AWAITING:*|AWAITING_SUBAGENT_RETRY:*) ;;
    "")
      echo "phase '$phase' not found in workflow '$wf'" >&2; return 1 ;;
    *)
      echo "phase '$phase' is not paused (current status: $val) — refusing to kick" >&2
      return 1 ;;
  esac
  # Re-emit a SPAWN signal by reading the original spawn request, if any.
  local req="$STATE_DIR/spawn/${wf}.${phase}.request"
  local prompt artifact
  if [ -f "$req" ]; then
    prompt=$(grep '^PROMPT_FILE=' "$req" 2>/dev/null | head -1 | cut -d= -f2-)
    artifact=$(grep '^RESULT_ARTIFACT=' "$req" 2>/dev/null | head -1 | cut -d= -f2-)
  fi
  echo "SPAWN: phase=$phase workflow=$wf prompt=${prompt:-unknown} artifact=${artifact:-unknown}"
  echo ""
  echo "  WATCHDOG KICK — operator-forced retry for paused phase '$phase'"
  echo "  Re-spawn the sub-agent with the original prompt (no inline-fallback)."
  _log_entry KICK "$wf" "$phase" 0 "operator-kick"
  return 0
}

cmd_health() {
  local rows
  rows=$(_collect_paused 2>/dev/null)
  if [ -z "$rows" ]; then
    echo "psk-watchdog: 0 paused phases"
    return 0
  fi
  local warn=0 hung=0 stale=0
  local cls _wf _ph _e _r
  while IFS=$'\t' read -r cls _wf _ph _e _r; do
    case "$cls" in
      WARN)  warn=$((warn+1)) ;;
      HUNG)  hung=$((hung+1)) ;;
      STALE) stale=$((stale+1)) ;;
    esac
  done <<EOF
$rows
EOF
  echo "psk-watchdog: $warn WARN, $hung HUNG, $stale STALE"
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatch
# ─────────────────────────────────────────────────────────────────────────────

case "${1:-scan}" in
  scan)       shift 2>/dev/null || true; cmd_scan ;;
  list)       shift; cmd_list ;;
  kick)       shift; cmd_kick "$@" ;;
  --health|health) cmd_health ;;
  -h|--help)
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "unknown subcommand: $1" >&2
    echo "run with --help for usage" >&2
    exit 2
    ;;
esac
