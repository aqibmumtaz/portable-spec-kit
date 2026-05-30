#!/usr/bin/env bash
# f79-critic-spawn-retrofit.sh — Adversarial assertions for F79 (HF2 psk-critic-spawn.sh retrofit through psk-spawn.sh).
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F73-F82-CLASS instance).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f79-critic-spawn-retrofit — HF2 psk-critic-spawn.sh routes through psk-spawn.sh"

CRITIC_SPAWN="$PROJ/agent/scripts/psk-critic-spawn.sh"
PSK_SPAWN="$PROJ/agent/scripts/psk-spawn.sh"

# AC1 — psk-critic-spawn.sh exists + executable
if [ -x "$CRITIC_SPAWN" ]; then
  pass "f79 AC1: psk-critic-spawn.sh exists + executable"
else
  fail "f79 AC1: psk-critic-spawn.sh missing or non-executable"
fi

# AC2 — psk-spawn.sh wrapper exists (dependency of HF2 retrofit)
if [ -x "$PSK_SPAWN" ]; then
  pass "f79 AC2: psk-spawn.sh wrapper exists + executable"
else
  fail "f79 AC2: psk-spawn.sh missing or non-executable"
fi

# AC3 — critic-spawn routes through psk-spawn.sh request (HF2 retrofit signal)
if grep -qE 'psk-spawn\.sh.*request|PSK_SPAWN.*request' "$CRITIC_SPAWN"; then
  pass "f79 AC3: psk-critic-spawn.sh routes through psk-spawn.sh request"
else
  fail "f79 AC3: psk-critic-spawn.sh does NOT route through psk-spawn.sh — HF2 retrofit regressed"
fi

# AC4 — all 5 critic templates supported (STEP_9_VALIDATION, FEATURE_COMPLETE, INIT, NEW_SETUP, EXISTING_SETUP)
#       REINIT folded into INIT (v0.6.62) — one template covers create + refresh.
COUNT=0
for tpl in STEP_9_VALIDATION FEATURE_COMPLETE INIT NEW_SETUP EXISTING_SETUP; do
  if grep -qE "$tpl" "$CRITIC_SPAWN"; then
    COUNT=$((COUNT+1))
  fi
done
if [ "$COUNT" -ge 5 ]; then
  pass "f79 AC4: all 5 critic templates present (STEP_9_VALIDATION..EXISTING_SETUP) — count=$COUNT"
else
  fail "f79 AC4: only $COUNT of 5 critic templates present in psk-critic-spawn.sh"
fi
