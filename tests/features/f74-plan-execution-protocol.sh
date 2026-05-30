#!/usr/bin/env bash
# f74-plan-execution-protocol.sh — Adversarial assertions for F74 (Plan Execution Protocol).
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F73-F82-CLASS instance).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f74-plan-execution-protocol — §Plan Execution Protocol (5th reliability layer)"

RUN_PLAN="$PROJ/agent/scripts/psk-run-plan.sh"
PLAN_SAVE="$PROJ/agent/scripts/psk-plan-save.sh"
EXEC_TEMPLATE="$PROJ/.portable-spec-kit/templates/plan-executable.md"
FRAMEWORK="$PROJ/portable-spec-kit.md"

# AC1 — §Plan Execution Protocol rule documented
if grep -qE '^## Plan Execution Protocol' "$FRAMEWORK"; then
  pass "f74 AC1: §Plan Execution Protocol rule in framework"
else
  fail "f74 AC1: §Plan Execution Protocol heading missing"
fi

# AC2 — driver script exists + executable
if [ -x "$RUN_PLAN" ]; then
  pass "f74 AC2: psk-run-plan.sh driver exists + executable"
else
  fail "f74 AC2: psk-run-plan.sh missing or non-executable"
fi

# AC3 — plan-save with approve gate exists
if [ -x "$PLAN_SAVE" ] && grep -qE 'approve\)' "$PLAN_SAVE"; then
  pass "f74 AC3: psk-plan-save.sh approve subcommand defined"
else
  fail "f74 AC3: psk-plan-save.sh approve subcommand missing"
fi

# AC4 — executable-plan template exists with phases: frontmatter spec
if [ -f "$EXEC_TEMPLATE" ] && grep -qE '^phases:' "$EXEC_TEMPLATE"; then
  pass "f74 AC4: plan-executable.md template includes phases: frontmatter"
else
  fail "f74 AC4: plan-executable.md template missing or lacks phases:"
fi

# AC5 — schema_version: 1 mandated in framework
if grep -qE 'schema_version:[[:space:]]*1' "$FRAMEWORK"; then
  pass "f74 AC5: schema_version: 1 mandated in framework"
else
  fail "f74 AC5: schema_version: 1 mandate missing in framework"
fi
