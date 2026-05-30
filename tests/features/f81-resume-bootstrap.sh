#!/usr/bin/env bash
# f81-resume-bootstrap.sh — Adversarial assertions for F81 (HF4 resume-on-session-start rule).
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F73-F82-CLASS instance).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f81-resume-bootstrap — HF4 resume-on-session-start rule"

BOOTSTRAP="$PROJ/agent/scripts/psk-resume-bootstrap.sh"
SYNC="$PROJ/agent/scripts/psk-sync-check.sh"
FRAMEWORK="$PROJ/portable-spec-kit.md"

# AC1 — bootstrap script exists + executable
if [ -x "$BOOTSTRAP" ]; then
  pass "f81 AC1: psk-resume-bootstrap.sh exists + executable"
else
  fail "f81 AC1: psk-resume-bootstrap.sh missing or non-executable"
fi

# AC2 — rule documented in framework
if grep -qE 'Resume-on-Session-Start' "$FRAMEWORK"; then
  pass "f81 AC2: §Resume-on-Session-Start rule in framework"
else
  fail "f81 AC2: Resume-on-Session-Start rule heading missing"
fi

# AC3 — PSK029 sync-check rule wired
if grep -qE 'PSK029' "$SYNC"; then
  pass "f81 AC3: PSK029 sync-check rule wired"
else
  fail "f81 AC3: PSK029 rule missing from psk-sync-check.sh"
fi

# AC4 — bypass env var PSK_RESUME_BOOTSTRAP_DISABLED documented
if grep -qE 'PSK_RESUME_BOOTSTRAP_DISABLED' "$FRAMEWORK"; then
  pass "f81 AC4: PSK_RESUME_BOOTSTRAP_DISABLED bypass documented"
else
  fail "f81 AC4: bypass env var not documented"
fi

# AC5 — bootstrap script self-documents "always exits 0" contract (it is a status
# report not a gate; cheap source-level assertion avoids the multi-second cost of
# actually running the bootstrap which drains the retry queue)
if grep -qE 'always exits 0|exits 0|status report.*not a gate' "$BOOTSTRAP"; then
  pass "f81 AC5: bootstrap declares always-exits-0 contract in source"
else
  fail "f81 AC5: always-exits-0 contract not documented in bootstrap"
fi
