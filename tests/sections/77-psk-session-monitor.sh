#!/bin/bash
# tests/sections/77-psk-session-monitor.sh — §Session Health Indicator
# regression coverage (QA-D22-P7-001, cycle-01-pass-007).
#
# Dim 22 (self-test integrity) requires every feature with mutation entries in
# reflex/lib/self-test-mutation.sh to have a corresponding tests/sections/ file.
# psk-session-monitor.sh has mutation entries (Mutation 7, threshold logic) but no
# dedicated section. This file covers the monitor's badge thresholds, statusline
# output, and bypass/limit env vars with deterministic transcript fixtures.
#
# Independently runnable: bash tests/sections/77-psk-session-monitor.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "Section 77 — Session Health Indicator (psk-session-monitor.sh)"

_S77_SM="$PROJ/agent/scripts/psk-session-monitor.sh"
_S77_TMP=$(mktemp -d)

# --- 77.1: monitor script exists + executable ---
[ -x "$_S77_SM" ] \
  && pass "77.1: psk-session-monitor.sh exists + executable" \
  || fail "77.1: psk-session-monitor.sh missing or not executable"

# Fixtures: deterministic transcript lines pinned to a 200k window.
# Green band (~20%): 40k tokens. Red band (~90%): 180k tokens.
printf '{"type":"assistant","message":{"usage":{"input_tokens":40000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}\n' > "$_S77_TMP/green.jsonl"
printf '{"type":"assistant","message":{"usage":{"input_tokens":180000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}\n' > "$_S77_TMP/red.jsonl"

# --- 77.2: --badge green band emits a green badge with a percentage ---
_S77_GREEN=$(PSK_SESSION_CONTEXT_LIMIT=200000 bash "$_S77_SM" --badge "$_S77_TMP/green.jsonl" 2>/dev/null)
if echo "$_S77_GREEN" | grep -q '🟢' && echo "$_S77_GREEN" | grep -qE '[0-9]+%'; then
  pass "77.2: --badge green band → 🟢 + percentage ($_S77_GREEN)"
else
  fail "77.2: --badge green band unexpected output: '$_S77_GREEN'"
fi

# --- 77.3: --badge red band emits a red badge (threshold logic load-bearing) ---
_S77_RED=$(PSK_SESSION_CONTEXT_LIMIT=200000 bash "$_S77_SM" --badge "$_S77_TMP/red.jsonl" 2>/dev/null)
if echo "$_S77_RED" | grep -q '🔴'; then
  pass "77.3: --badge red band → 🔴 ($_S77_RED)"
else
  fail "77.3: --badge red band should be 🔴, got: '$_S77_RED'"
fi

# --- 77.4: --check prints a full reading (tokens / limit / pct) ---
_S77_CHECK=$(PSK_SESSION_CONTEXT_LIMIT=200000 bash "$_S77_SM" --check "$_S77_TMP/red.jsonl" 2>/dev/null)
if echo "$_S77_CHECK" | grep -qiE 'limit' && echo "$_S77_CHECK" | grep -qE '[0-9]+'; then
  pass "77.4: --check prints a full reading (limit + numbers present)"
else
  fail "77.4: --check output missing expected reading: '$(echo "$_S77_CHECK" | head -1)'"
fi

# --- 77.5: PSK_SESSION_MONITOR_DISABLED=1 is a silent no-op ---
_S77_DIS=$(PSK_SESSION_MONITOR_DISABLED=1 bash "$_S77_SM" --badge "$_S77_TMP/red.jsonl" 2>/dev/null)
_S77_DIS_RC=$?
if [ "$_S77_DIS_RC" -eq 0 ] && [ -z "$_S77_DIS" ]; then
  pass "77.5: PSK_SESSION_MONITOR_DISABLED=1 → silent no-op (exit 0, no output)"
else
  fail "77.5: disabled monitor should be silent no-op (rc=$_S77_DIS_RC, out='$_S77_DIS')"
fi

# --- 77.6: PSK_SESSION_CONTEXT_LIMIT honored (same usage, larger window → lower band) ---
# 180k tokens against a 1M window is green (~18%), not red — proves the limit env var drives the band.
_S77_BIGWIN=$(PSK_SESSION_CONTEXT_LIMIT=1000000 bash "$_S77_SM" --badge "$_S77_TMP/red.jsonl" 2>/dev/null)
if echo "$_S77_BIGWIN" | grep -q '🟢'; then
  pass "77.6: PSK_SESSION_CONTEXT_LIMIT=1000000 reclassifies 180k as 🟢 (limit env var load-bearing)"
else
  fail "77.6: 180k against 1M window should be 🟢, got: '$_S77_BIGWIN'"
fi

# --- 77.7: --statusline emits a ctx: line (reads session JSON on stdin) ---
# Statusline reads a session-info JSON on stdin; on missing/empty data it must exit 0 (fail-safe).
_S77_SL=$(echo '{}' | bash "$_S77_SM" --statusline 2>/dev/null)
_S77_SL_RC=$?
if [ "$_S77_SL_RC" -eq 0 ]; then
  pass "77.7: --statusline exits 0 (fail-safe on minimal stdin)"
else
  fail "77.7: --statusline should exit 0 fail-safe (rc=$_S77_SL_RC)"
fi

# --- 77.8: mutation entry exists in self-test-mutation.sh (Dim 22 coverage contract) ---
if grep -q 'mut_session_monitor_threshold\|session-monitor/threshold' "$PROJ/reflex/lib/self-test-mutation.sh" 2>/dev/null; then
  pass "77.8: self-test-mutation.sh has the session-monitor threshold mutation (Dim 22 contract met)"
else
  fail "77.8: self-test-mutation.sh missing session-monitor mutation entry"
fi

# --- 77.9: framework documents §Session Health Indicator ---
grep -q '### Session Health Indicator' "$PROJ/portable-spec-kit.md" \
  && pass "77.9: portable-spec-kit.md documents §Session Health Indicator" \
  || fail "77.9: §Session Health Indicator missing from framework"

# --- 77.10: flow doc 33 exists (QA-D11-P7-001 companion) ---
[ -f "$PROJ/docs/work-flows/33-session-health.md" ] \
  && pass "77.10: docs/work-flows/33-session-health.md exists" \
  || fail "77.10: flow doc 33 missing"

# Cleanup
rm -rf "$_S77_TMP"

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  RESULTS (77-psk-session-monitor): $PASS passed, $FAIL failed, $TOTAL total"
  echo "═══════════════════════════════════════════"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi
