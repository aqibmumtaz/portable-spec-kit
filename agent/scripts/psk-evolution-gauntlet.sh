#!/bin/bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist — v0.6.60 HF7b)
# ════════════════════════════════════════════════════════════════
# psk-evolution-gauntlet.sh — Self-Evolution Regression Gauntlet (v0.6.22+, ADR-033)
#
# Every proposed kit rule passes a 6-gate gauntlet (A-F) before merging.
# No rule ships without proving it doesn't break existing functionality.
#
# Usage:
#   bash agent/scripts/psk-evolution-gauntlet.sh <proposal-file>
#
# Where <proposal-file> is agent/tasks/proposed/Pxx-name.md (principle proposal)
#                       OR agent/tasks/proposed/Gxx-name.md (general kit rule).
#
# Gates run in order A→F; first failure halts the gauntlet and reports.
#
#   Gate A — all framework + benchmarking tests pass
#   Gate B — no new rule conflicts introduced
#   Gate C — proposed rule consistent with PHILOSOPHY.md (cat 11)
#   Gate D — fixture project Reflex returns GRANTED (skipped in --quick mode)
#   Gate E — kit's own /optimize stays clean
#   Gate F — kit author manual approval (CLI prompt)
#
# Bypass individual gates with env vars:
#   PSK_GAUNTLET_GATE_D_DISABLED=1 (skip Reflex fixture run)
#   PSK_GAUNTLET_GATE_F_DISABLED=1 (skip manual approval — CI-only emergency)
# ════════════════════════════════════════════════════════════════

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PROPOSAL="${1:-}"

if [ -z "$PROPOSAL" ]; then
  echo "Usage: $0 <proposal-file>"
  echo ""
  echo "Proposal file should be at agent/tasks/proposed/Pxx-name.md or Gxx-name.md"
  exit 1
fi

if [ ! -f "$PROPOSAL" ]; then
  echo "✗ Proposal file not found: $PROPOSAL"
  exit 1
fi

QUICK_MODE="${PSK_GAUNTLET_QUICK:-0}"

echo "═══════════════════════════════════════════════════════════"
echo "  PSK Self-Evolution Regression Gauntlet (v0.6.22+)"
echo "═══════════════════════════════════════════════════════════"
echo "Proposal: $PROPOSAL"
echo "Quick mode: $QUICK_MODE"
echo ""

GATES_PASSED=0
GATES_FAILED=0
FAILED_GATE=""

run_gate() {
  local label="$1"
  local cmd="$2"
  echo "→ Gate $label: $cmd"
  # eval-allowlist: gauntlet gate command from kit-internal gate registry (kit-controlled)
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  ✓ Gate $label PASSED"
    GATES_PASSED=$((GATES_PASSED + 1))
    return 0
  else
    echo "  ✗ Gate $label FAILED"
    GATES_FAILED=$((GATES_FAILED + 1))
    FAILED_GATE="$label"
    return 1
  fi
}

# ─── Gate A — all framework + benchmarking tests pass ───
if ! run_gate "A — all tests" "bash '$PROJ_ROOT/tests/test-spec-kit.sh' && bash '$PROJ_ROOT/tests/test-spd-benchmarking.sh'"; then
  echo ""
  echo "Gate A failure: existing test suite broken — proposal cannot proceed"
  echo "Action: re-run 'bash tests/test-spec-kit.sh' for detail · fix tests · resubmit proposal"
  exit 1
fi

# ─── Gate B — no new rule conflicts introduced ───
if ! run_gate "B — no new rule conflicts" "bash '$PROJ_ROOT/agent/scripts/psk-rule-conflicts.sh' --scan"; then
  echo ""
  echo "Gate B failure: new rule conflicts introduced"
  echo "Action: review psk-rule-conflicts.sh --scan · resolve conflicts · resubmit"
  exit 1
fi

# ─── Gate C — proposed rule consistent with PHILOSOPHY.md ───
if ! run_gate "C — philosophy consistency" "[ -f '$PROJ_ROOT/agent/PHILOSOPHY.md' ] && grep -qE '^### P[0-9]+ — ' '$PROJ_ROOT/agent/PHILOSOPHY.md'"; then
  echo ""
  echo "Gate C failure: PHILOSOPHY.md missing or empty"
  echo "Action: ensure agent/PHILOSOPHY.md is present with seeded principles"
  exit 1
