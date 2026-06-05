#!/usr/bin/env bash
# f85-kit-fidelity.sh — Per-feature audit for F85 (§Kit Fidelity 8th reliability layer).
# v0.6.64 — kit-fidelity-8th-layer plan deliverable.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f85-kit-fidelity — §Kit Fidelity 8th reliability layer + wrapper + inventory + 2 logs + PSK040"

FRAMEWORK="$PROJ/portable-spec-kit.md"
WRAPPER="$PROJ/agent/scripts/psk-kit-cmd.sh"
INVENTORY="$PROJ/.portable-spec-kit/kit-commands.yml"
DEV_LOG="$PROJ/agent/.kit-deviation-log"
GAP_LOG="$PROJ/agent/.kit-gap-log"
SYNC_CHECK="$PROJ/agent/scripts/psk-sync-check.sh"
FLOW_DOC="$PROJ/docs/work-flows/30-kit-fidelity.md"
SKILL="$PROJ/.portable-spec-kit/skills/kit-fidelity.md"

# AC1 — §Kit Fidelity section present in framework
if grep -qE '^## Kit Fidelity ' "$FRAMEWORK"; then
  pass "f85 AC1: §Kit Fidelity section in portable-spec-kit.md"
else
  fail "f85 AC1: §Kit Fidelity heading missing"
fi

# AC2 — framework declares §Kit Fidelity as 8th reliability layer + a current overview count.
# §Kit Fidelity stays the 8th layer; the overview total grows as new layers land
# (v0.6.74 nine, v0.6.78 ten, v0.6.79 eleven).
if grep -q '8th reliability layer' "$FRAMEWORK" && grep -qE '(eight|nine|ten|eleven|twelve) enforcement layers' "$FRAMEWORK"; then
  pass "f85 AC2: framework identifies §Kit Fidelity as 8th + declares current layer count"
else
  fail "f85 AC2: framework missing 8th-layer claim or enforcement-layers overview count"
fi

# AC3 — wrapper script present + executable
if [ -x "$WRAPPER" ]; then
  pass "f85 AC3: psk-kit-cmd.sh wrapper present + executable"
else
  fail "f85 AC3: psk-kit-cmd.sh missing or not executable"
fi

# AC4 — canonical-command inventory present
if [ -f "$INVENTORY" ] && grep -qE '^schema_version: 1$' "$INVENTORY"; then
  pass "f85 AC4: kit-commands.yml inventory present with schema_version: 1"
else
  fail "f85 AC4: kit-commands.yml missing or invalid schema_version"
fi

# AC5 — both audit-trail logs committed
if [ -f "$DEV_LOG" ] && [ -f "$GAP_LOG" ]; then
  pass "f85 AC5: .kit-deviation-log + .kit-gap-log committed"
else
  fail "f85 AC5: one or both audit logs missing"
fi

# AC6 — PSK040 sync-check function defined + registered
if grep -q 'check_psk040_kit_fidelity_coverage()' "$SYNC_CHECK"; then
  pass "f85 AC6: PSK040 check function defined in psk-sync-check.sh"
else
  fail "f85 AC6: PSK040 check function missing"
fi

# AC7 — flow doc 30 present
if [ -f "$FLOW_DOC" ]; then
  pass "f85 AC7: docs/work-flows/30-kit-fidelity.md present"
else
  fail "f85 AC7: flow doc 30-kit-fidelity.md missing"
fi

# AC8 — skill file present
if [ -f "$SKILL" ]; then
  pass "f85 AC8: .portable-spec-kit/skills/kit-fidelity.md present"
else
  fail "f85 AC8: skill file missing"
fi

# AC9 — ADR-089 in PLANS.md
if grep -q 'ADR-089' "$PROJ/agent/PLANS.md"; then
  pass "f85 AC9: ADR-089 (§Kit Fidelity 8th layer) recorded in PLANS.md"
else
  fail "f85 AC9: ADR-089 missing from PLANS.md"
fi
