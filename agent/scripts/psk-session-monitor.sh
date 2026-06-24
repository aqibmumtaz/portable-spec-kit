#!/bin/bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist)
# =============================================================
# psk-session-monitor.sh — Claude Code UserPromptSubmit-hook: session context-health monitor
#
# Two surfaces, one measurement:
#   1. BADGE (passive, continuous) — a 3-level health indicator (🟢/🟡/🔴 + %) the
#      agent renders in the breadcrumb header next to the `opt:` badge, so you can
#      keep an eye on session health every reply. Delivered each turn via the hook's
#      additionalContext (SESSION_HEALTH line). Also available via `--badge`.
#   2. BANNER (active, de-duped) — a one-time `/clear` recommendation that fires ONLY
#      when context enters the RED zone (and once more, deeper). Never nags.
#
# THE 3 LEVELS (when each appears — grounded in lost-in-the-middle research):
#   🟢 green   <50%       middle small, attention strong, rules hold   → badge only
#   🟡 yellow  50–79%     middle large, instruction-following dilutes  → badge only (no banner)
#   🔴 red     ≥80%       heavy dilution, lossy auto-compact imminent  → badge + one banner
#   The yellow band is BADGE-ONLY on purpose: passive awareness without interruption.
#   The banner is reserved for red, de-duped (once per band), re-arms after a /clear.
#
# ACCURATE TRACE (verified against the real Claude Code transcript schema):
#   Each assistant line carries `.message.usage` with input_tokens +
#   cache_creation_input_tokens + cache_read_input_tokens. The MOST RECENT assistant
#   turn's sum IS the live context-window occupancy (caches already reflect cumulative
#   context — no cross-turn summing). jq-free: grep extracts the usage object + fields.
#
# FAIL-SAFE: any error / missing data → exit 0 silently. Never blocks, never disrupts.
#
# Modes:
#   psk-session-monitor.sh                 # HOOK mode (reads hook JSON on stdin):
#                                          #   emits additionalContext badge every turn
#                                          #   + de-duped systemMessage banner in RED.
#   psk-session-monitor.sh --badge [file]  # print just the badge string: "🟡 62%"
#   psk-session-monitor.sh --statusline    # STATUSLINE mode (reads session JSON on stdin):
#                                          #   prints "ctx: 🟢 27%  ·  opt: 🟢 optimized" to
#                                          #   stdout for the Claude Code status bar — STRUCTURAL,
#                                          #   rendered by Claude Code every turn, agent-independent.
#   psk-session-monitor.sh --check [file]  # human-readable tokens/limit/pct/color/action
#   psk-session-monitor.sh --self-test     # prove band + de-dup + re-arm logic
#
# Config (optional env overrides):
#   PSK_SESSION_CONTEXT_LIMIT  window size in tokens (default auto-tier: >220k ⇒ 1,000,000 else 200,000)
#   PSK_SESSION_YELLOW_PCT     green→yellow threshold (default 50)
#   PSK_SESSION_WARN_PCT       yellow→red threshold + first banner (default 80)
#   PSK_SESSION_URGE_PCT       deep-red second banner (default 92)
#   PSK_SESSION_MONITOR_DISABLED=1   silent no-op
# =============================================================

set -uo pipefail

[ "${PSK_SESSION_MONITOR_DISABLED:-0}" = "1" ] && exit 0

YELLOW_PCT="${PSK_SESSION_YELLOW_PCT:-50}"
WARN_PCT="${PSK_SESSION_WARN_PCT:-80}"
URGE_PCT="${PSK_SESSION_URGE_PCT:-92}"
STATE_DIR="${PSK_SESSION_STATE_DIR:-$HOME/.claude}"
STATE_FILE="$STATE_DIR/.psk-session-monitor.state"

# --- token extraction (jq-free, schema-verified), tail-bounded for speed ------
context_tokens_of() {
  local transcript="$1"
  [ -f "$transcript" ] || return 0
  local blob usage inp cc cr
  blob="$(tail -c 4000000 "$transcript" 2>/dev/null)" || return 0
  usage="$(printf '%s' "$blob" | grep -o '"usage":{[^}]*}' | tail -1)"
  [ -n "$usage" ] || return 0
  inp="$(printf '%s' "$usage" | grep -o '"input_tokens":[0-9]*'                | grep -o '[0-9]*' | head -1)"
  cc="$(printf '%s'  "$usage" | grep -o '"cache_creation_input_tokens":[0-9]*' | grep -o '[0-9]*' | head -1)"
  cr="$(printf '%s'  "$usage" | grep -o '"cache_read_input_tokens":[0-9]*'     | grep -o '[0-9]*' | head -1)"
  inp="${inp:-0}"; cc="${cc:-0}"; cr="${cr:-0}"
  echo $(( inp + cc + cr ))
}

