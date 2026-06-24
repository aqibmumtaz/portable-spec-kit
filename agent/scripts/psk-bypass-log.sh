#!/bin/bash
# mechanical-script: deterministic append-only audit log; no AI invocation
# =============================================================
# psk-bypass-log.sh — Bypass-tamper audit log (HF9 v0.6.60)
#
# Every PSK_*_DISABLED / *_FORCE / *_GATE_DISABLED invocation in
# the kit calls `psk-bypass-log.sh log` immediately after the
# bypass-condition check. Each invocation is durably persisted
# to agent/.bypass-log (JSONL — one record per line).
#
# Bypasses remain ALWAYS available for genuine emergencies, but
# every use is captured. PSK027 sync-check surfaces patterns:
#   1–2 bypasses in 24h → WARNING
#   3+ bypasses in 24h  → ERROR
#   10+ bypasses in 7d  → ERROR (structural abuse)
#
# Usage:
#   bash agent/scripts/psk-bypass-log.sh log \
#     --env-var <NAME> \
#     --command "$0 $*" \
#     [--justification <text>]
#
#   bash agent/scripts/psk-bypass-log.sh list [--since-days N]
#   bash agent/scripts/psk-bypass-log.sh count [--since-days N]
#   bash agent/scripts/psk-bypass-log.sh clear [--confirm]
#
# Log format (JSONL — newline-delimited JSON):
#   {"timestamp":"YYYY-MM-DDTHH:MM:SSZ","env_var":"...","command":"...","justification":"...","caller_pid":N,"user":"..."}
#
# Why JSONL (not YAML):
#   - Append-only writes are atomic (one >> per record)
#   - Each line is self-contained — no parser-state-required
#   - Concurrent kit scripts can append without conflict
#   - grep / tail / awk friendly for the sync-check count probe
#
# Log rotation:
#   When entries exceed 1000, the file is truncated to the most
#   recent 1000 records (tail-rotation mirrors HF4 session-audit.log).
#
# This script NEVER reads secrets. Logged commands may contain
# script paths and env-var NAMES only — secret VALUES never enter
# the log.
# =============================================================

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LOG_FILE="$PROJ_ROOT/agent/.bypass-log"
MAX_ENTRIES=1000
DEFAULT_SINCE_DAYS=7

usage() {
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
}

# Escape a string for inclusion in JSON (handles backslash, quote, control chars)
json_escape() {
  python3 -c "
import json, sys
s = sys.stdin.read()
# json.dumps emits surrounding quotes; strip them — we paste the body raw
print(json.dumps(s)[1:-1], end='')
" 2>/dev/null
}

# Convert ISO-8601 Z timestamp to epoch seconds (BSD/GNU portable)
iso_to_epoch() {
  python3 -c "
import sys, re, calendar
s = sys.argv[1].strip() if len(sys.argv) > 1 else ''
m = re.match(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z\$', s)
if m:
    p = [int(x) for x in m.groups()]
    print(calendar.timegm((p[0],p[1],p[2],p[3],p[4],p[5],0,0,0)))
else:
    print(0)
" "$1" 2>/dev/null || echo 0
}

rotate_if_needed() {
  [ -f "$LOG_FILE" ] || return 0
  local line_count
  line_count=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d ' ')
  if [ -n "$line_count" ] && [ "$line_count" -gt "$MAX_ENTRIES" ]; then
    local tmp="${LOG_FILE}.tmp.$$"
    tail -n "$MAX_ENTRIES" "$LOG_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$LOG_FILE"
  fi
}

