#!/usr/bin/env bash
# F8 — Open source README + CONTRIBUTING + LICENSE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F8 — Open source README + CONTRIBUTING + LICENSE"

assert_kit_root_file "README.md" "F8: README.md"
assert_kit_root_file "CONTRIBUTING.md" "F8: CONTRIBUTING.md"
assert_kit_root_file "LICENSE" "F8: LICENSE"

if grep -qi "MIT" "$PROJ/LICENSE"; then
  pass "F8: LICENSE is MIT"
else
  fail "F8: LICENSE not MIT"
fi

if [ $(wc -l < "$PROJ/CONTRIBUTING.md") -gt 10 ]; then
  pass "F8: CONTRIBUTING.md non-trivial"
else
  fail "F8: CONTRIBUTING.md too short"
fi