resolve_limit() {
  # Resolve the context-window limit WITHOUT guessing. Claude Code exposes no explicit
  # limit field, but a `compact_boundary` line carries `compactMetadata.preTokens` — the
  # context size just before a compaction. A 200k window cannot reach e.g. 767k pre-compact,
  # so preTokens is AUTHORITATIVE proof of the true window. Window-evidence = max(current
  # total, any preTokens seen); map it onto the standard tier ladder. This fixes two bugs in
  # the old `total > 220000` guess: (1) the 220k inversion (🔴109% → 🟢23% on crossing), and
  # (2) a 1M session that compacted back below 220k being mis-tiered as 200k (≈75% vs true ≈15%).
  local total="$1" transcript="${2:-}"
  if [ -n "${PSK_SESSION_CONTEXT_LIMIT:-}" ]; then echo "$PSK_SESSION_CONTEXT_LIMIT"; return; fi
  local evidence="${total:-0}"
  # Consult preTokens only when the current total alone is ambiguous (≤200k). If total already
  # exceeds 200k we are certainly on a >200k window, so no transcript scan is needed (fast path).
  if [ "$evidence" -le 200000 ] && [ -n "$transcript" ] && [ -f "$transcript" ]; then
    local pre
    pre="$(grep -oE '"preTokens":[0-9]+' "$transcript" 2>/dev/null | grep -oE '[0-9]+' | sort -rn | head -1)"
    [ -n "$pre" ] && [ "$pre" -gt "$evidence" ] 2>/dev/null && evidence="$pre"
  fi
  # Map window-evidence onto the standard ladder: 200k, then 1M, then round up to the next M.
  if   [ "$evidence" -le 200000 ];  then echo 200000
  elif [ "$evidence" -le 1000000 ]; then echo 1000000
  else echo $(( ((evidence / 1000000) + 1) * 1000000 )); fi
}

# health color (badge): green <YELLOW · yellow <WARN · red ≥WARN
health_color() {
  local pct="$1"
  if [ "$pct" -ge "$WARN_PCT" ]; then echo red
  elif [ "$pct" -ge "$YELLOW_PCT" ]; then echo yellow
  else echo green; fi
}
emoji_of() { case "$1" in red) echo "🔴" ;; yellow) echo "🟡" ;; *) echo "🟢" ;; esac; }

# banner band (de-dup): 0 none · 1 warn(red) · 2 urge(deep red)
band_of() {
  local pct="$1"
  if [ "$pct" -ge "$URGE_PCT" ]; then echo 2
  elif [ "$pct" -ge "$WARN_PCT" ]; then echo 1
  else echo 0; fi
}

json_escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

