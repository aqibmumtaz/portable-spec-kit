#!/bin/bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist — v0.6.60 HF7b)
# ════════════════════════════════════════════════════════════════
# psk-coverage-overlap-check.sh — Symmetric self-evolution probe
#
# Closes the structural blind spot the user surfaced in v0.6.27:
# the kit's auto-evolution was biased toward ADDITION (find more
# bugs / add more probes) and blind to CONSOLIDATION (this probe
# duplicates that one — merge them). Mode C's 12-row seed was
# ALL duplicate coverage and shipped without any structural alarm.
#
# This script extracts the kit's coverage signatures from each
# probing mechanism and reports overlap clusters.
#
# Implements P9 — Symmetric self-evolution (PHILOSOPHY.md).
#
# Usage:
#   bash agent/scripts/psk-coverage-overlap-check.sh [--scan|--health|--json|--proposal FILE]
#
# Modes:
#   --scan      human-readable report of overlap clusters (default)
#   --health    one-line indicator for /optimize cat 14
#   --json      machine-parseable for /optimize integration
#   --proposal  scan a single proposed-rule file for overlaps with existing
#               kit mechanisms (Phase 6 Gate G integration)
#
# Bypass:
#   PSK_OVERLAP_CHECK_DISABLED=1
# ════════════════════════════════════════════════════════════════

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "$0")/.." && pwd)/..}"
PROJ_ROOT="$(cd "$PROJ_ROOT" && pwd)"

MODE="--scan"
PROPOSAL_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --scan|--health|--json) MODE="$1"; shift ;;
    --proposal)             MODE="--proposal"; PROPOSAL_FILE="$2"; shift 2 ;;
    --help|-h)
      sed -n '/^# Usage:/,/^# ====/p' "$0" | head -20
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ "${PSK_OVERLAP_CHECK_DISABLED:-0}" = "1" ]; then
  case "$MODE" in
    --health) echo "overlap: bypassed (PSK_OVERLAP_CHECK_DISABLED=1)" ;;
    --json)   echo '{"status":"bypassed","overlap_count":0,"clusters":[]}' ;;
    *)        echo "[overlap-check] disabled via PSK_OVERLAP_CHECK_DISABLED=1" ;;
  esac
  exit 0
fi

# ─── Coverage-signature extraction ──────────────────────────────

# Each kit mechanism that probes/audits the project is a "coverage source."
# We extract one keyword per source representing what it covers.

extract_dimensions() {
  # qa-agent.md `### Dimension N — <subject>` headers + the `| N | <subject> |` table
  local qa="$PROJ_ROOT/reflex/prompts/qa-agent.md"
  [ -f "$qa" ] || return
  # Section headers
  grep -oE "^### Dimension [0-9]+ — [^(]+" "$qa" 2>/dev/null | \
    sed -E 's/^### Dimension ([0-9]+) — ([^(]+).*/dim-\1|\2/' | \
    awk -F'|' 'NF >= 2 { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); printf "%-12s %s\n", $1, tolower($2) }'
  # Table rows
  awk '/^\| [0-9]+ \|/ { sub(/^\| /, "dim-"); sub(/ \| /, "|"); sub(/ \|.*/, ""); print }' "$qa" 2>/dev/null | \
    awk -F'|' 'NF >= 2 { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); printf "%-12s %s\n", $1, tolower($2) }'
}

extract_phase0_helpers() {
  # reflex/lib/check-*.sh — name + first-line-comment
  local lib="$PROJ_ROOT/reflex/lib"
  [ -d "$lib" ] || return
  for f in "$lib"/check-*.sh; do
    [ -f "$f" ] || continue
    local base
    base=$(basename "$f" .sh)
    local subject
    subject=$(awk '/^#.*— /{ sub(/^#[^—]*— /, ""); sub(/[ ]*\(.*$/, ""); print; exit }' "$f" 2>/dev/null | head -c 80)
    [ -z "$subject" ] && subject=$(echo "$base" | sed 's/check-//; s/-/ /g')
    printf "%-12s %s\n" "ph0-${base#check-}" "$(echo "$subject" | tr 'A-Z' 'a-z')"
  done
}

