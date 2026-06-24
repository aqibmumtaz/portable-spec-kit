#!/bin/bash
# mechanical-script: psk-rule.sh — kit-rule lookup helper (KIT-GAP-0055, v0.6.74)
#
# Sub-Agent Prompt Fidelity 9th reliability layer — single source of truth
# for actionable kit rules. Sub-agents (and main agent) call this script
# before any decision that depends on a kit rule. Output is verbatim rule
# text; paraphrasing in prompts is forbidden by psk-prompt-lint.sh + PSK042.
#
# Usage:
#   psk-rule.sh lookup <rule-id>            — print verbatim rule text
#   psk-rule.sh list                        — list all rule ids
#   psk-rule.sh applies-to <decision-class> — list rules that apply to a class
#   psk-rule.sh validate <id> <text>        — assert text matches rule body byte-for-byte
#   psk-rule.sh --help

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RULES_FILE="${PSK_RULES_FILE:-$PROJ_ROOT/.portable-spec-kit/kit-rules.yml}"

cmd_lookup() {
  local id="${1:-}"
  [ -z "$id" ] && { echo "usage: psk-rule.sh lookup <rule-id>" >&2; exit 2; }
  [ ! -f "$RULES_FILE" ] && { echo "rules file not found: $RULES_FILE" >&2; exit 1; }

  local out
  out=$(awk -v want="$id" '
    /^  - id:/ {
      sub(/^  - id:[[:space:]]*/, "", $0); gsub(/[[:space:]]+$/, "", $0)
      cur_id = $0; in_entry = 1; in_text = 0
      next
    }
    in_entry && /^    text: \|/ { in_text = 1; next }
    in_text && /^      / {
      if (cur_id == want) { sub(/^      /, "", $0); print }
      next
    }
    in_text && /^[a-z]/ { in_text = 0; in_entry = 0 }
    /^  - id:/ { in_text = 0 }
  ' "$RULES_FILE")

  # QA-2-01 (cycle-01-pass-001): an unknown rule-id MUST surface an error, not
  # exit 0 silently. The Layer 9 contract has every sub-agent prompt run
  # `psk-rule.sh lookup <rule-id>` before any decision; a typo'd or renamed id
  # that prints nothing + exits 0 leaves the sub-agent with NO rule text and no
  # signal (violates §Error Handling). Match cmd_validate()'s not-found
  # behavior: "rule not found: <id>" to stderr + exit 1.
  if [ -z "$out" ]; then
    echo "rule not found: $id" >&2
    exit 1
  fi
  printf '%s\n' "$out"
}

cmd_list() {
  [ ! -f "$RULES_FILE" ] && { echo "rules file not found: $RULES_FILE" >&2; exit 1; }
  awk '
    /^  - id:/ {
      sub(/^  - id:[[:space:]]*/, "", $0); gsub(/[[:space:]]+$/, "", $0)
      cur_id = $0
    }
    /^    surface:/ {
      sub(/^    surface:[[:space:]]*/, "", $0); gsub(/[[:space:]]+$/, "", $0)
      printf "%-35s %s\n", cur_id, $0
    }
  ' "$RULES_FILE"
}

cmd_applies_to() {
  local target="${1:-}"
  [ -z "$target" ] && { echo "usage: psk-rule.sh applies-to <decision-class>" >&2; exit 2; }
  [ ! -f "$RULES_FILE" ] && { echo "rules file not found: $RULES_FILE" >&2; exit 1; }

  awk -v want="$target" '
    /^  - id:/ {
      sub(/^  - id:[[:space:]]*/, "", $0); gsub(/[[:space:]]+$/, "", $0)
      cur_id = $0
    }
    /^    applies_to:/ {
      sub(/^    applies_to:[[:space:]]*/, "", $0); gsub(/[[:space:]]+$/, "", $0)
      if ($0 == want) print cur_id
    }
  ' "$RULES_FILE"
}

cmd_validate() {
  local id="${1:-}" text="${2:-}"
  [ -z "$id" ] || [ -z "$text" ] && {
    echo "usage: psk-rule.sh validate <rule-id> <text-to-check>" >&2; exit 2
  }
  local rule_text
  rule_text=$(cmd_lookup "$id")
  [ -z "$rule_text" ] && { echo "rule not found: $id" >&2; exit 1; }

  if [ "$rule_text" = "$text" ]; then
    echo "✓ text matches rule '$id' verbatim"
    exit 0
  else
    echo "✗ text does NOT match rule '$id' verbatim" >&2
    echo "" >&2
    echo "  Expected:" >&2
    echo "$rule_text" | sed 's/^/    /' >&2
    echo "" >&2
    echo "  Got:" >&2
    echo "$text" | sed 's/^/    /' >&2
    exit 1
  fi
}

cmd_help() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  lookup)     shift; cmd_lookup "$@" ;;
  list)       cmd_list ;;
  applies-to) shift; cmd_applies_to "$@" ;;
  validate)   shift; cmd_validate "$@" ;;
  -h|--help|"") cmd_help ;;
  *) echo "unknown subcommand: $1" >&2; exit 2 ;;
esac
