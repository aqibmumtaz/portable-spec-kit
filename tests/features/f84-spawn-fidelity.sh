#!/usr/bin/env bash
# f84-spawn-fidelity.sh — Adversarial assertions for F84 (HF8 §Spawn Fidelity 6th reliability layer).
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F73-F82-CLASS instance).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f84-spawn-fidelity — §Spawn Fidelity 6th reliability layer + Standard Spawn Recipe skill"

FRAMEWORK="$PROJ/portable-spec-kit.md"
SKILL="$PROJ/.portable-spec-kit/skills/spawn-fidelity.md"
GATES="$PROJ/reflex/lib/gates.sh"

# AC1 — §Spawn Fidelity rule documented in framework
if grep -qE '^## Spawn Fidelity' "$FRAMEWORK"; then
  pass "f84 AC1: §Spawn Fidelity rule in portable-spec-kit.md"
else
  fail "f84 AC1: §Spawn Fidelity heading missing"
fi

# AC2 — framework declares "six enforcement layers" (HF8 update)
if grep -qE 'six enforcement layers|6 enforcement layers|6th reliability layer' "$FRAMEWORK"; then
  pass "f84 AC2: framework declares 6th reliability layer (Spawn Fidelity)"
else
  fail "f84 AC2: 6th-layer declaration missing in §Reliability Architecture intro"
fi

# AC3 — spawn-fidelity skill file exists
if [ -f "$SKILL" ]; then
  pass "f84 AC3: spawn-fidelity skill at .portable-spec-kit/skills/spawn-fidelity.md"
else
  fail "f84 AC3: spawn-fidelity skill file missing"
fi

# AC4 — Standard Spawn Recipe codified in framework
if grep -qE 'Standard Spawn Recipe' "$FRAMEWORK"; then
  pass "f84 AC4: Standard Spawn Recipe codified in framework"
else
  fail "f84 AC4: Standard Spawn Recipe not referenced in framework"
fi

# AC5 — 13th mechanical gate audit-completeness wired in gates.sh
if grep -qE 'audit.completeness|audit_completeness' "$GATES"; then
  pass "f84 AC5: 13th gate audit-completeness wired in reflex/lib/gates.sh"
else
  fail "f84 AC5: 13th gate not wired in gates.sh"
fi

# AC6 — Dim 27 + Dim 28 registered in qa-agent.md
QA_AGENT="$PROJ/reflex/prompts/qa-agent.md"
if [ -f "$QA_AGENT" ] && grep -qE 'Dimension 27' "$QA_AGENT" && grep -qE 'Dimension 28' "$QA_AGENT"; then
  pass "f84 AC6: Dim 27 + Dim 28 registered in qa-agent.md"
else
  fail "f84 AC6: Dim 27 or Dim 28 not registered in qa-agent.md"
fi
