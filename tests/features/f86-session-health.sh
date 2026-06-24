#!/usr/bin/env bash
# f86-session-health.sh — Per-feature audit for F86 (Session Health Indicator / context-window
# drift monitor). ADR-088 Approach A: every feature gets a tests/features/fNN-*.sh selective audit.
# G31 (QA-1-02) — F86 previously pointed only at tests/sections/77-psk-session-monitor.sh; this
# feature-test closes the ADR-088 deviation. Behavioral where it matters (badge bands, threshold
# env vars, --statusline surface, fail-safe exit 0), not structural-grep only.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f86-session-health — Session Health Indicator (psk-session-monitor.sh) F86 acceptance criteria"

SM="$PROJ/agent/scripts/psk-session-monitor.sh"
FRAMEWORK="$PROJ/portable-spec-kit.md"
INSTALL_HOOKS="$PROJ/agent/scripts/psk-install-hooks.sh"

# Fixtures: synthetic Claude Code transcripts with known context occupancy.
_F86_TMP=$(mktemp -d)
trap 'rm -rf "$_F86_TMP"' EXIT
printf '{"type":"assistant","message":{"usage":{"input_tokens":40000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}\n'  > "$_F86_TMP/green.jsonl"   # 20% of 200k
printf '{"type":"assistant","message":{"usage":{"input_tokens":130000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}\n' > "$_F86_TMP/yellow.jsonl"  # 65% of 200k
printf '{"type":"assistant","message":{"usage":{"input_tokens":180000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}\n' > "$_F86_TMP/red.jsonl"     # 90% of 200k

# AC1 — script present + executable
if [ -x "$SM" ]; then
  pass "f86 AC1: psk-session-monitor.sh present + executable"
else
  fail "f86 AC1: psk-session-monitor.sh missing or not executable"
fi

# AC2 — BEHAVIORAL: --badge green band (<50%) emits 🟢 + a percentage
_f86_g=$(PSK_SESSION_CONTEXT_LIMIT=200000 bash "$SM" --badge "$_F86_TMP/green.jsonl" 2>/dev/null)
if echo "$_f86_g" | grep -q '🟢' && echo "$_f86_g" | grep -qE '[0-9]+%'; then
  pass "f86 AC2: green band (<50%) → 🟢 + percentage ($_f86_g)"
else
  fail "f86 AC2: green band unexpected: '$_f86_g'"
fi

# AC3 — BEHAVIORAL: --badge yellow band (50–79%) emits 🟡
_f86_y=$(PSK_SESSION_CONTEXT_LIMIT=200000 bash "$SM" --badge "$_F86_TMP/yellow.jsonl" 2>/dev/null)
if echo "$_f86_y" | grep -q '🟡'; then
  pass "f86 AC3: yellow band (50–79%) → 🟡 ($_f86_y)"
else
  fail "f86 AC3: yellow band should be 🟡, got: '$_f86_y'"
fi

# AC4 — BEHAVIORAL: --badge red band (≥80%) emits 🔴
_f86_r=$(PSK_SESSION_CONTEXT_LIMIT=200000 bash "$SM" --badge "$_F86_TMP/red.jsonl" 2>/dev/null)
if echo "$_f86_r" | grep -q '🔴'; then
  pass "f86 AC4: red band (≥80%) → 🔴 ($_f86_r)"
else
  fail "f86 AC4: red band should be 🔴, got: '$_f86_r'"
fi

# AC5 — BEHAVIORAL: threshold env vars are load-bearing. Same 65% usage, but YELLOW_PCT raised
# to 70 → must drop back to green (65 < 70).
_f86_thr=$(PSK_SESSION_CONTEXT_LIMIT=200000 PSK_SESSION_YELLOW_PCT=70 bash "$SM" --badge "$_F86_TMP/yellow.jsonl" 2>/dev/null)
if echo "$_f86_thr" | grep -q '🟢'; then
  pass "f86 AC5: PSK_SESSION_YELLOW_PCT honored (65% < 70 → 🟢: $_f86_thr)"
