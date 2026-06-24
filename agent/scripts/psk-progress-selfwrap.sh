#!/usr/bin/env bash
# mechanical-script: psk-progress-selfwrap.sh — generic self-wrap for long-op scripts
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS EXISTS (no-silent-wait, generic):
#   psk-progress.sh is the kit's generic progress monitor, but each long-op script
#   used to carry its own bespoke 4-line "re-exec through psk-progress.sh" block
#   (copy-paste, drift-prone). This is the ONE shared self-wrap every long-op script
#   sources, so the monitor is wired consistently ALL OVER the kit, not re-implemented.
#
# WHAT IT DOES:
#   When sourced, it re-execs the CALLING script through psk-progress.sh (which emits
#   heartbeats to stderr + a live-progress file readable via `psk-progress.sh --status`).
#   On the re-exec'd run PSK_PROGRESS_ACTIVE=1 is set, so sourcing it again falls through
#   (no infinite re-exec, no double-wrap when a reflex gate already wraps the caller).
#
# USAGE — source near the TOP of a long-op script, after it resolves its own dir:
#   PSK_SELFWRAP_LABEL="my-op" PSK_SELFWRAP_METRIC='✓|✗' \
#     source "<dir>/psk-progress-selfwrap.sh" "$@"
#   • PSK_SELFWRAP_LABEL  (optional) heartbeat label — defaults to the caller's basename
#   • PSK_SELFWRAP_METRIC (optional) grep -E pattern counted in the heartbeat
#   • pass "$@" to source so the caller's args are forwarded to the re-exec
#
# GUARDS (fail-safe — never blocks the caller):
#   • PSK_PROGRESS_ACTIVE set   → already under a monitor; fall through (no re-exec)
#   • PSK_PROGRESS_DISABLED=1   → opt out entirely; fall through
#   • psk-progress.sh missing / not executable → fall through (caller runs unwrapped)
#   • sourced without a resolvable caller path → fall through
# ─────────────────────────────────────────────────────────────────────────────

# Resolve this helper's dir → sibling psk-progress.sh (both live in agent/scripts/).
_psw_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_psw_prog="$_psw_dir/psk-progress.sh"

if [ -z "${PSK_PROGRESS_ACTIVE:-}" ] && [ "${PSK_PROGRESS_DISABLED:-0}" != "1" ] && [ -x "$_psw_prog" ]; then
  # The caller is the script that sourced us — BASH_SOURCE[1].
  _psw_caller="${BASH_SOURCE[1]:-}"
  if [ -n "$_psw_caller" ] && [ -f "$_psw_caller" ]; then
    export PSK_PROGRESS_ACTIVE=1
    _psw_label="${PSK_SELFWRAP_LABEL:-$(basename "$_psw_caller" .sh)}"
    # PSK_SELFWRAP_TAIL (default 0) → echo the last N captured lines on completion, so
    # an interactive run still sees the caller's final output (e.g. a suite RESULTS
    # block) even though stdout was captured for metric counting.
    _psw_tail="${PSK_SELFWRAP_TAIL:-0}"
    # KIT-GAP-0122: PSK_SELFWRAP_STAGE (optional) ERE for the op's section headers —
    # surfaces "sec NN" in the heartbeat so a long sectioned op shows which stage runs.
    _psw_stage_args=""
    [ -n "${PSK_SELFWRAP_STAGE:-}" ] && _psw_stage_args="--stage $PSK_SELFWRAP_STAGE"
    if [ -n "${PSK_SELFWRAP_METRIC:-}" ]; then
      exec bash "$_psw_prog" --label "$_psw_label" --metric "$PSK_SELFWRAP_METRIC" $_psw_stage_args --tail "$_psw_tail" -- bash "$_psw_caller" "$@"
    else
      exec bash "$_psw_prog" --label "$_psw_label" $_psw_stage_args --tail "$_psw_tail" -- bash "$_psw_caller" "$@"
    fi
  fi
fi
# Fall-through: already wrapped / disabled / unavailable — caller continues normally.
