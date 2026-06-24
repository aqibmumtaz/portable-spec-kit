#!/bin/bash
# mechanical-script: psk-template-quality.sh — Template Quality Bar lint (no AI invocation)
# psk-template-quality.sh — 7-criterion Template Quality Bar lint
#
# Audits a template file against the 7 mandatory criteria defined in
# portable-spec-kit.md §Template Quality Bar:
#   1. Stack-agnostic       — no hardcoded language/framework in normative sections
#   2. Domain-agnostic      — no domain vocabulary outside example blocks
#   3. Scale-agnostic       — works for 1-feature MVP and 100-feature enterprise
#   4. Useful-and-complete  — every section the feature requires is concrete
#   5. Lifecycle-aware      — explicit state markers
#   6. Self-documenting     — audit header present
#   7. Round-trippable      — scaffold passes sync-check zero-edit
#
# Usage:
#   psk-template-quality.sh <template-file>          # single file, human output
#   psk-template-quality.sh <template-file> --json   # JSON output
#   psk-template-quality.sh --all                    # audit every template
#   psk-template-quality.sh --all --strict           # exit 1 on any failure (gate mode)
#   psk-template-quality.sh --audit-log              # show audit log
#
# Exit codes:
#   0  all criteria pass (or --all without --strict)
#   1  one or more criteria fail (with --strict, or single-file mode)
#   2  usage error

set -eo pipefail   # -e: exit on error; -o pipefail: catch failures through pipes too

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TEMPLATES_DIR="$PROJ_ROOT/.portable-spec-kit/templates"
AUDIT_LOG="$TEMPLATES_DIR/.audit-log.yaml"
TODAY="$(date +%Y-%m-%d)"

# Stack-specific terms that should not appear in normative sections.
# Detection is keyword-based; stack examples in `### Examples (stack: <name>)` blocks are OK.
STACK_TERMS='\bNext\.js\b|\bFastAPI\b|\bDjango\b|\bExpress\b|\bFlask\b|\bRails\b|\bDrizzle\b|\bPrisma\b|\bPostgres\b|\bMySQL\b|\bMongoDB\b|\bReact\b|\bVue\b|\bAngular\b|\bSvelte\b|\bTailwind\b|\bshadcn\b'

# Domain-specific terms (project-specific vocabulary) that should not appear outside example blocks.
DOMAIN_TERMS='\bcv-builder\b|\bnews-validation\b|\be-commerce\b|\bsocial-media\b|\bfintech\b'

# Required audit header pattern
AUDIT_HEADER_PATTERN='<!-- TEMPLATE-KIND:.*GENERICITY:.*LAST-AUDITED:'

# Required placeholder pattern for REQUIRED user-input sections
REQUIRED_PLACEHOLDER='<!-- REQUIRED'

_check_criterion_1() {
  # Stack-agnostic: stack terms only inside example blocks
  local file="$1"
  # Strip example blocks then grep for stack terms
  local normative; normative=$(awk '
    /^### Examples \(stack:/ { skip=1; next }
    /^###/ && skip { skip=0 }
    /<!-- Example/ { skip=1; next }
    /-->/ && skip { skip=0; next }
    !skip { print }
  ' "$file")
  if echo "$normative" | grep -qE "$STACK_TERMS"; then
    return 1
  fi
  return 0
}

_check_criterion_2() {
  # Domain-agnostic: domain terms only inside example blocks
  local file="$1"
  local normative; normative=$(awk '
    /<!-- Example/ { skip=1; next }
    /-->/ && skip { skip=0; next }
    !skip { print }
  ' "$file")
  if echo "$normative" | grep -qE "$DOMAIN_TERMS"; then
    return 1
  fi
  return 0
}

_check_criterion_3() {
  # Scale-agnostic: tables don't hardcode fixed row counts in instructions
  local file="$1"
  if grep -qiE 'exactly [0-9]+ rows|fixed at [0-9]+ entries|always [0-9]+ items' "$file"; then
    return 1
  fi
  return 0
}

_check_criterion_4() {
  # Useful-and-complete: standard sections present (purpose, role, inputs/outputs OR sections OR usage)
  local file="$1"
  local has_purpose has_role
  has_purpose=$(grep -ciE 'Purpose:|^## Purpose|^# Purpose' "$file" || true)
  has_role=$(grep -ciE 'Role:|^## Role|^# Role|^## Overview|^## Usage' "$file" || true)
  if [ "$has_purpose" -lt 1 ] || [ "$has_role" -lt 1 ]; then
    return 1
  fi
  # Reject vacuous "fill in X" placeholders that constitute the entire body
  local body_lines content_lines
  body_lines=$(wc -l < "$file")
  content_lines=$(grep -vcE '^[[:space:]]*$|^<!--|^---$|FILL|TODO|XXX' "$file" || true)
  if [ "$body_lines" -gt 20 ] && [ "$content_lines" -lt 10 ]; then
    return 1
  fi
  return 0
}

_check_criterion_5() {
  # Lifecycle-aware: explicit state markers for stateful template classes
  local file="$1"
  local kind; kind=$(grep -oE 'TEMPLATE-KIND:[[:space:]]*[a-z-]+' "$file" | head -1 | awk '{print $2}')
  case "$kind" in
    plan|finding|task|release)
      grep -qE 'draft|approved|executing|done|abandoned|open|closed|acknowledged|rejected|\[x\]|\[ \]|\[~\]' "$file" || return 1
      ;;
    *)
      return 0  # stateless template classes
      ;;
  esac
  return 0
}