else
  fail "f86 AC5: YELLOW_PCT override not honored, got: '$_f86_thr'"
fi

# AC6 — BEHAVIORAL: PSK_SESSION_CONTEXT_LIMIT load-bearing (same usage, 1M window → lower band)
_f86_big=$(PSK_SESSION_CONTEXT_LIMIT=1000000 bash "$SM" --badge "$_F86_TMP/red.jsonl" 2>/dev/null)
if echo "$_f86_big" | grep -q '🟢'; then
  pass "f86 AC6: PSK_SESSION_CONTEXT_LIMIT honored (180k/1M=18% → 🟢: $_f86_big)"
else
  fail "f86 AC6: CONTEXT_LIMIT override not honored, got: '$_f86_big'"
fi

# AC7 — BEHAVIORAL: --statusline surface exits 0 fail-safe on minimal stdin
_f86_sl=$(echo '{}' | bash "$SM" --statusline 2>/dev/null); _f86_sl_rc=$?
if [ "$_f86_sl_rc" -eq 0 ]; then
  pass "f86 AC7: --statusline structural surface exits 0 (fail-safe)"
else
  fail "f86 AC7: --statusline should exit 0 fail-safe (rc=$_f86_sl_rc)"
fi

# AC8 — BEHAVIORAL: PSK_SESSION_MONITOR_DISABLED=1 full bypass (silent, exit 0, no badge)
_f86_dis=$(PSK_SESSION_MONITOR_DISABLED=1 bash "$SM" --badge "$_F86_TMP/red.jsonl" 2>/dev/null); _f86_dis_rc=$?
if [ "$_f86_dis_rc" -eq 0 ] && [ -z "$_f86_dis" ]; then
  pass "f86 AC8: PSK_SESSION_MONITOR_DISABLED=1 → silent no-op (exit 0, empty)"
else
  fail "f86 AC8: MONITOR_DISABLED should be silent no-op (rc=$_f86_dis_rc out='$_f86_dis')"
fi

# AC9 — BEHAVIORAL: fail-safe on missing / garbage transcript (exit 0, badge suppressed)
echo 'not json at all' > "$_F86_TMP/garbage.jsonl"
_f86_bad=$(bash "$SM" --badge "$_F86_TMP/garbage.jsonl" 2>/dev/null); _f86_bad_rc=$?
_f86_missing_rc=0; bash "$SM" --badge "$_F86_TMP/does-not-exist.jsonl" >/dev/null 2>&1 || _f86_missing_rc=$?
if [ "$_f86_bad_rc" -eq 0 ] && [ "$_f86_missing_rc" -eq 0 ]; then
  pass "f86 AC9: fail-safe — garbage + missing transcript both exit 0, badge suppressed"
else
  fail "f86 AC9: fail-safe broken (garbage rc=$_f86_bad_rc, missing rc=$_f86_missing_rc)"
fi

# AC10 — installer wiring: psk-install-hooks.sh wires statusLine + UserPromptSubmit for the monitor
if [ -f "$INSTALL_HOOKS" ] && grep -q 'psk-session-monitor.sh' "$INSTALL_HOOKS" \
   && grep -qE 'statusLine|statusline' "$INSTALL_HOOKS" && grep -q 'UserPromptSubmit' "$INSTALL_HOOKS"; then
  pass "f86 AC10: psk-install-hooks.sh wires monitor as statusLine + UserPromptSubmit"
else
  fail "f86 AC10: installer wiring for session monitor missing"
fi

# AC11 — framework documents the F86 feature (§Session Health Indicator)
if grep -q 'Session Health Indicator' "$FRAMEWORK"; then
  pass "f86 AC11: §Session Health Indicator documented in portable-spec-kit.md"
else
  fail "f86 AC11: §Session Health Indicator section missing from framework"
fi
