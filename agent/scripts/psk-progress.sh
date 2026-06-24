#!/usr/bin/env bash
# mechanical-script: psk-progress.sh — progress heartbeat wrapper for long blocking ops
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS EXISTS (no-silent-wait):
#   Long kit operations (full test suite, sync-check --full, doc-sync, the reflex
#   gates) run with output redirected to a log and the caller BLOCKS with zero
#   feedback until done — a multi-minute "silent wait" where running-slow looks
#   identical to hung. This wrapper runs the command, captures its output to a log,
#   and emits a heartbeat to STDERR every N seconds (elapsed · metric-count · %),
#   then a final exit line — so a long op is never silent.
#
# CONTRACT (fail-safe — never changes the wrapped command's behavior):
#   - The wrapped command's exit code is returned VERBATIM.
#   - The command's stdout+stderr go to --log (or a temp file); the wrapper's own
#     stdout stays clean. Heartbeats + the final summary go to STDERR only, so they
#     never pollute a log a downstream parser reads.
#   - PSK_PROGRESS_DISABLED=1 → run the command directly (no heartbeat), still
#     returning its exit code. PSK_PROGRESS_INTERVAL overrides the default interval.
#
# Usage:
#   psk-progress.sh [--label L] [--log F] [--metric ERE] [--total N]
#                   [--interval S] [--tail K] -- CMD...
#   --label   name shown in the heartbeat (default: "task")
#   --log     file for the command's stdout+stderr (default: a temp file)
#   --metric  grep -E pattern; heartbeat counts matching lines in the log so far
#   --total   denominator → renders count/total (pct%)
#   --interval heartbeat seconds (default 30; or PSK_PROGRESS_INTERVAL)
#   --tail K  on completion, echo the last K log lines to stderr (default 0)
#
# Example:
#   psk-progress.sh --label "test-spec-kit" --metric '✓|✗' --total 2916 -- \
#     bash tests/test-spec-kit.sh
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

# Live-progress dir — every heartbeat is mirrored here (decoupled from stderr) so
# progress survives ANY stdout/stderr redirection (KIT-GAP-0105: an agent backgrounding
# a long op + redirecting its streams used to hide all progress). Read with `--status`.
# TMPDIR-INDEPENDENT (KIT-GAP-0110): the dir must NOT depend on $TMPDIR — the op-writer
# (agent's shell, $TMPDIR=/var/folders/.../T on macOS) and the statusLine reader (Claude
# Code's subprocess, often $TMPDIR=/tmp or unset) had DIFFERENT $TMPDIR, so the statusLine
# read an empty dir and `run:` never showed. Anchor on the fixed `/tmp` path (identical in
# every context) + uid (per-user isolation, no multi-user collision) so writer and reader
# always resolve the SAME dir regardless of their environment.
PROGRESS_DIR="${PSK_PROGRESS_DIR:-/tmp/psk-progress-$(id -u 2>/dev/null || echo u)}"

