#!/usr/bin/env bash
# F11 — User Profile system (global + workspace)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F11 — User Profile system"

if kit_grep "user-profile" -q; then
  pass "F11: user-profile path documented"
else
  fail "F11: user-profile path missing"
fi

if kit_grep ".portable-spec-kit/user-profile" -q; then
  pass "F11: workspace profile path documented"
else
  fail "F11: workspace profile path missing"
fi

if kit_grep "~/.portable-spec-kit" -q; then
  pass "F11: global profile path documented"
else
  fail "F11: global profile path missing"
fi

if kit_grep "Profile Lookup Order" -qi; then
  pass "F11: profile lookup order documented"
else
  fail "F11: profile lookup order missing"
fi