# --- HOOK mode ----------------------------------------------------------------
run_hook() {
  local stdin transcript sid total limit pct color emo band prev_sid prev_band
  stdin="$(cat 2>/dev/null || true)"
  transcript="$(printf '%s' "$stdin" | grep -o '"transcript_path":"[^"]*"' | head -1 | sed 's/.*"transcript_path":"//; s/"$//')"
  sid="$(printf '%s' "$stdin" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/.*"session_id":"//; s/"$//')"
  [ -f "$transcript" ] || exit 0
  total="$(context_tokens_of "$transcript")"
  [ -n "$total" ] && [ "$total" -gt 0 ] 2>/dev/null || exit 0
  limit="$(resolve_limit "$total" "$transcript")"
  pct=$(( total * 100 / limit ))
  color="$(health_color "$pct")"; emo="$(emoji_of "$color")"
  band="$(band_of "$pct")"

  # de-dup state for the BANNER only: "<sid> <warned_band> <total>"
  prev_sid=""; prev_band=0
  if [ -f "$STATE_FILE" ]; then read -r prev_sid prev_band _ < "$STATE_FILE" 2>/dev/null || true; prev_band="${prev_band:-0}"; fi
  if [ "$sid" != "$prev_sid" ]; then prev_band=0
  elif [ "$total" -lt $(( limit * (WARN_PCT - 15) / 100 )) ]; then prev_band=0   # re-arm after /clear or compaction
  fi
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  printf '%s %s %s\n' "$sid" "$band" "$total" > "$STATE_FILE" 2>/dev/null || true

  # ALWAYS inject the badge (passive, continuous) via additionalContext.
  local ctx_line; ctx_line="SESSION_HEALTH: ctx ${emo} ${pct}%  (render in breadcrumb as: ctx: ${emo} ${pct}%)"
  # BANNER (active) only when entering a higher red band than already warned.
  local sysmsg=""
  if [ "$band" -gt "$prev_band" ]; then
    local k=$(( total / 1000 )) lk=$(( limit / 1000 ))
    if [ "$band" = "2" ]; then
      sysmsg="⚠ Context ~${pct}% (${k}k/${lk}k) — high lost-in-the-middle risk + auto-compact imminent. Run /clear now and start fresh; the kit re-briefs from agent/ files (TASKS / AGENT_CONTEXT / .session-stack)."
    else
      sysmsg="Context ~${pct}% (${k}k/${lk}k) entered the red zone — good point to finish the current task and run /clear before the next. (One-time notice; you won't be nagged.)"
    fi
  fi

  # Emit as a UserPromptSubmit hook — NOT Stop. A Stop hook that returns
  # additionalContext re-invokes the agent every turn (infinite loop). The
  # UserPromptSubmit event injects the badge once per real user turn, no loop.
  if [ -n "$sysmsg" ]; then
    printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' \
      "$(json_escape "$sysmsg")" "$(json_escape "$ctx_line")"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$(json_escape "$ctx_line")"
  fi
  exit 0
}

# --- newest transcript for cwd (shared by --badge / --check) ------------------
newest_transcript() {
  local pdir; pdir="$HOME/.claude/projects/$(pwd | sed 's/[^A-Za-z0-9]/-/g')"
  ls -t "$pdir"/*.jsonl 2>/dev/null | head -1
}

# --- BADGE mode: print just "🟡 62%" (for the agent / statusline) -------------
run_badge() {
  local transcript="${1:-$(newest_transcript)}" total limit pct
  [ -f "$transcript" ] || { exit 0; }
  total="$(context_tokens_of "$transcript")"; [ -n "$total" ] && [ "$total" -gt 0 ] 2>/dev/null || exit 0
  limit="$(resolve_limit "$total" "$transcript")"; pct=$(( total * 100 / limit ))
  printf '%s %s%%\n' "$(emoji_of "$(health_color "$pct")")" "$pct"
}

# --- CHECK mode (verification) ------------------------------------------------
run_check() {
  local transcript="${1:-$(newest_transcript)}" total limit pct color band
  [ -f "$transcript" ] || { echo "check: no transcript found ($transcript)"; return 0; }
  total="$(context_tokens_of "$transcript")"; total="${total:-0}"
  limit="$(resolve_limit "$total" "$transcript")"
  [ "$total" -gt 0 ] || { echo "check: no usage data in transcript"; return 0; }
  pct=$(( total * 100 / limit )); color="$(health_color "$pct")"; band="$(band_of "$pct")"
  echo "transcript : $transcript"
  echo "context    : $total tokens"
  echo "limit      : $limit tokens ($([ -n "${PSK_SESSION_CONTEXT_LIMIT:-}" ] && echo configured || echo auto-tier))"
  echo "usage      : ${pct}%   (green<${YELLOW_PCT}% · yellow<${WARN_PCT}% · red≥${WARN_PCT}%)"
  echo "badge      : $(emoji_of "$color") ${pct}%  ($color)"
  case "$band" in
    2) echo "banner     : URGE — /clear now (deep red)";;
    1) echo "banner     : WARN — /clear soon (entered red)";;
    0) echo "banner     : (none — badge-only below red)";;
  esac
}

# --- SELF-TEST: prove bands + banner de-dup + re-arm --------------------------
run_self_test() {
  local fail=0 t; t="$(mktemp -d)"
  _mk(){ printf '{"type":"assistant","message":{"role":"assistant","content":[],"usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":10}}}\n' "$1" > "$t/tx.jsonl"; }
  export PSK_SESSION_CONTEXT_LIMIT=200000 PSK_SESSION_YELLOW_PCT=50 PSK_SESSION_WARN_PCT=80 PSK_SESSION_URGE_PCT=92
  STATE_DIR="$t"; STATE_FILE="$t/.psk-session-monitor.state"
  _hook(){ printf '{"session_id":"%s","transcript_path":"%s"}' "$1" "$t/tx.jsonl" | run_hook; }
  _badge(){ run_badge "$t/tx.jsonl"; }

  # badge colors at the 3 levels
  _mk 80000;  [ "$(_badge)" = "🟢 40%" ] && echo "  ✓ 40% → 🟢 green badge" || { echo "  ✗ 40% badge: $(_badge)"; fail=1; }
  _mk 130000; [ "$(_badge)" = "🟡 65%" ] && echo "  ✓ 65% → 🟡 yellow badge" || { echo "  ✗ 65% badge: $(_badge)"; fail=1; }
  _mk 170000; [ "$(_badge)" = "🔴 85%" ] && echo "  ✓ 85% → 🔴 red badge" || { echo "  ✗ 85% badge: $(_badge)"; fail=1; }

  # statusline mode: structural badge line to stdout (substring — an opt: suffix may append)
  _mk 80000; _sl="$(printf '{"transcript_path":"%s"}' "$t/tx.jsonl" | run_statusline)"
  echo "$_sl" | grep -q 'ctx: 🟢 40%' && echo "  ✓ statusline → '$_sl'" || { echo "  ✗ statusline should print ctx badge: $_sl"; fail=1; }

  # banner: yellow is BADGE-ONLY (no systemMessage), red fires once, no nag, re-arms
  _mk 130000; out="$(_hook S1)"; { echo "$out" | grep -q 'additionalContext' && ! echo "$out" | grep -q 'systemMessage'; } \
    && echo "  ✓ yellow 65% → badge only, NO banner (no nag)" || { echo "  ✗ yellow should be badge-only: $out"; fail=1; }
  # hook event MUST be UserPromptSubmit, never Stop (a Stop hook + additionalContext re-invokes the agent → loop)
  { echo "$out" | grep -q '"hookEventName":"UserPromptSubmit"' && ! echo "$out" | grep -q '"hookEventName":"Stop"'; } \
    && echo "  ✓ emits UserPromptSubmit hook event (not Stop — no agent loop)" || { echo "  ✗ wrong hook event (must be UserPromptSubmit): $out"; fail=1; }
  _mk 170000; out="$(_hook S1)"; echo "$out" | grep -q 'systemMessage' && echo "  ✓ enter red 85% → banner once" || { echo "  ✗ red should banner: $out"; fail=1; }
  _mk 172000; out="$(_hook S1)"; { echo "$out" | grep -q 'additionalContext' && ! echo "$out" | grep -q 'systemMessage'; } \
    && echo "  ✓ still red → badge only, NO repeat banner (no nag)" || { echo "  ✗ repeat red should not banner: $out"; fail=1; }
  _mk 188000; out="$(_hook S1)"; echo "$out" | grep -q 'systemMessage' && echo "  ✓ deep red 94% → escalation banner once" || { echo "  ✗ deep red should escalate: $out"; fail=1; }
  _mk 60000;  _hook S1 >/dev/null   # context drops (a /clear happened)
  _mk 170000; out="$(_hook S1)"; echo "$out" | grep -q 'systemMessage' && echo "  ✓ re-arm after /clear → banner again" || { echo "  ✗ should re-arm: $out"; fail=1; }

  # authoritative limit (ctx-accuracy fix) — preTokens proves a 1M window even when current
  # total is small (post-compact). Without the override, total=100k + compact_boundary
  # preTokens=767107 MUST tier to 1M (10%), not 200k (50%).
  unset PSK_SESSION_CONTEXT_LIMIT
  printf '{"type":"system","subtype":"compact_boundary","compactMetadata":{"trigger":"manual","preTokens":767107}}\n{"type":"assistant","message":{"usage":{"input_tokens":100000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n' > "$t/tx.jsonl"
  _lim="$(resolve_limit 100000 "$t/tx.jsonl")"
  [ "$_lim" = 1000000 ] && echo "  ✓ preTokens=767107 → 1M tier (post-compact 1M session tiered correctly)" || { echo "  ✗ preTokens should force 1M tier, got limit=$_lim"; fail=1; }
  # no 220k cliff — a total just over 200k resolves to the 1M tier (monotonic, no inversion)
  printf '{"type":"assistant","message":{"usage":{"input_tokens":210000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n' > "$t/tx.jsonl"
  _lim2="$(resolve_limit 210000 "$t/tx.jsonl")"
  [ "$_lim2" = 1000000 ] && echo "  ✓ total 210k → 1M tier (no 220k cliff)" || { echo "  ✗ total 210k should be 1M tier, got limit=$_lim2"; fail=1; }
  export PSK_SESSION_CONTEXT_LIMIT=200000
  rm -rf "$t"
  [ "$fail" = 0 ] && echo "  self-test: PASS (3-level badge + red-only de-duped banner + re-arm)" || { echo "  self-test: FAIL"; return 1; }
}

# --- opt badge (parity with the breadcrumb) — read optimize-state directly, fail-safe.
# Resolves relative to THIS script (agent/scripts/), so it works whether cwd is the
# project root or a parent workspace (nested-kit install). Empty if no state file.
_statusline_opt_badge() {
  local root state st
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || return 0
  state="$root/.portable-spec-kit/optimize-state.yml"
  [ -f "$state" ] || return 0
  st="$(grep -m1 '^status:' "$state" 2>/dev/null | sed 's/^status:[[:space:]]*//; s/[[:space:]]*$//')"
  case "$st" in
    optimized) printf 'opt: 🟢 optimized' ;;
    review)    printf 'opt: 🟡 review' ;;
    stale)     printf 'opt: 🔴 stale' ;;
    *)         return 0 ;;
  esac
}

