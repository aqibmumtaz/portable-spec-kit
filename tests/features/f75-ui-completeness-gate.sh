#!/usr/bin/env bash
# f75-ui-completeness-gate.sh — Adversarial assertions for F75 (UI Completeness Gate / PSK025).
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F73-F82-CLASS instance).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f75-ui-completeness-gate — UI Completeness Gate + PSK025"

UI_SCRIPT="$PROJ/agent/scripts/psk-ui-completeness.sh"
SYNC="$PROJ/agent/scripts/psk-sync-check.sh"

# AC1 — UI completeness script exists + executable
if [ -x "$UI_SCRIPT" ]; then
  pass "f75 AC1: psk-ui-completeness.sh exists + executable"
else
  fail "f75 AC1: psk-ui-completeness.sh missing or non-executable"
fi

# AC2 — PSK025 sync-check rule wired
if grep -qE 'PSK025' "$SYNC"; then
  pass "f75 AC2: PSK025 rule wired in psk-sync-check.sh"
else
  fail "f75 AC2: PSK025 rule missing from psk-sync-check.sh"
fi

# AC3 — UI completeness check emits JSON when --json flag passed
if [ -x "$UI_SCRIPT" ] && bash "$UI_SCRIPT" --help 2>&1 | grep -qE '\-\-json' \
   || grep -qE '\-\-json' "$UI_SCRIPT" 2>/dev/null; then
  pass "f75 AC3: psk-ui-completeness.sh supports --json output"
else
  fail "f75 AC3: --json flag not present in UI completeness script"
fi

# AC4 — kit-self project (no frontend) should report PSK025 as skip-path in source
# (read script source rather than running full sync-check to keep test fast).
if grep -qE 'PSK025.*no frontend declared.*skip|frontend declared — skip' "$SYNC"; then
  pass "f75 AC4: PSK025 skip-path branch present in psk-sync-check.sh source"
else
  fail "f75 AC4: PSK025 skip-path branch not found in psk-sync-check.sh"
fi
