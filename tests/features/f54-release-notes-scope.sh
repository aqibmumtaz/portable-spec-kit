#!/usr/bin/env bash
# F54 — Release notes scope rule
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F54 — Release notes scope"

if kit_grep "release notes" -qi; then
  pass "F54: release-notes guidance documented"
else
  fail "F54: release-notes guidance missing"
fi

if kit_grep "public repo" -qi || kit_grep "publicly visible" -qi || kit_grep "private docs" -qi; then
  pass "F54: public-vs-private rule documented"
else
  fail "F54: public-vs-private rule missing"
fi

if [ -f "$PROJ/CHANGELOG.md" ]; then
  pass "F54: CHANGELOG.md present"
else
  fail "F54: CHANGELOG.md missing"
fi
