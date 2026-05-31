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
# Save before sourcing sections — section files each redefine SCRIPT_DIR to
# point to tests/sections/, which would clobber the orchestrator's tests/ path.
ORCHESTRATOR_DIR="$SCRIPT_DIR"

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
  "$SCRIPT_DIR/sections/05-mandate-compliance.sh"
  "$SCRIPT_DIR/sections/97-kit-fidelity.sh"
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

# Phase T2 (Loop 4) — per-feature test discovery (Approach 3).
# Sources tests/features/f*.sh dynamically. Additive — runs alongside the
# legacy 5-section sourcing during the migration. Once all 70 features have
# been moved (Phase T5-T7), the section sourcing becomes redundant and
# sections/* will be converted to thin shims (Phase T9).
# Restore cwd: section edge-case tests (section 18) create+delete temp dirs,
# leaving the shell in a deleted directory. Feature file sourcing silently
# fails unless we return to a valid cwd first.
# Restore ORCHESTRATOR_DIR: section files redefine SCRIPT_DIR, clobbering it.
cd "$PROJ" 2>/dev/null || cd / 2>/dev/null || true
if [ -d "$ORCHESTRATOR_DIR/features" ]; then
  feature_files=( "$ORCHESTRATOR_DIR/features"/f*.sh )
  if [ -e "${feature_files[0]:-/dev/null}" ]; then
    echo ""
    echo "═══ Per-feature tests (tests/features/) ═══"
    for ff in "${feature_files[@]}"; do
      [ -f "$ff" ] && source "$ff"
    done
  fi
fi

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
