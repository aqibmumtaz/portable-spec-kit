#!/usr/bin/env bash
# F6 — Example projects (starter + my-app)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F6 — Example projects (starter + my-app)"

assert_kit_root_dir "examples/starter" "F6: examples/starter"
assert_kit_root_dir "examples/my-app" "F6: examples/my-app"
assert_kit_root_dir "examples/starter/agent" "F6: starter agent/"
assert_kit_root_dir "examples/my-app/agent" "F6: my-app agent/"

for ex in starter my-app; do
  if [ -f "$PROJ/examples/$ex/README.md" ]; then
    pass "F6: $ex has README.md"
  else
    fail "F6: $ex README.md missing"
  fi
  if [ -f "$PROJ/examples/$ex/portable-spec-kit.md" ] || [ -L "$PROJ/examples/$ex/portable-spec-kit.md" ]; then
    pass "F6: $ex has portable-spec-kit.md"
  else
    fail "F6: $ex portable-spec-kit.md missing"
  fi
done