# --- STATUSLINE mode: the STRUCTURAL surface (Claude Code statusLine) ----------
# Claude Code pipes the session JSON to this command and renders stdout as the
# persistent status bar EVERY turn. Unlike the breadcrumb badge (rendered by the
# agent — trust-based, dilutes as context fills), the statusline is agent-independent:
# the user always sees ctx, even when the agent skips its breadcrumb. Fail-safe: any
# error / missing data → print nothing, exit 0 (Claude Code shows an empty bar, never errors).
run_statusline() {
  local stdin transcript total limit pct color emo line opt
  stdin="$(cat 2>/dev/null || true)"
  transcript="$(printf '%s' "$stdin" | grep -o '"transcript_path":"[^"]*"' | head -1 | sed 's/.*"transcript_path":"//; s/"$//')"
  [ -n "$transcript" ] || transcript="$(newest_transcript)"
  [ -f "$transcript" ] || exit 0
  total="$(context_tokens_of "$transcript")"
  [ -n "$total" ] && [ "$total" -gt 0 ] 2>/dev/null || exit 0
  limit="$(resolve_limit "$total" "$transcript")"
  pct=$(( total * 100 / limit ))
  color="$(health_color "$pct")"; emo="$(emoji_of "$color")"
  line="ctx: ${emo} ${pct}%"
  opt="$(_statusline_opt_badge)"
  [ -n "$opt" ] && line="${line}  ·  ${opt}"
  # Progress monitor (long-op heartbeat) — the THIRD always-on surface. Mirrors how this
  # statusline carries ctx + opt: it also carries an actively-running long-op's progress
  # (`run: <label> · <elapsed> · <count>`) so a backgrounded suite/build/gate is never a
  # silent wait to the user. psk-progress.sh --statusline prints nothing when no op is live.
  local prog _prog_sh
  _prog_sh="$(dirname "${BASH_SOURCE[0]}")/psk-progress.sh"
  if [ -x "$_prog_sh" ]; then
    prog="$(bash "$_prog_sh" --statusline 2>/dev/null || true)"
    [ -n "$prog" ] && line="${line}  ·  ${prog}"
  fi
  printf '%s\n' "$line"
}

case "${1:-}" in
  --badge)      shift; run_badge "${1:-}" ;;
  --statusline) run_statusline ;;
  --check)      shift; run_check "${1:-}" ;;
  --self-test)  run_self_test ;;
  "" )          run_hook ;;
  * )           echo "usage: psk-session-monitor.sh [--badge|--statusline|--check [transcript]|--self-test]" >&2; exit 2 ;;
esac