extract_sync_check_fns() {
  # agent/scripts/psk-sync-check.sh `check_<name>()` functions
  local sc="$PROJ_ROOT/agent/scripts/psk-sync-check.sh"
  [ -f "$sc" ] || return
  grep -oE "^check_[a-z_]+\(\)" "$sc" 2>/dev/null | sed 's/()$//' | while read -r fn; do
    # Find the comment block above this function
    local subject
    subject=$(grep -B1 "^${fn}()" "$sc" | head -1 | sed -E 's/^# *//; s/^[A-Z]+: *//' | head -c 80)
    [ -z "$subject" ] && subject=$(echo "$fn" | sed 's/check_//; s/_/ /g')
    printf "%-12s %s\n" "sync-${fn#check_}" "$(echo "$subject" | tr 'A-Z' 'a-z')"
  done
}

extract_optimize_cats() {
  # agent/scripts/psk-optimize.sh `# Cat N — <subject>`
  local opt="$PROJ_ROOT/agent/scripts/psk-optimize.sh"
  [ -f "$opt" ] || return
  grep -oE "# Cat [0-9]+ — [^(]+" "$opt" 2>/dev/null | \
    sed -E 's/# Cat ([0-9]+) — ([^(]+).*/cat-\1|\2/' | \
    awk -F'|' 'NF >= 2 { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); printf "%-12s %s\n", $1, tolower($2) }'
}

# ─── Overlap detection (deterministic v1) ───────────────────────

# Build the full coverage map, then look for keyword clusters across sources.
# v1 = simple-keyword overlap. v2 (deferred) = LLM-judged semantic overlap.

OVERLAP_KEYWORDS=(
  "rft|r→f→t|requirements traceability|feature.*test"
  "claim|claim verification|public claim"
  "doc[- ]code|doc.*sync|documentation drift"
  "rule[- ]conflict|always.never|contradiction"
  "reqs?[- ]coverage|R[ -]bullet"
  "install|installer|script inventory"
  "philosophy|principle"
  "audit[- ]coverage|coverage gap"
  "ui polish|client[- ]grade|design system"
  "version|version bump|version cascade"
  "test[- ]quality|stub|trivial test"
  "production[- ]readiness|release ready"
  "security|injection|secret|cve"
  "performance|N\+1|O\(n²\)|hot loop"
  "architecture|architectural compliance|ADR"
  "tech[- ]debt|deprecated|smelly"
  "audit[- ]trail|register hygiene"
  "kit[- ]bootstrap|hooks installed"
  "host environment|portability"
  "acceptance criterion|fidelity"
  "temporal coupling"
  "self[- ]test"
  "auditor[- ]output|hygiene"
)

# Aggregate all coverage sources into one stream
build_coverage_map() {
  extract_dimensions
  extract_phase0_helpers
  extract_sync_check_fns
  extract_optimize_cats
}

# For each keyword cluster, find sources that mention it.
detect_overlaps() {
  local map="$1"
  local overlaps=""
  local count=0
  for kw_pattern in "${OVERLAP_KEYWORDS[@]}"; do
    local matches
    matches=$(echo "$map" | grep -iE "$kw_pattern" 2>/dev/null | awk '{ print $1 }' | sort -u | tr '\n' ',' | sed 's/,$//')
    local n_matches
    n_matches=$(echo "$matches" | tr ',' '\n' | grep -c '^.' 2>/dev/null | head -1)
    n_matches="${n_matches:-0}"
    if [ "$n_matches" -ge 2 ]; then
      overlaps="${overlaps}${kw_pattern%%|*}|${matches}|${n_matches}\n"
      count=$((count + 1))
    fi
  done
  echo -e "$overlaps"
  return 0
}

# ─── Proposal-mode: scan a single file for overlap with existing ──

