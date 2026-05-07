#!/usr/bin/env bash
# F22 — Version format: v{release}.{patch}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F22 — Version format"

if kit_grep "Version Format" -qi; then
  pass "F22: §Version Format present"
else
  fail "F22: §Version Format missing"
fi

if kit_grep "v0\." -q; then
  pass "F22: v0.x version pattern present"
else
  fail "F22: v0.x pattern missing"
fi

if kit_grep "Release group" -qi || kit_grep "release group" -qi; then
  pass "F22: release-group concept documented"
else
  fail "F22: release-group concept missing"
fi

assert_kit_root_file "CHANGELOG.md" "F22: CHANGELOG.md"

# RELEASES.md may live at kit root OR agent/RELEASES.md depending on layout
if [ -f "$PROJ/RELEASES.md" ] || [ -f "$PROJ/agent/RELEASES.md" ]; then
  pass "F22: RELEASES.md present (root or agent/)"
else
  fail "F22: RELEASES.md missing"
fi
