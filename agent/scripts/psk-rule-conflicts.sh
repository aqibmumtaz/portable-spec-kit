#!/bin/bash
# mechanical-script: psk-rule-conflicts.sh — rule conflict scanner (no AI invocation)
# ════════════════════════════════════════════════════════════════
# psk-rule-conflicts.sh — Rule-conflict detector (v0.6.18+, ADR-030)
#
# Programmatically scans the kit's MANDATORY rules from portable-spec-kit.md +
# skill files + ADRs, builds a rule-graph, surfaces contradictions / silent
# stoppers / precedence ambiguities.
#
# v0.6.18 ships deterministic-only detection (regex-based pair scan).
# LLM-probe layer for ambiguous pairs deferred to v0.6.18+ release iteration.
#
# Usage:
#   bash agent/scripts/psk-rule-conflicts.sh [--scan|--health|--json]
# Output:
#   plain — human readable report
#   --json — JSON for downstream consumers (/optimize cat 10)
#
# Bypass: PSK_RULE_CONFLICTS_DISABLED=1
# ════════════════════════════════════════════════════════════════

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
MODE="${1:---scan}"

if [ "${PSK_RULE_CONFLICTS_DISABLED:-0}" = "1" ]; then
  case "$MODE" in
    --json) echo '{"status":"disabled","conflicts":[]}' ;;
    *) echo "rule-conflict detection disabled (PSK_RULE_CONFLICTS_DISABLED=1)" ;;
  esac
  exit 0
fi

# Source files to scan for rules
KIT_FILE="$PROJ_ROOT/portable-spec-kit.md"
SKILLS_DIR="$PROJ_ROOT/.portable-spec-kit/skills"

if [ ! -f "$KIT_FILE" ]; then
  case "$MODE" in
    --json) echo '{"status":"skipped","reason":"portable-spec-kit.md not found","conflicts":[]}' ;;
    *) echo "portable-spec-kit.md not found — skipping" ;;
  esac
  exit 0
fi

# Extract MANDATORY rules — lines containing MUST/MANDATORY/NEVER/ALWAYS keywords
# in conditional/imperative context (sentences ending with the rule)
TMP_RULES=$(mktemp)
grep -hnE "(MUST [a-z]|MANDATORY[^a-z]|NEVER [a-z]|ALWAYS [a-z]|must NOT|never|always)" "$KIT_FILE" 2>/dev/null | head -200 > "$TMP_RULES"

if [ -d "$SKILLS_DIR" ]; then
  find "$SKILLS_DIR" -name "*.md" -exec grep -hnE "(MUST [a-z]|MANDATORY[^a-z]|NEVER [a-z]|ALWAYS [a-z]|must NOT|never|always)" {} + 2>/dev/null | head -200 >> "$TMP_RULES"
fi

RULE_COUNT=$(wc -l < "$TMP_RULES" | tr -d ' ')

# Deterministic conflict detection — pairs of rules where:
#   - One has "always X" or "MUST X"
#   - Another has "never X" or "MUST NOT X"
#   - X overlap: both reference the same subject (file path · action verb · concept)

CONFLICTS_JSON="["
CONFLICT_COUNT=0
FIRST=true

# Common subjects to check for always/never overlap
SUBJECTS=(
  "commit"
  "push"
  "edit symlink"
  "edit framework"
  ".env"
  "secret"
  "personal memory"
  "auto-commit"
  "cycle id"
  "scope change"
  "test"
  "agent/AGENT.md"
  "agent/AGENT_CONTEXT.md"
  "PHILOSOPHY.md"
)

for subject in "${SUBJECTS[@]}"; do
  always_lines=$(grep -iE "(always|MUST|MANDATORY)[^.]*$subject" "$TMP_RULES" 2>/dev/null | head -3)
  never_lines=$(grep -iE "(never|MUST NOT|cannot|do not)[^.]*$subject" "$TMP_RULES" 2>/dev/null | head -3)

  if [ -n "$always_lines" ] && [ -n "$never_lines" ]; then
    # Potential conflict — both always-rule and never-rule reference this subject
    # In real conflict detection, an LLM probe would judge whether the contexts truly conflict
    # For deterministic scaffold, we surface as "potential-conflict-needs-review"

    [ "$FIRST" = true ] && FIRST=false || CONFLICTS_JSON="$CONFLICTS_JSON,"
    subject_esc=$(echo "$subject" | sed 's/"/\\"/g')
    always_first=$(echo "$always_lines" | head -1 | sed 's/"/\\"/g; s/\\/\\\\/g' | tr -d '\n' | head -c 200)
    never_first=$(echo "$never_lines" | head -1 | sed 's/"/\\"/g; s/\\/\\\\/g' | tr -d '\n' | head -c 200)

    CONFLICTS_JSON="$CONFLICTS_JSON{\"subject\":\"$subject_esc\",\"type\":\"potential-always-never-overlap\",\"severity\":\"advisory\",\"always_rule\":\"$always_first\",\"never_rule\":\"$never_first\"}"
    CONFLICT_COUNT=$((CONFLICT_COUNT + 1))
  fi
done

CONFLICTS_JSON="$CONFLICTS_JSON]"

case "$MODE" in
  --json)
    cat << EOF
{
  "schema_version": 1,
  "scanned_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "rule_count": $RULE_COUNT,
  "conflict_count": $CONFLICT_COUNT,
  "scan_mode": "deterministic",
  "llm_probe_deferred": "v0.6.18+ release iteration — LLM probe for ambiguous pairs not yet implemented",
  "conflicts": $CONFLICTS_JSON
}
EOF
    ;;
  --health)
    if [ "$CONFLICT_COUNT" -eq 0 ]; then
      echo "🟢 rule-conflicts: 0 detected (scanned $RULE_COUNT rules, deterministic pass)"
    else
      echo "🟡 rule-conflicts: $CONFLICT_COUNT potential conflict(s) detected (advisory — review manually)"
    fi
    ;;
  *)
    echo "═══════════════════════════════════════════════════════════"
    echo "  PSK Rule-Conflict Detection (v0.6.18+ deterministic mode)"
    echo "═══════════════════════════════════════════════════════════"
    echo "Scanned: portable-spec-kit.md + .portable-spec-kit/skills/*.md"
    echo "Rules captured: $RULE_COUNT"
    echo "Potential conflicts (deterministic regex pass): $CONFLICT_COUNT"
    echo ""
    if [ "$CONFLICT_COUNT" -gt 0 ]; then
      echo "Conflicts (advisory — review for false positives):"
      echo "$CONFLICTS_JSON" | tr ',' '\n' | head -20
    else
      echo "✓ No deterministic conflicts detected"
    fi
    echo ""
    echo "Note: LLM-probe layer for ambiguous pairs deferred — current pass is regex-only."
    echo "Bypass: PSK_RULE_CONFLICTS_DISABLED=1"
    ;;
esac

rm -f "$TMP_RULES"
exit 0
