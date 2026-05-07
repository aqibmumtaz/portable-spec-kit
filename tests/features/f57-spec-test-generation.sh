#!/usr/bin/env bash
# F57 — Spec-based test generation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F57 — Spec-based test generation"

if kit_grep "Spec-Based Test Generation" -qi || kit_grep "test stub" -qi; then
  pass "F57: §Spec-Based Test Generation documented"
else
  fail "F57: §Spec-Based Test Generation missing"
fi

if kit_grep "forward flow" -qi && kit_grep "retroactive" -qi; then
  pass "F57: forward vs retroactive flow distinguished"
else
  fail "F57: flow distinction missing"
fi

if kit_grep "stub completion" -qi || kit_grep "check_stub_complete" -q || kit_grep "incomplete markers" -qi; then
  pass "F57: stub completion gate documented"
else
  fail "F57: stub completion gate missing"
fi

# psk-bootstrap-check.sh exists per F57 design
if [ -f "$PROJ/agent/scripts/psk-bootstrap-check.sh" ]; then
  pass "F57: psk-bootstrap-check.sh present"
else
  fail "F57: psk-bootstrap-check.sh missing"
fi

# Bootstrap check has --quiet and --remediate flags
if [ -f "$PROJ/agent/scripts/psk-bootstrap-check.sh" ] && \
   grep -qE "(\-\-quiet|\-\-remediate)" "$PROJ/agent/scripts/psk-bootstrap-check.sh"; then
  pass "F57: bootstrap-check has --quiet/--remediate flags"
else
  fail "F57: bootstrap-check flags missing"
fi