_check_criterion_6() {
  # Self-documenting: audit header present
  local file="$1"
  grep -qE "$AUDIT_HEADER_PATTERN" "$file" || return 1
  return 0
}

_check_criterion_7() {
  # Round-trippable: REQUIRED placeholders are grep-detectable; no unmarked TBD/TODO in body
  local file="$1"
  # Grep for unmarked TBD/TODO without the REQUIRED marker
  if grep -qE '\bTBD\b|\bTODO:|\bXXX\b' "$file" 2>/dev/null; then
    # Allow if wrapped in REQUIRED marker
    if ! grep -qE "$REQUIRED_PLACEHOLDER" "$file"; then
      return 1
    fi
  fi
  return 0
}

audit_template() {
  local file="$1" emit_json="${2:-no}"
  [ ! -f "$file" ] && { echo "file not found: $file" >&2; return 2; }
  local kind passed=() failed=()
  kind=$(grep -oE 'TEMPLATE-KIND:[[:space:]]*[a-z-]+' "$file" | head -1 | awk '{print $2}')
  [ -z "$kind" ] && kind="(unset)"

  for i in 1 2 3 4 5 6 7; do
    if _check_criterion_$i "$file"; then
      passed+=("$i")
    else
      failed+=("$i")
    fi
  done

  if [ "$emit_json" = "json" ]; then
    local p_csv f_csv
    p_csv=$(IFS=,; echo "${passed[*]}")
    f_csv=$(IFS=,; echo "${failed[*]}")
    printf '{"file":"%s","kind":"%s","criteria_passed":[%s],"criteria_failed":[%s],"audit_date":"%s"}\n' \
      "$file" "$kind" "$p_csv" "$f_csv" "$TODAY"
  else
    local mark="✓"
    [ ${#failed[@]} -gt 0 ] && mark="✗"
    printf '%s %s [kind=%s passed=%d/7 failed=%s]\n' \
      "$mark" "${file#$PROJ_ROOT/}" "$kind" "${#passed[@]}" \
      "$([ ${#failed[@]} -gt 0 ] && echo "${failed[*]}" || echo "-")"
  fi

  [ ${#failed[@]} -gt 0 ] && return 1
  return 0
}

audit_all() {
  local strict="${1:-no}"
  [ ! -d "$TEMPLATES_DIR" ] && { echo "$TEMPLATES_DIR does not exist — run inventory first" >&2; return 2; }
  local total=0 failed_count=0
  for f in "$TEMPLATES_DIR"/*.md "$TEMPLATES_DIR"/*.sh "$TEMPLATES_DIR"/*.html; do
    [ -f "$f" ] || continue
    [[ "$f" == *".audit-log.yaml" ]] && continue
    total=$((total + 1))
    if ! audit_template "$f"; then
      failed_count=$((failed_count + 1))
    fi
  done
  echo "---"
  echo "audit summary: $total template(s), $failed_count failure(s)"
  if [ "$strict" = "strict" ] && [ "$failed_count" -gt 0 ]; then
    return 1
  fi
  return 0
}

show_audit_log() {
  [ ! -f "$AUDIT_LOG" ] && { echo "no audit log yet"; return 0; }
  cat "$AUDIT_LOG"
}

case "${1:-}" in
  --all)
    if [ "${2:-}" = "--strict" ]; then
      audit_all strict
    else
      audit_all
    fi
    ;;
  --audit-log)
    show_audit_log
    ;;
  --json)
    [ -z "${2:-}" ] && { echo "usage: psk-template-quality.sh --json <file>" >&2; exit 2; }
    audit_template "$2" json
    ;;
  -h|--help|"")
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    if [ -f "$1" ]; then
      if [ "${2:-}" = "--json" ]; then
        audit_template "$1" json
      else
        audit_template "$1"
      fi
    else
      echo "unknown argument or file not found: $1" >&2
      exit 2
    fi
    ;;
esac
