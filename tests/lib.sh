# tests/lib.sh — shared helpers + globals for all test sections
#
# v0.6.11 — closes QA-TEST-COUPLING-01 (Option C):
# Sourced by tests/test-spec-kit.sh (orchestrator) AND by each
# tests/sections/*.sh file. Provides PASS/FAIL/TOTAL counters,
# pass()/fail()/section() helpers, kit_grep, and PROJ/ROOT/TEMP/KIT_ALL
# globals. Each section file independently runnable:
#   bash tests/sections/04-reflex.sh
# All sections runnable together via the orchestrator:
#   bash tests/test-spec-kit.sh
# Counters are incremented in the same shell when sections are SOURCED
# (not bash'd) by the orchestrator, so totals aggregate naturally.
#
# Idempotent: re-sourcing this file resets counters only if not already set.

# Counters (global, accumulated across sections when orchestrator sources them)
PASS="${PASS:-0}"
FAIL="${FAIL:-0}"
TOTAL="${TOTAL:-0}"

pass() { ((PASS++)); ((TOTAL++)); echo "  ✓ $1"; }
fail() { ((FAIL++)); ((TOTAL++)); echo "  ✗ $1"; }
section() { echo ""; echo "═══ $1 ═══"; }

# Project paths — derived from this file's location so sections can be
# bash'd directly from any cwd.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="${PROJ:-$(cd "$LIB_DIR/.." && pwd)}"
ROOT="${ROOT:-$PROJ/../..}"

# Kit grep — searches core framework file + all skill/reference files.
# Supports the skill-based architecture where content may be in
# portable-spec-kit.md OR .portable-spec-kit/skills/*.md
# Usage: kit_grep "pattern" [-q|-qi]
kit_grep() {
  local pattern="$1"
  local flags="${2:--q}"
  grep $flags "$pattern" "$PROJ/portable-spec-kit.md" 2>/dev/null && return 0
  for ref in "$PROJ/.portable-spec-kit/skills/"*.md; do
    [ -f "$ref" ] || continue
    grep $flags "$pattern" "$ref" 2>/dev/null && return 0
  done
  return 1
}

# Kit files — all framework files concatenated (for grep -o, grep -c patterns)
KIT_ALL="$PROJ/portable-spec-kit.md"
if ls "$PROJ/.portable-spec-kit/skills/"*.md >/dev/null 2>&1; then
  KIT_ALL_FILES="$PROJ/portable-spec-kit.md $PROJ/.portable-spec-kit/skills/*.md"
else
  KIT_ALL_FILES="$PROJ/portable-spec-kit.md"
fi

# Per-run TEMP — only set once if not already set (orchestrator sets it; sections inherit)
TEMP="${TEMP:-/tmp/psk-test-$(date +%s)}"
