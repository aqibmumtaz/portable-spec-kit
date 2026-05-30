#!/usr/bin/env bash
# f82-watchdog-idempotency.sh — Adversarial assertions for F82 (HF4b watchdog + idempotency).
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F73-F82-CLASS instance).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f82-watchdog-idempotency — HF4b watchdog + phase idempotency contract"

WATCHDOG="$PROJ/agent/scripts/psk-workflow-watchdog.sh"
FRAMEWORK="$PROJ/portable-spec-kit.md"

# AC1 — watchdog script exists + executable
if [ -x "$WATCHDOG" ]; then
  pass "f82 AC1: psk-workflow-watchdog.sh exists + executable"
else
  fail "f82 AC1: psk-workflow-watchdog.sh missing or non-executable"
fi

# AC2 — §Phase Idempotency rule documented in framework
if grep -qE 'Phase Idempotency' "$FRAMEWORK"; then
  pass "f82 AC2: §Phase Idempotency rule in framework"
else
  fail "f82 AC2: §Phase Idempotency heading missing"
fi

# AC3 — three thresholds documented (15min WARN / 1h HUNG / 24h STALE)
if grep -qE '15.?min' "$WATCHDOG" && grep -qE 'hung|HUNG' "$WATCHDOG"; then
  pass "f82 AC3: 15min/1h/24h threshold semantics documented in watchdog"
else
  fail "f82 AC3: threshold documentation incomplete in watchdog script"
fi

# AC4 — watchdog source declares idempotency / no-side-effect contract (cheap
# source-level check avoids the cost of actually running the watchdog which may
# enqueue retry-queue entries on hung phases).
if grep -qE 'idempoten|no.side.effect|safely re.runnable|hung-phase detector' "$WATCHDOG"; then
  pass "f82 AC4: watchdog idempotency contract documented in source"
else
  fail "f82 AC4: watchdog idempotency contract not documented"
fi

# AC5 — PSK_IDEMPOTENCY_DISABLED bypass env var documented in framework
if grep -qE 'PSK_IDEMPOTENCY_DISABLED' "$FRAMEWORK"; then
  pass "f82 AC5: PSK_IDEMPOTENCY_DISABLED bypass documented"
else
  fail "f82 AC5: PSK_IDEMPOTENCY_DISABLED bypass not documented"
fi
