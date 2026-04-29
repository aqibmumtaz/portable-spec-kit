#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Portable Spec Kit — Full Test Suite Orchestrator
#
# v0.6.11 — closes QA-TEST-COUPLING-01 (Option C, thematic split).
# This file is a THIN ORCHESTRATOR. Tests live in tests/sections/*.sh,
# each independently runnable. Shared helpers + globals in tests/lib.sh.
#
# Usage:
#   bash tests/test-spec-kit.sh                  # run all sections
#   bash tests/sections/01-infrastructure.sh     # run one section
#   bash tests/sections/04-reflex.sh             # ditto
#
# Why this design — the audit history:
#   QA-TEST-COUPLING-01 (v0.6.11 iter-1 finding) flagged that 69 of 70
#   features in SPECS.md all referenced this single test file. One flake
#   reported all 69 features as broken simultaneously. Option C splits
#   into thematic files preserving cohesion via tests/lib.sh while
#   restoring real per-section runtime independence.
#
# Aggregation pattern:
#   Each section file is sourced (not bash'd) by this orchestrator. They
#   share PASS/FAIL/TOTAL counters defined in tests/lib.sh, so totals
#   accumulate naturally across all sections without IPC. The orchestrator
#   prints the final aggregated summary.
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load shared helpers + globals (PASS/FAIL/TOTAL/PROJ/ROOT/kit_grep/...)
source "$SCRIPT_DIR/lib.sh"

# Section files in dependency order — infrastructure first (sets up TEMP +
# verifies framework files exist), then pipeline, then reliability, then
# reflex (largest, depends on rest of kit being intact).
SECTIONS=(
  "$SCRIPT_DIR/sections/01-infrastructure.sh"
  "$SCRIPT_DIR/sections/02-pipeline.sh"
  "$SCRIPT_DIR/sections/03-reliability.sh"
  "$SCRIPT_DIR/sections/04-reflex.sh"
)

for s in "${SECTIONS[@]}"; do
  if [ ! -f "$s" ]; then
    echo "✗ section file missing: $s" >&2
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL + 1))
    continue
  fi
  # shellcheck source=/dev/null
  source "$s"
done

# Final aggregated summary
echo ""
echo "═══════════════════════════════════════════"
echo "  RESULTS: $PASS passed, $FAIL failed, $TOTAL total"
echo "═══════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ ALL TESTS PASSED"
  exit 0
else
  echo "  ❌ $FAIL TESTS FAILED"
  exit 1
fi
