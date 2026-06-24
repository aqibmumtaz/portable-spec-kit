#!/bin/bash
# mechanical-script: psk-prompt-lint.sh — Sub-Agent Prompt Fidelity lint (KIT-GAP-0055, v0.6.74)
#
# §Sub-Agent Prompt Fidelity (9th reliability layer) prompt validator.
# Every prompt file that references a kit rule (anywhere in the kit) MUST:
#   (a) include `kit_rule_citations:` frontmatter listing rule ids it cites,
#   (b) have each cited rule's text appear verbatim in the prompt body,
#   (c) include the mandatory preamble (added in P3).
#
# Usage:
#   psk-prompt-lint.sh <prompt-file>       — lint one prompt
#   psk-prompt-lint.sh --all               — lint every prompt under kit
#   psk-prompt-lint.sh --strict            — exit 1 on any violation
#   psk-prompt-lint.sh --check-preamble    — only verify preamble presence (P3)
#   psk-prompt-lint.sh --help
#
# Exit: 0 clean · 1 violations · 2 usage error

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RULE_SCRIPT="$PROJ_ROOT/agent/scripts/psk-rule.sh"
PREAMBLE_MARKER="Before any decision, run \`psk-rule.sh lookup"

STRICT=0
CHECK_PREAMBLE_ONLY=0
ALL_MODE=0
VIOLATIONS=0
CHECKED=0

# Discover every prompt file under kit (reflex/prompts/*.md + workflow phases/*.md +
# plan prompts/*.md + critic templates) — skip per-pass artifacts in reflex/history/
discover_prompts() {
  {
    find "$PROJ_ROOT/reflex/prompts" -name '*.md' -type f 2>/dev/null
    find "$PROJ_ROOT/.portable-spec-kit/workflows" -path '*/phases/*.md' -type f 2>/dev/null
    find "$PROJ_ROOT/agent/plans" -path '*/prompts/*.md' -type f 2>/dev/null
  } | sort -u
}

# Extract kit_rule_citations: from prompt frontmatter
extract_citations() {
  local f="$1"
  awk '
    BEGIN { in_fm=0; in_list=0 }
    /^---$/ { if (in_fm) exit; in_fm=1; next }
    in_fm && /^kit_rule_citations:/ { in_list=1; next }
    in_list && /^  - / {
      sub(/^  - /, "", $0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      print $0; next
    }
    in_list && /^[a-z_]+:/ { in_list=0 }
  ' "$f"
}

# Check if a prompt references any kit rule (heuristic: it mentions decision
# classes governed by kit rules — verdict, scope, severity, bucket, disposition, etc.)
prompt_references_rule() {
  local f="$1"
  grep -qiE 'verdict|GRANTED|DENIED|scope:|severity|Bucket [A-D]|disposition|kit-rule|psk-rule' "$f" 2>/dev/null
}

# Verify the preamble is present (P3 requirement)
has_preamble() {
  local f="$1"
  grep -qF "$PREAMBLE_MARKER" "$f" 2>/dev/null
}

lint_one() {
  local f="$1"
  CHECKED=$((CHECKED+1))
  local rel="${f#$PROJ_ROOT/}"

  if [ "$CHECK_PREAMBLE_ONLY" = "1" ]; then
    if ! has_preamble "$f"; then
      echo "✗ $rel: missing mandatory preamble (P3)" >&2
      VIOLATIONS=$((VIOLATIONS+1))
    fi
    return
  fi

  # If prompt references decisions/rules, it MUST have citations + preamble
  if prompt_references_rule "$f"; then
    local cits
    cits=$(extract_citations "$f")
    if [ -z "$cits" ]; then
      echo "✗ $rel: references kit rules but missing kit_rule_citations: frontmatter" >&2
      VIOLATIONS=$((VIOLATIONS+1))
    else
      # Verify each cited rule's text is in the prompt body (verbatim)
      while IFS= read -r rid; do
        [ -z "$rid" ] && continue
        local rule_text
        rule_text=$(bash "$RULE_SCRIPT" lookup "$rid" 2>/dev/null)
        if [ -z "$rule_text" ]; then
          echo "✗ $rel: cites unknown rule '$rid'" >&2
          VIOLATIONS=$((VIOLATIONS+1))
          continue
        fi
        # Check first line of rule text appears in prompt body (cheap byte-check)
        local first_line
        first_line=$(echo "$rule_text" | head -1)
        if ! grep -qF "$first_line" "$f" 2>/dev/null; then
          echo "✗ $rel: cites rule '$rid' but text not present verbatim (first line: '$first_line')" >&2
          VIOLATIONS=$((VIOLATIONS+1))
        fi
      done <<< "$cits"
    fi

    # Preamble required when prompt makes decisions
    if ! has_preamble "$f"; then
      echo "⚠ $rel: references decisions but missing P3 preamble (advisory until P3 lands)" >&2
    fi
  fi
}

main() {
  case "${1:-}" in
    --help|-h|"")
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
  esac

  for arg in "$@"; do
    case "$arg" in
      --strict)          STRICT=1 ;;
      --check-preamble)  CHECK_PREAMBLE_ONLY=1 ;;
      --all)             ALL_MODE=1 ;;
    esac
  done

  if [ "$ALL_MODE" = "1" ]; then
    while IFS= read -r f; do
      [ -f "$f" ] && lint_one "$f"
    done < <(discover_prompts)
  else
    # Single-file mode — positional arg
    local f="$1"
    [ -f "$f" ] || { echo "prompt file not found: $f" >&2; exit 2; }
    lint_one "$f"
  fi

  if [ "$VIOLATIONS" -eq 0 ]; then
    echo "✓ prompt-lint clean ($CHECKED prompt(s) checked)"
    exit 0
  else
    echo "" >&2
    echo "✗ prompt-lint: $VIOLATIONS violation(s) across $CHECKED prompt(s)" >&2
    if [ "$STRICT" = "1" ]; then
      exit 1
    else
      echo "  (advisory mode — run with --strict to fail on violations)" >&2
      exit 0
    fi
  fi
}

main "$@"