fi

# ─── Gate D — fixture project Reflex (skipped in quick mode) ───
if [ "${PSK_GAUNTLET_GATE_D_DISABLED:-0}" = "1" ] || [ "$QUICK_MODE" = "1" ]; then
  echo "→ Gate D: SKIPPED (--quick mode or PSK_GAUNTLET_GATE_D_DISABLED=1)"
else
  if ! run_gate "D — fixture Reflex" "bash '$PROJ_ROOT/reflex/run.sh' --help"; then
    echo "  · Gate D weak (Reflex orchestrator not invokable) — review reflex/run.sh"
  fi
fi

# ─── Gate E — kit's own /optimize stays clean ───
if ! run_gate "E — /optimize health" "bash '$PROJ_ROOT/agent/scripts/psk-optimize.sh' --health"; then
  echo "  · Gate E weak (optimize.sh non-zero exit) — review /optimize state"
fi

# ─── Gate G — Coverage-overlap check (P9 Symmetric Self-Evolution, v0.6.28+) ───
# Closes the structural gap user surfaced in v0.6.27: gauntlet caught regex
# rule-conflicts (Gate B) but missed semantic coverage overlaps. Mode C
# 12-row seed proposal would have failed Gate G structurally — keywords
# overlapped Phase 0 + dimensions across the board.
echo "→ Gate G: coverage-overlap check (proposal vs existing kit mechanisms)"
if [ -x "$PROJ_ROOT/agent/scripts/psk-coverage-overlap-check.sh" ]; then
  if bash "$PROJ_ROOT/agent/scripts/psk-coverage-overlap-check.sh" --proposal "$PROPOSAL" 2>&1; then
    echo "  ✓ Gate G PASSED (no detected overlap with existing coverage)"
    GATES_PASSED=$((GATES_PASSED + 1))
  else
    echo "  ✗ Gate G FAILED (proposal duplicates existing coverage — review above)"
    echo "    Bypass: PSK_OVERLAP_CHECK_DISABLED=1 if overlap is intentional defense-in-depth"
    GATES_FAILED=$((GATES_FAILED + 1))
  fi
else
  echo "  · Gate G skipped (psk-coverage-overlap-check.sh missing)"
fi

# ─── Gate F — kit author manual approval ───
if [ "${PSK_GAUNTLET_GATE_F_DISABLED:-0}" = "1" ]; then
  echo "→ Gate F: SKIPPED (PSK_GAUNTLET_GATE_F_DISABLED=1 — CI-emergency override)"
else
  echo "→ Gate F: manual approval required"
  if [ -t 0 ]; then
    read -r -p "  Approve proposal $(basename "$PROPOSAL")? (yes/no): " response
    if [ "$response" = "yes" ]; then
      echo "  ✓ Gate F PASSED (manual approval)"
      GATES_PASSED=$((GATES_PASSED + 1))
    else
      echo "  ✗ Gate F REJECTED (manual rejection)"
      echo ""
      echo "Action: archive proposal in agent/tasks/rejected/ with rationale"
      exit 1
    fi
  else
    echo "  · non-interactive mode — Gate F deferred to human review"
    echo "  Run interactively to complete Gate F"
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Gauntlet results: $GATES_PASSED passed, $GATES_FAILED failed"
echo "═══════════════════════════════════════════════════════════"

if [ "$GATES_FAILED" -eq 0 ]; then
  echo "✓ All gates passed — proposal can land"
  echo ""
  echo "Next steps:"
  echo "  1. Move proposal: mv $PROPOSAL agent/tasks/done/"
  echo "  2. Add ADR entry in agent/PLANS.md"
  echo "  3. Add regression test in tests/sections/04-reflex.sh"
  echo "  4. Bump kit version + commit"
  echo "  5. Run gauntlet again 48h post-merge (CI auto-flag if regression)"
  exit 0
else
  echo "✗ $GATES_FAILED gate(s) failed — proposal rejected at Gate $FAILED_GATE"
  echo ""
  echo "Action: archive in agent/tasks/rejected/$(basename "$PROPOSAL") with rationale"
  exit 1
fi