# `--status [label]` — print the latest heartbeat from the live file(s) and exit. The
# always-readable progress signal, independent of how the wrapped op's streams (or this
# wrapper's stderr) were redirected. No label → the most-recently-updated op.
if [ "${1:-}" = "--status" ]; then
  _ps_want="${2:-}"
  if [ -n "$_ps_want" ]; then
    _ps_safe=$(printf '%s' "$_ps_want" | tr -c 'A-Za-z0-9._-' '_')
    if [ -f "$PROGRESS_DIR/$_ps_safe.live" ]; then cat "$PROGRESS_DIR/$_ps_safe.live"
    else echo "[progress] no live progress for '$_ps_want'"; fi
    exit 0
  fi
  _ps_latest=$(ls -t "$PROGRESS_DIR"/*.live 2>/dev/null | head -1)
  if [ -n "$_ps_latest" ]; then cat "$_ps_latest"
  else echo "[progress] no active long-op (no live files in $PROGRESS_DIR)"; fi
  exit 0
fi

# `--statusline` — COMPACT readout of the most-recent ACTIVELY-running op, for the Claude
# Code status bar (the always-on, agent-independent surface — same guarantee as the session
# monitor's ctx/opt badges). Prints `run: <label> · <elapsed> · <count>` or NOTHING. Without
# this, a long op backgrounded by the agent (stderr captured to a task file, live-file in
# /tmp) is invisible to the user — the exact no-silent-wait gap the live-file was meant to
# close but couldn't, having no surface the user actually watches. "Active" = a .live file
# touched within PSK_PROGRESS_STATUSLINE_WINDOW seconds whose last line is a heartbeat (not a
# completion line). Fail-safe: any error / no active op → print nothing, exit 0 (never breaks
# the bar).
if [ "${1:-}" = "--statusline" ]; then
  _sl_window="${PSK_PROGRESS_STATUSLINE_WINDOW:-25}"
  [ -d "$PROGRESS_DIR" ] || exit 0
  _sl_f=$(ls -t "$PROGRESS_DIR"/*.live 2>/dev/null | head -1)
  [ -n "$_sl_f" ] && [ -f "$_sl_f" ] || exit 0
  _sl_now=$(date +%s 2>/dev/null || echo 0)
  _sl_mt=$(stat -f %m "$_sl_f" 2>/dev/null || stat -c %Y "$_sl_f" 2>/dev/null || echo 0)
  [ "$_sl_now" -gt 0 ] && [ "$_sl_mt" -gt 0 ] && [ $((_sl_now - _sl_mt)) -le "$_sl_window" ] || exit 0
  _sl_line=$(tail -1 "$_sl_f" 2>/dev/null)
  case "$_sl_line" in
    *"done in"*|*"FAILED in"*) exit 0 ;;   # completed op — not "running"
  esac
  case "$_sl_line" in
    "[progress] "*) printf 'run: %s\n' "${_sl_line#\[progress\] }" ;;
  esac
  exit 0
fi

# `--mark <label> <text>` — write ONE heartbeat line to <label>'s live file WITHOUT wrapping
# a command (KIT-GAP-0134). For long ops whose stages run as separate IN-PROCESS steps that
# CANNOT be wrapped as a single command because they export shell state the caller needs —
# e.g. reflex run.sh's pre-QA pipeline (preconditions → preflight → sandbox) sets PASS_DIR /
# REFLEX_PASS_DIR exports consumed by the later spawn-qa call, so a `psk-progress -- <cmd>`
# subshell would lose them. Each step calls `--mark` to advance the live-file stage; then
# `--status`, `--statusline`, and `tail -f` surface the current stage on the always-on
# surfaces. Fail-safe: any error exits 0 (never blocks the caller's pipeline).
if [ "${1:-}" = "--mark" ]; then
  _mk_label="${2:-task}"; _mk_text="${3:-}"
  _mk_safe=$(printf '%s' "$_mk_label" | tr -c 'A-Za-z0-9._-' '_'); [ -z "$_mk_safe" ] && _mk_safe="task"
  mkdir -p "$PROGRESS_DIR" 2>/dev/null || true
  # Same `[progress] <label> · <text>` shape the heartbeat writes, so --statusline renders it
  # as `run: <label> · <text>` and the box-table live-row picks it up uniformly. The text is
  # the human stage label (not "Ns · count") — a stage mark, not a timed heartbeat.
  printf '[progress] %s · %s\n' "$_mk_label" "$_mk_text" > "$PROGRESS_DIR/$_mk_safe.live" 2>/dev/null || true
  exit 0
fi

LABEL="task"
LOG=""
METRIC=""
TOTAL=""
INTERVAL="${PSK_PROGRESS_INTERVAL:-30}"
TAIL=0
STAGE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --label)    LABEL="${2:-task}"; shift 2 ;;
    --log)      LOG="${2:-}"; shift 2 ;;
    --metric)   METRIC="${2:-}"; shift 2 ;;
    --total)    TOTAL="${2:-}"; shift 2 ;;
    --interval) INTERVAL="${2:-30}"; shift 2 ;;
    --tail)     TAIL="${2:-0}"; shift 2 ;;
    --stage)    STAGE="${2:-}"; shift 2 ;;   # KIT-GAP-0122: ERE for the op's stage/section headers; the latest match's number is surfaced in the heartbeat (e.g. "sec 04") so a long op shows WHICH stage is running, not just a count
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    --) shift; break ;;
    *) echo "psk-progress.sh: unknown arg '$1' (did you forget '--' before the command?)" >&2; exit 2 ;;
  esac
done

[ $# -eq 0 ] && { echo "psk-progress.sh: no command after '--'" >&2; exit 2; }

# anti-double-wrap signal: mark this process tree as already under a progress
# monitor. A self-wrapping child (e.g. tests/test-spec-kit.sh, which wraps
# itself in psk-progress.sh when run directly) reads PSK_PROGRESS_ACTIVE and
# skips its own wrap, so a gate that already routes through this wrapper does
# not double-wrap. Exported before any run path (bypass + heartbeat) so the
# wrapped command and all its descendants inherit it.
export PSK_PROGRESS_ACTIVE=1

# Default log = temp file we own.
if [ -z "$LOG" ]; then
  LOG="$(mktemp 2>/dev/null || echo "/tmp/psk-progress.$$.log")"
fi

# Live-progress file — the latest heartbeat is written here (overwritten each beat) so
# `psk-progress.sh --status` reads current progress regardless of stream redirection.
LABEL_SAFE=$(printf '%s' "$LABEL" | tr -c 'A-Za-z0-9._-' '_'); [ -z "$LABEL_SAFE" ] && LABEL_SAFE="task"
LIVE_FILE="$PROGRESS_DIR/$LABEL_SAFE.live"
mkdir -p "$PROGRESS_DIR" 2>/dev/null || true

# Bypass — run the command directly, no heartbeat, exit code verbatim.
if [ "${PSK_PROGRESS_DISABLED:-0}" = "1" ]; then
  "$@" >"$LOG" 2>&1; rc=$?
  [ "$TAIL" -gt 0 ] 2>/dev/null && tail -n "$TAIL" "$LOG" >&2
  exit "$rc"
fi

_emit_heartbeat() {
  _el=$(( SECONDS - T0 ))
  _n=""
  if [ -n "$METRIC" ]; then
    _c=$(grep -cE "$METRIC" "$LOG" 2>/dev/null | head -1)
    _c="${_c:-0}"
    if [ -n "$TOTAL" ] && [ "$TOTAL" -gt 0 ] 2>/dev/null; then
      _pct=$(( _c * 100 / TOTAL ))
      _n=" · ${_c}/${TOTAL} (${_pct}%)"
    else
      _n=" · ${_c}"
    fi
  fi
  # KIT-GAP-0122: surface the current STAGE for a long sectioned op. Grep the log
  # for the latest line matching the stage ERE (e.g. a "═══ NN. Title ═══" section
  # header), pull its leading number, and show "sec NN". ASCII-only ("sec " + digits)
  # so the byte-counting box-table renderer stays aligned.
  _stg=""
  if [ -n "$STAGE" ]; then
    _sn=$(grep -E "$STAGE" "$LOG" 2>/dev/null | tail -1 | grep -oE '[0-9]+[a-z]?' | head -1)
    [ -n "$_sn" ] && _stg=" · sec ${_sn}"
  fi
  printf '[progress] %s · %ds%s%s\n' "$LABEL" "$_el" "$_stg" "$_n" >&2
  # Mirror to the live file (decoupled from stderr — survives redirection). KIT-GAP-0105.
  printf '[progress] %s · %ds%s%s\n' "$LABEL" "$_el" "$_stg" "$_n" > "$LIVE_FILE" 2>/dev/null || true
}

T0=$SECONDS
( "$@" >"$LOG" 2>&1 ) &
CMD_PID=$!

# Initial live-file write (KIT-GAP-0111) — make the op visible in EVERY read path
# (--status, --statusline, the agent's chat relay) the INSTANT it starts, not only after
# the first $INTERVAL (default 30s). Without this there is a 30s blind window where a
# just-launched long op shows nothing anywhere — the "monitor isn't coming" symptom on a
# UI that surfaces progress by reading the live file rather than streaming stderr. Live-file
# ONLY (no stderr) so a quick op that finishes before the first heartbeat adds no stderr
# noise; the final "done"/"FAILED" line overwrites it on completion.
printf '[progress] %s · 0s\n' "$LABEL" > "$LIVE_FILE" 2>/dev/null || true

# Poll: sleep, then heartbeat if still running. First STDERR heartbeat lands after one
# interval (fast commands finish before any heartbeat — no stderr spam); the live file is
# already populated from the initial write above.
while kill -0 "$CMD_PID" 2>/dev/null; do
  sleep "$INTERVAL"
  kill -0 "$CMD_PID" 2>/dev/null || break
  _emit_heartbeat
done

wait "$CMD_PID"; rc=$?
EL=$(( SECONDS - T0 ))

_final=""
if [ -n "$METRIC" ]; then
  _fc=$(grep -cE "$METRIC" "$LOG" 2>/dev/null | head -1); _fc="${_fc:-0}"
  _final=" · ${_fc} matched"
fi
if [ "$rc" -eq 0 ]; then
  _fline=$(printf '[progress] %s · done in %ds%s · exit 0' "$LABEL" "$EL" "$_final")
else
  _fline=$(printf '[progress] %s · FAILED in %ds%s · exit %d (log: %s)' "$LABEL" "$EL" "$_final" "$rc" "$LOG")
fi
printf '%s\n' "$_fline" >&2
# Final state to the live file too, so `--status` after completion shows done/FAILED.
printf '%s\n' "$_fline" > "$LIVE_FILE" 2>/dev/null || true

[ "$TAIL" -gt 0 ] 2>/dev/null && tail -n "$TAIL" "$LOG" >&2
exit "$rc"
