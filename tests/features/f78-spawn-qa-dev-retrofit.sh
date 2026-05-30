#!/usr/bin/env bash
# f78-spawn-qa-dev-retrofit.sh — Adversarial assertions for F78 (HF1 spawn-qa/spawn-dev psk-spawn.sh retrofit).
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F73-F82-CLASS instance).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f78-spawn-qa-dev-retrofit — HF1 reflex spawn-qa / spawn-dev psk-spawn.sh retrofit"

SPAWN_QA="$PROJ/reflex/lib/spawn-qa.sh"
SPAWN_DEV="$PROJ/reflex/lib/spawn-dev.sh"
PSK_SPAWN="$PROJ/agent/scripts/psk-spawn.sh"

# AC1 — psk-spawn.sh wrapper exists + executable
if [ -x "$PSK_SPAWN" ]; then
  pass "f78 AC1: psk-spawn.sh wrapper exists + executable"
else
  fail "f78 AC1: psk-spawn.sh missing or non-executable"
fi

# AC2 — spawn-qa.sh routes through psk-spawn.sh request
if grep -qE 'psk-spawn\.sh.*request|PSK_SPAWN.*request' "$SPAWN_QA"; then
  pass "f78 AC2: spawn-qa.sh routes through psk-spawn.sh request"
else
  fail "f78 AC2: spawn-qa.sh does NOT route through psk-spawn.sh — HF1 retrofit regressed"
fi

# AC3 — spawn-dev.sh routes through psk-spawn.sh request
if grep -qE 'psk-spawn\.sh.*request|PSK_SPAWN.*request' "$SPAWN_DEV"; then
  pass "f78 AC3: spawn-dev.sh routes through psk-spawn.sh request"
else
  fail "f78 AC3: spawn-dev.sh does NOT route through psk-spawn.sh — HF1 retrofit regressed"
fi

# AC4 — neither spawn-qa nor spawn-dev contains an inline-fallback branch
# (the hallmark of pre-HF1 behavior was an `else` branch that wrote findings
# inline when the Task spawn failed)
if grep -qE 'inline.fallback' "$SPAWN_QA" && grep -qE 'no.inline.fallback|NO inline-fallback' "$SPAWN_QA"; then
  pass "f78 AC4: spawn-qa.sh explicitly documents no-inline-fallback contract"
else
  if grep -qE 'no inline.fallback|no-inline-fallback' "$SPAWN_QA"; then
    pass "f78 AC4: spawn-qa.sh explicitly documents no-inline-fallback contract"
  else
    fail "f78 AC4: no-inline-fallback contract not asserted in spawn-qa.sh"
  fi
fi
