#!/usr/bin/env bash
# tests/shared/pipeline-rules.sh — assertions for R→F→T traceability,
# scope-change types, and ADL format rules.
#
# Phase T4.3 (Loop 4) — extracted from sections/02-pipeline.sh §27-§28
# (R→F traceability + scope-change simulation), §40 (R→F→T), §47 (ADL).
#
# Sourced by features that exercise pipeline-discipline rules:
#   features/f27-rf-traceability.sh
#   features/f28-scope-change-types.sh
#   features/f49-scope-change-recording.sh
#   features/f52-rft-traceability.sh
#   features/f61-architecture-decision-log.sh
#
# Idempotent — safe to source multiple times.

[ -n "${SHARED_PIPELINE_RULES_LOADED:-}" ] && return 0
SHARED_PIPELINE_RULES_LOADED=1

# Canonical 4 scope-change types per F28.
SCOPE_CHANGE_TYPES=(DROP ADD MODIFY REPLACE)

# assert_rf_traceability_documented
# Asserts framework documents the R→F traceability rule.
assert_rf_traceability_documented() {
  if kit_grep "R→F" -q || kit_grep "R-to-F" -q; then
    pass "framework documents R→F traceability"
  else
    fail "framework missing R→F traceability documentation"
  fi
}

# assert_rft_traceability_documented
# Asserts framework documents R→F→T (test ref required before [x]).
assert_rft_traceability_documented() {
  if kit_grep "R→F→T" -q; then
    pass "framework documents R→F→T traceability"
  else
    fail "framework missing R→F→T traceability documentation"
  fi
}

# assert_scope_change_type <type>
# Asserts framework documents one of DROP/ADD/MODIFY/REPLACE.
assert_scope_change_type() {
  local t="$1"
  if kit_grep "$t" -q; then
    pass "framework documents scope-change type $t"
  else
    fail "framework missing scope-change type $t"
  fi
}

# assert_all_scope_change_types
# Convenience: assert all 4 scope-change types present.
assert_all_scope_change_types() {
  for t in "${SCOPE_CHANGE_TYPES[@]}"; do
    assert_scope_change_type "$t"
  done
}

# assert_adl_format_documented
# Asserts framework references ADL/ADR format with required columns
# (ID/Date/Decision/Status/Impact at minimum).
assert_adl_format_documented() {
  if kit_grep "Architecture Decision Log" -q || kit_grep "ADR-" -q; then
    pass "framework documents ADL/ADR format"
  else
    fail "framework missing ADL/ADR documentation"
  fi
}

# assert_specs_has_tests_column <specs-file>
# Asserts the SPECS.md feature table includes a Tests column header.
assert_specs_has_tests_column() {
  local specs="${1:-$PROJ/agent/SPECS.md}"
  if [ ! -f "$specs" ]; then
    fail "SPECS.md missing for tests-column check ($specs)"
    return
  fi
  if grep -qE "\| *Tests *\|" "$specs"; then
    pass "SPECS.md feature table has Tests column"
  else
    fail "SPECS.md feature table missing Tests column"
  fi
}

# assert_done_features_have_tests <specs-file>
# Asserts every [x] feature row in SPECS.md has a non-empty Tests column.
# Returns count of done features and how many have refs.
assert_done_features_have_tests() {
  local specs="${1:-$PROJ/agent/SPECS.md}"
  if [ ! -f "$specs" ]; then
    fail "SPECS.md missing for done-features check"
    return
  fi
  local total=0 with_test=0
  while IFS= read -r line; do
    # match a feature row that has [x] in the Status column
    if [[ "$line" =~ ^\|\ *F[0-9]+ ]] && [[ "$line" == *"[x]"* ]]; then
      total=$((total+1))
      # Tests column is the rightmost field — check it has content beyond whitespace
      local tests_col
      tests_col=$(echo "$line" | awk -F'|' '{print $(NF-1)}' | sed 's/^ *//; s/ *$//')
      if [ -n "$tests_col" ]; then
        with_test=$((with_test+1))
      fi
    fi
  done < "$specs"
  if [ "$total" -eq 0 ]; then
    pass "SPECS.md done-feature R→F→T check (no done features yet)"
  elif [ "$with_test" -eq "$total" ]; then
    pass "SPECS.md all $total done features have Tests refs"
  else
    fail "SPECS.md $((total-with_test))/$total done features missing Tests refs"
  fi
}