scan_proposal() {
  local prop="$1"
  if [ ! -f "$prop" ]; then
    echo "[overlap-check] proposal file not found: $prop" >&2
    exit 1
  fi
  local map
  map=$(build_coverage_map)
  local prop_text
  prop_text=$(cat "$prop" | tr 'A-Z' 'a-z')
  local hits=""
  local count=0
  for kw_pattern in "${OVERLAP_KEYWORDS[@]}"; do
    if echo "$prop_text" | grep -qiE "$kw_pattern"; then
      local existing_sources
      existing_sources=$(echo "$map" | grep -iE "$kw_pattern" 2>/dev/null | awk '{ print $1 }' | sort -u | tr '\n' ',' | sed 's/,$//')
      if [ -n "$existing_sources" ]; then
        hits="${hits}  - keyword \"${kw_pattern%%|*}\" already covered by: ${existing_sources}\n"
        count=$((count + 1))
      fi
    fi
  done
  if [ "$count" = "0" ]; then
    echo "[overlap-check] proposal '$prop' — clean (no detected overlap with existing mechanisms)"
    exit 0
  fi
  echo "[overlap-check] proposal '$prop' has $count keyword(s) overlapping existing coverage:"
  echo -e "$hits"
  exit 1
}

# ─── Main ─────────────────────────────────────────────────────

case "$MODE" in
  --proposal)
    scan_proposal "$PROPOSAL_FILE"
    ;;
  --health)
    map=$(build_coverage_map)
    overlaps=$(detect_overlaps "$map")
    n=$(echo "$overlaps" | grep -c '^.' 2>/dev/null | head -1)
    n="${n:-0}"
    if [ "$n" -gt 0 ]; then
      echo "overlap: 🟡 $n cluster(s) detected — run psk-coverage-overlap-check.sh --scan"
    else
      echo "overlap: 🟢 clean"
    fi
    ;;
  --json)
    # Closes QA-KIT-OVERLAP-CHECK-01 (v0.6.28): JSON-emission moved into a
    # function so `local first=1` is valid (was a syntax error outside any
    # function under POSIX bash). Also fixes "first: unbound variable" trip
    # under `set -uo pipefail` when the overlaps stream was empty (loop body
    # never executed → outer scope $first never initialized).
    emit_json_clusters() {
      local overlaps="$1"
      local first=1
      local kw sources count
      while IFS='|' read -r kw sources count; do
        [ -z "$kw" ] && continue
        [ "$first" = "1" ] || echo ","
        first=0
        printf '    {"keyword":"%s","sources":"%s","count":%s}' "$kw" "$sources" "$count"
      done <<< "$overlaps"
      echo ""
    }
    map=$(build_coverage_map)
    overlaps=$(detect_overlaps "$map")
    n=$(echo "$overlaps" | grep -c '^.' 2>/dev/null | head -1)
    n="${n:-0}"
    echo "{"
    echo "  \"status\": \"$([ "$n" -gt 0 ] && echo overlaps_found || echo clean)\","
    echo "  \"scan_mode\": \"deterministic-keyword\","
    echo "  \"overlap_count\": $n,"
    echo "  \"clusters\": ["
    emit_json_clusters "$overlaps"
    echo "  ]"
    echo "}"
    ;;
  --scan|*)
    map=$(build_coverage_map)
    echo "═══ Coverage map (kit's probing mechanisms) ═══"
    echo "$map" | head -40
    echo ""
    echo "═══ Overlap clusters (≥2 sources, deterministic-keyword v1) ═══"
    overlaps=$(detect_overlaps "$map")
    n=$(echo "$overlaps" | grep -c '^.' 2>/dev/null | head -1)
    n="${n:-0}"
    if [ "$n" = "0" ]; then
      echo "✓ no overlap clusters detected"
    else
      while IFS='|' read -r kw sources count; do
        [ -z "$kw" ] && continue
        echo "⚠ \"$kw\" → covered by $count sources: $sources"
      done <<< "$overlaps"
      echo ""
      echo "Review each cluster: are these intentional defense-in-depth (ok) or duplication that wastes tokens (consolidate)?"
    fi
    echo ""
    echo "Bypass: PSK_OVERLAP_CHECK_DISABLED=1"
    ;;
esac

exit 0
