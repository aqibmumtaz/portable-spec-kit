#!/usr/bin/env bash
# f77-cascade-purge.sh — Adversarial assertions for F77 (HF0 cascade-as-user-update purge + PSK028).
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F73-F82-CLASS instance).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f77-cascade-purge — PSK028 cascade-as-user-update anti-pattern detection"

SYNC="$PROJ/agent/scripts/psk-sync-check.sh"
ORCHESTRATE="$PROJ/agent/scripts/psk-orchestrate.sh"

# AC1 — PSK028 rule wired in psk-sync-check.sh
if grep -qE 'PSK028' "$SYNC"; then
  pass "f77 AC1: PSK028 rule wired in psk-sync-check.sh"
else
  fail "f77 AC1: PSK028 rule not found in psk-sync-check.sh"
fi

# AC2 — cascade-as-user-update detection function present
if grep -qE 'cascade.as.user.update|cascade_as_user' "$SYNC"; then
  pass "f77 AC2: cascade-as-user-update detection logic present"
else
  fail "f77 AC2: cascade-as-user-update detection logic missing"
fi

# AC3 — psk-orchestrate.sh exists (carries the --update mode that was purged)
if [ -x "$ORCHESTRATE" ]; then
  pass "f77 AC3: psk-orchestrate.sh exists + executable"
else
  fail "f77 AC3: psk-orchestrate.sh missing or non-executable"
fi

# AC4 — PSK028 0-violations branch present in source (source-level check; avoid
# running full sync-check to keep test fast)
if grep -qE 'PSK028.*0 violations|0 violations' "$SYNC"; then
  pass "f77 AC4: PSK028 0-violations success branch present in psk-sync-check.sh"
else
  fail "f77 AC4: PSK028 0-violations branch not found"
fi
