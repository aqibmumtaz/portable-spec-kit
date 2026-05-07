#!/usr/bin/env bash
# F70 — Reflex AVACR Loop (the largest feature — covers Loop 1-3 work)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/reflex-fixtures.sh"

section "F70 — Reflex AVACR + Loop 1-3 enforcement"

# Core reflex layout
if [ -d "$PROJ/reflex" ]; then
  pass "F70: reflex/ dir present"
else
  fail "F70: reflex/ dir missing"
fi

if [ -f "$PROJ/reflex/run.sh" ]; then
  pass "F70: reflex/run.sh present"
else
  fail "F70: reflex/run.sh missing"
fi

# Prompts
assert_reflex_prompt "qa-agent.md"
assert_reflex_prompt "dev-agent.md"

# Loop 1 (G19-G23) — specific code paths
if [ -f "$PROJ/reflex/lib/spawn-qa.sh" ]; then
  pass "F70: G19 spawn-qa.sh present"
else
  fail "F70: G19 spawn-qa.sh missing"
fi

if [ -f "$PROJ/reflex/lib/check-rft-integrity.sh" ]; then
  pass "F70: G20 check-rft-integrity.sh present"
else
  fail "F70: G20 check-rft-integrity.sh missing"
fi

if [ -f "$PROJ/reflex/lib/doc-code-diff.sh" ]; then
  pass "F70: G22 doc-code-diff.sh present"
else
  fail "F70: G22 doc-code-diff.sh missing"
fi

# Loop 3 abort-enforcement (L1-L6)
# L1 — preconditions
if [ -f "$PROJ/reflex/lib/preconditions.sh" ] && \
   grep -qE "check_prior_abort" "$PROJ/reflex/lib/preconditions.sh"; then
  pass "F70: L1 check_prior_abort present"
else
  fail "F70: L1 check_prior_abort missing"
fi

# L2 — EXIT trap in run.sh
if [ -f "$PROJ/reflex/run.sh" ] && \
   grep -qE "trap.*EXIT" "$PROJ/reflex/run.sh"; then
  pass "F70: L2 EXIT trap present in run.sh"
else
  fail "F70: L2 EXIT trap missing"
fi

# L3 — .iter-status.yml writes in loop.sh
if [ -f "$PROJ/reflex/lib/loop.sh" ] && \
   grep -qE "iter-status" "$PROJ/reflex/lib/loop.sh"; then
  pass "F70: L3 .iter-status.yml writes present"
else
  fail "F70: L3 .iter-status.yml writes missing"
fi

# L4 — abort integrity probe
if [ -f "$PROJ/reflex/lib/check-abort-integrity.sh" ]; then
  pass "F70: L4 check-abort-integrity.sh present"
else
  fail "F70: L4 check-abort-integrity.sh missing"
fi

# L5 — convergence-audit gate (9th gate)
if [ -f "$PROJ/reflex/lib/gates.sh" ] && \
   grep -qE "convergence-audit" "$PROJ/reflex/lib/gates.sh"; then
  pass "F70: L5 9th gate convergence-audit present"
else
  fail "F70: L5 9th gate missing"
fi

# L6 — §Convergence in framework
if kit_grep "Convergence" -q; then
  pass "F70: L6 §Convergence section documented"
else
  fail "F70: L6 §Convergence section missing"
fi

# 8th gate — mandate-compliance (Loop 2 Phase F)
if [ -f "$PROJ/reflex/lib/mandate-audit.sh" ]; then
  pass "F70: 8th gate mandate-audit.sh present"
else
  fail "F70: 8th gate missing"
fi

if [ -f "$PROJ/reflex/lib/gates.sh" ] && \
   grep -qE "mandate-compliance" "$PROJ/reflex/lib/gates.sh"; then
  pass "F70: 8th gate wired in gates.sh"
else
  fail "F70: 8th gate not wired"
fi

# Dim 25 mandate-compliance probe in qa-agent prompt
if grep -qiE "(Dim 25|Dimension 25|mandate-compliance|Mandate.Compliance)" "$PROJ/reflex/prompts/qa-agent.md" 2>/dev/null; then
  pass "F70: Dim 25 mandate-compliance probe registered"
else
  fail "F70: Dim 25 not registered"
fi

# Reflex Finding Classification — scope: target-project | kit | meta
if kit_grep "scope: target-project" -q && kit_grep "scope: kit" -q && kit_grep "scope: meta" -q; then
  pass "F70: 3-scope finding classification documented"
else
  fail "F70: 3-scope finding classification missing"
fi

# Execution isolation — sandbox + dev-branch + protected-files write-ban
if kit_grep "sandbox worktree" -qi || kit_grep "QA-Agent runs in a sandbox" -qi; then
  pass "F70: QA sandbox-worktree isolation documented"
else
  fail "F70: QA sandbox isolation missing"
fi

if kit_grep "Protected-files write-ban" -qi || kit_grep "protected-files" -qi || kit_grep "AGENT.md.*never" -qi; then
  pass "F70: protected-files write-ban documented"
else
  fail "F70: protected-files write-ban missing"
fi

# install-into-project.sh
if [ -f "$PROJ/reflex/install-into-project.sh" ] || [ -f "$PROJ/install.sh" ]; then
  pass "F70: reflex install entry present"
else
  fail "F70: reflex install entry missing"
fi
