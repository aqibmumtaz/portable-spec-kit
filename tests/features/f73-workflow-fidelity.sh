#!/usr/bin/env bash
# f73-workflow-fidelity.sh — Adversarial assertions for F73 (Workflow Fidelity).
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F73-F82-CLASS instance).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f73-workflow-fidelity — §Workflow Fidelity (4th reliability layer)"

WF_SCRIPT="$PROJ/agent/scripts/psk-workflow-state.sh"
SPAWN_SCRIPT="$PROJ/agent/scripts/psk-spawn.sh"
FRAMEWORK="$PROJ/portable-spec-kit.md"

# AC1 — §Workflow Fidelity rule present in framework
if grep -qE '^## Workflow Fidelity' "$FRAMEWORK"; then
  pass "f73 AC1: §Workflow Fidelity rule documented in portable-spec-kit.md"
else
  fail "f73 AC1: §Workflow Fidelity heading missing in framework"
fi

# AC2 — phase state machine script exists + executable
if [ -x "$WF_SCRIPT" ]; then
  pass "f73 AC2: psk-workflow-state.sh exists + executable"
else
  fail "f73 AC2: psk-workflow-state.sh missing or non-executable"
fi

# AC3 — psk-spawn.sh exists (sub-agent spawn wrapper)
if [ -x "$SPAWN_SCRIPT" ]; then
  pass "f73 AC3: psk-spawn.sh exists + executable"
else
  fail "f73 AC3: psk-spawn.sh missing or non-executable"
fi

# AC4 — bypass env var PSK_WORKFLOW_STATE_DISABLED documented in framework
if grep -qE 'PSK_WORKFLOW_STATE_DISABLED' "$FRAMEWORK"; then
  pass "f73 AC4: PSK_WORKFLOW_STATE_DISABLED bypass documented"
else
  fail "f73 AC4: bypass env var not documented in framework"
fi

# AC5 — no-inline-fallback contract assertion in psk-spawn.sh
if grep -qE 'no inline.fallback|no-inline-fallback|inline_fallback|structurally no path' "$SPAWN_SCRIPT" 2>/dev/null; then
  pass "f73 AC5: psk-spawn.sh enforces no-inline-fallback contract"
else
  fail "f73 AC5: no-inline-fallback contract not asserted in psk-spawn.sh"
fi
