#!/usr/bin/env bash
# F37 — GitHub topics/tags
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F37 — GitHub topics"

# README typically lists topics
if grep -qiE "(topic|tag)" "$PROJ/README.md"; then
  pass "F37: README references topics/tags"
else
  fail "F37: README missing topics"
fi

if grep -qE "github.com/aqibmumtaz/portable-spec-kit" "$PROJ/README.md" 2>/dev/null || \
   kit_grep "github.com/aqibmumtaz" -q; then
  pass "F37: GitHub repo URL documented"
else
  fail "F37: GitHub URL missing"
fi