cmd_log() {
  local env_var="" command="" justification=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --env-var)        shift; env_var="${1:-}" ;;
      --command)        shift; command="${1:-}" ;;
      --justification)  shift; justification="${1:-}" ;;
      *) echo "log: unknown arg: $1" >&2; exit 1 ;;
    esac
    shift || true
  done

  if [ -z "$env_var" ] || [ -z "$command" ]; then
    echo "log: --env-var and --command are required" >&2
    return 1
  fi

  # Default justification (precedence): a REAL explicit --justification arg >
  # PSK_BYPASS_REASON env var > self-test auto-tag > "not provided".
  # QA-D7-PSK027-RATIONALE-GAP fix (v0.6.83): an explicit operator reason always
  # wins. Only a REASONLESS bypass inside the kit's own test suite
  # (PSK_BYPASS_SELFTEST=1, exported by tests/lib.sh) is auto-tagged
  # `self-test:<env-var>`, which PSK027's count then excludes via
  # `--exclude-selftest`, so test-infrastructure bypasses don't inflate the
  # undocumented-bypass-abuse signal.
  #
  # QA-D21-003 fix (cycle-01-pass-005): the kit's own ~18 caller sites invoke
  # this logger with `--justification "${PSK_BYPASS_REASON:-not provided}"`,
  # i.e. they ALWAYS pass a non-empty value ("not provided" when the env var is
  # unset). That defeated the precedence below — the auto-tag + env-var paths
  # were unreachable because `$justification` was never empty. Treat the literal
  # sentinel "not provided" as "no real reason given" so the precedence (env var
  # → self-test auto-tag → "not provided") still applies. A caller that passes a
  # genuine reason string is unaffected; only the sentinel falls through.
  if [ -z "$justification" ] || [ "$justification" = "not provided" ]; then
    if [ -n "${PSK_BYPASS_REASON:-}" ]; then
      justification="$PSK_BYPASS_REASON"
    elif [ "${PSK_BYPASS_SELFTEST:-0}" = "1" ]; then
      justification="self-test:${env_var}"
    else
      justification="not provided"
    fi
  fi

  mkdir -p "$(dirname "$LOG_FILE")"

  local ts user pid
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  user=$(git config user.name 2>/dev/null || whoami 2>/dev/null || echo "unknown")
  pid="${PPID:-$$}"

  # Escape fields for JSON safety
  local env_var_j command_j justification_j user_j
  env_var_j=$(printf '%s' "$env_var" | json_escape)
  command_j=$(printf '%s' "$command" | json_escape)
  justification_j=$(printf '%s' "$justification" | json_escape)
  user_j=$(printf '%s' "$user" | json_escape)

  printf '{"timestamp":"%s","env_var":"%s","command":"%s","justification":"%s","caller_pid":%s,"user":"%s"}\n' \
    "$ts" "$env_var_j" "$command_j" "$justification_j" "$pid" "$user_j" >> "$LOG_FILE"

  rotate_if_needed
  return 0
}

cmd_list() {
  local since_days="$DEFAULT_SINCE_DAYS"
  while [ $# -gt 0 ]; do
    case "$1" in
      --since-days) shift; since_days="${1:-$DEFAULT_SINCE_DAYS}" ;;
      *) echo "list: unknown arg: $1" >&2; exit 1 ;;
    esac
    shift || true
  done

  [ -f "$LOG_FILE" ] || { echo "(no bypass log — agent/.bypass-log absent)"; return 0; }

  local cutoff_epoch now_epoch
  now_epoch=$(date -u +%s)
  cutoff_epoch=$(( now_epoch - since_days * 86400 ))

  echo "Bypass log — last ${since_days} day(s):"
  echo "  (newest first)"
  echo ""

  # JSONL filter — sort newest-first, filter by timestamp, pretty-print
  python3 - "$LOG_FILE" "$cutoff_epoch" <<'PYEOF'
import sys, json, re, calendar
path, cutoff = sys.argv[1], int(sys.argv[2])
entries = []
try:
    with open(path) as f:
        for idx, line in enumerate(f):
            line = line.strip()
            if not line or not line.startswith('{'):
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            ts = rec.get('timestamp', '')
            m = re.match(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$', ts)
            if not m:
                continue
            p = [int(x) for x in m.groups()]
            ep = calendar.timegm((p[0],p[1],p[2],p[3],p[4],p[5],0,0,0))
            if ep >= cutoff:
                # Track file-order index as secondary sort key — when two
                # entries share a timestamp (same-second writes), the later
                # line in the file is newer (append-only log).
                entries.append((ep, idx, rec))
except Exception as e:
    print(f"(error reading log: {e})")
    sys.exit(0)

# Sort newest-first: primary by epoch, secondary by file-order index
# (both descending, so latest-appended line wins ties).
entries.sort(key=lambda x: (x[0], x[1]), reverse=True)
if not entries:
    print("  (no bypasses in window)")
else:
    for ep, _idx, rec in entries:
        ts = rec.get('timestamp', '?')
        ev = rec.get('env_var', '?')
        cmd = rec.get('command', '?')
        just = rec.get('justification', '?')
        usr = rec.get('user', '?')
        print(f"  {ts}  {ev}")
        print(f"    user:          {usr}")
        print(f"    command:       {cmd}")
        print(f"    justification: {just}")
        print("")
print(f"({len(entries)} bypass(es) in window)")
PYEOF
}

