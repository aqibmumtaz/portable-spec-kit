#!/usr/bin/env bash
# F71 — Framework internal consistency: stub paths, source-structures, project-setup alignment
# Validates that test stub paths in portable-spec-kit.md point to tests/features/,
# that source-structures.md includes subdir layout, and project-setup.md mkdir includes subdirs.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F71 — Framework consistency: stub paths + source-structures + project-setup"

FRAMEWORK="$PROJ/portable-spec-kit.md"
SOURCE_STRUCTURES="$PROJ/.portable-spec-kit/skills/source-structures.md"
PROJECT_SETUP="$PROJ/.portable-spec-kit/skills/project-setup.md"

# --- F71.1: No bare tests/f{n} stub paths in framework (all must use tests/features/) ---
if grep -n 'tests/f{n}\|tests/f{N}\|tests/test_f{n}\|tests/test-f{n}' "$FRAMEWORK" 2>/dev/null \
   | grep -v 'tests/features/' | grep -q .; then
  fail "F71.1: portable-spec-kit.md has stub paths missing tests/features/ prefix"
  grep -n 'tests/f{n}\|tests/f{N}\|tests/test_f{n}\|tests/test-f{n}' "$FRAMEWORK" | grep -v 'tests/features/' | head -5
else
  pass "F71.1: all stub paths in portable-spec-kit.md use tests/features/ prefix"
fi

# --- F71.2: source-structures.md documents features/ subdir under tests/ ---
# Tree format uses separate lines — look for features/ comment mentioning per-feature tests
if grep -q 'Per-feature tests\|per-feature tests\|f{n}-.*.test\|f1-.*test' "$SOURCE_STRUCTURES" 2>/dev/null; then
  pass "F71.2: source-structures.md documents features/ subdir (per-feature tests)"
else
  fail "F71.2: source-structures.md missing features/ subdir documentation for per-feature tests"
fi

# --- F71.3: project-setup.md mkdir line includes tests/features subdir ---
if grep -q 'tests/features\|tests/{features' "$PROJECT_SETUP" 2>/dev/null; then
  pass "F71.3: project-setup.md mkdir includes tests/features/ subdir"
else
  fail "F71.3: project-setup.md mkdir does not include tests/features/ subdir"
fi

# --- F71.4: kit itself has tests/features/ directory ---
if [ -d "$PROJ/tests/features" ]; then
  pass "F71.4: kit has tests/features/ directory"
else
  fail "F71.4: kit missing tests/features/ directory"
fi

# --- F71.5: kit has tests/e2e/ directory ---
if [ -d "$PROJ/tests/e2e" ]; then
  pass "F71.5: kit has tests/e2e/ directory"
else
  fail "F71.5: kit missing tests/e2e/ directory"
fi

# --- F71.6: kit has .portable-spec-kit/config.md ---
if [ -f "$PROJ/.portable-spec-kit/config.md" ]; then
  pass "F71.6: kit has .portable-spec-kit/config.md"
else
  fail "F71.6: kit missing .portable-spec-kit/config.md"
fi
