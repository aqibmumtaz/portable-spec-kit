#!/usr/bin/env bash
# F18 — 10 core strengths in feature table
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F18 — 10 core strengths"

# README typically presents strengths
if grep -qiE "(strength|feature|capabilit)" "$PROJ/README.md"; then
  pass "F18: README presents strengths/features"
else
  fail "F18: README missing strengths section"
fi

# Several known kit strength keywords
for kw in "Spec-Persistent" "Persistent Memory" "Reflex" "Skill"; do
  if kit_grep "$kw" -q; then
    pass "F18: kit declares strength: $kw"
  else
    fail "F18: strength missing: $kw"
  fi
done