cmd_count() {
  local since_days="1"  # default = last 24h for PSK027 use
  local exclude_selftest="0"
  while [ $# -gt 0 ]; do
    case "$1" in
      --since-days) shift; since_days="${1:-1}" ;;
      # QA-D7-PSK027-RATIONALE-GAP fix (v0.6.83): exclude self-test-tagged
      # bypasses (justification starting `self-test:`) so PSK027 counts only
      # real, operator-driven undocumented bypasses — not test infrastructure.
      --exclude-selftest) exclude_selftest="1" ;;
      *) echo "count: unknown arg: $1" >&2; exit 1 ;;
    esac
    shift || true
  done

  if [ ! -f "$LOG_FILE" ]; then
    echo "0"
    return 0
  fi

  local now_epoch cutoff_epoch
  now_epoch=$(date -u +%s)
  cutoff_epoch=$(( now_epoch - since_days * 86400 ))

  python3 - "$LOG_FILE" "$cutoff_epoch" "$exclude_selftest" <<'PYEOF'
import sys, json, re, calendar
path, cutoff, exclude_selftest = sys.argv[1], int(sys.argv[2]), sys.argv[3] == "1"
n = 0
try:
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or not line.startswith('{'):
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            ts = rec.get('timestamp', '')
            m = re.match(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$', ts)
            if not m:
                continue
            if exclude_selftest and str(rec.get('justification', '')).startswith('self-test:'):
                continue
            p = [int(x) for x in m.groups()]
            ep = calendar.timegm((p[0],p[1],p[2],p[3],p[4],p[5],0,0,0))
            if ep >= cutoff:
                n += 1
except Exception:
    pass
print(n)
PYEOF
}

cmd_clear() {
  local confirm=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --confirm) confirm=1 ;;
      *) echo "clear: unknown arg: $1" >&2; exit 1 ;;
    esac
    shift || true
  done

  if [ "$confirm" -ne 1 ]; then
    echo "clear: confirmation required" >&2
    echo "  This will permanently delete agent/.bypass-log." >&2
    echo "  Pass --confirm to proceed." >&2
    return 1
  fi

  if [ -f "$LOG_FILE" ]; then
    rm -f "$LOG_FILE"
    echo "Cleared $LOG_FILE."
  else
    echo "(no log to clear)"
  fi
  return 0
}

cmd_unique_env_vars() {
  # Helper for PSK027: list unique env_vars with counts in window
  local since_days="${1:-1}"
  [ -f "$LOG_FILE" ] || { echo ""; return 0; }
  local now_epoch cutoff_epoch
  now_epoch=$(date -u +%s)
  cutoff_epoch=$(( now_epoch - since_days * 86400 ))
  python3 - "$LOG_FILE" "$cutoff_epoch" <<'PYEOF'
import sys, json, re, calendar
from collections import Counter
path, cutoff = sys.argv[1], int(sys.argv[2])
c = Counter()
try:
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or not line.startswith('{'):
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            ts = rec.get('timestamp', '')
            m = re.match(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$', ts)
            if not m:
                continue
            p = [int(x) for x in m.groups()]
            ep = calendar.timegm((p[0],p[1],p[2],p[3],p[4],p[5],0,0,0))
            if ep >= cutoff:
                c[rec.get('env_var', '?')] += 1
except Exception:
    pass
for env_var, n in c.most_common():
    print(f"{env_var} {n}")
PYEOF
}

case "${1:-}" in
  log)              shift; cmd_log "$@" ;;
  list)             shift; cmd_list "$@" ;;
  count)            shift; cmd_count "$@" ;;
  clear)            shift; cmd_clear "$@" ;;
  unique-env-vars)  shift; cmd_unique_env_vars "$@" ;;
  -h|--help|"")     usage ;;
  *) echo "unknown subcommand: $1" >&2; usage; exit 2 ;;
esac
