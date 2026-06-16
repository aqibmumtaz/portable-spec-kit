#!/usr/bin/env bash
# F1 — Framework file (portable-spec-kit.md)
#
# Per-feature test file (Loop 4 Approach 3). Selective audit of F1 behavior.
# Independently runnable: bash tests/features/f01-framework-file.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F1 — Framework file (portable-spec-kit.md)"

assert_kit_root_file "portable-spec-kit.md" "F1: framework file"
assert_kit_root_file ".gitignore" "F1: .gitignore"

# Agent-entry-point symlink contract (QA-D20-P6-001).
# On Mac/Linux the installer points CLAUDE.md → portable-spec-kit.md via symlink;
# on Windows (or any FS without symlink support) it is installed as a copy. The
# contract is: CLAUDE.md MUST exist and MUST resolve to portable-spec-kit.md's
# content — whether it is a symlink (preferred) or a content-identical copy. A
# stale copy that has drifted from the framework file is the failure this guards.
if [ -e "$PROJ/CLAUDE.md" ] || [ -L "$PROJ/CLAUDE.md" ]; then
  pass "F1: CLAUDE.md agent-entry-point present"
  if [ -L "$PROJ/CLAUDE.md" ]; then
    # Symlink install (Mac/Linux): target must resolve to portable-spec-kit.md.
    link_target="$(readlink "$PROJ/CLAUDE.md")"
    case "$link_target" in
      *portable-spec-kit.md)
        pass "F1: CLAUDE.md symlink resolves to portable-spec-kit.md"
        ;;
      *)
        fail "F1: CLAUDE.md symlink points to '$link_target', expected portable-spec-kit.md"
        ;;
    esac
    if [ -r "$PROJ/CLAUDE.md" ]; then
      pass "F1: CLAUDE.md symlink target is readable"
    else
      fail "F1: CLAUDE.md symlink target is broken (unreadable)"
    fi
  else
    # Copy install (Windows / no-symlink FS): content must match the framework file.
    if diff -q "$PROJ/CLAUDE.md" "$PROJ/portable-spec-kit.md" >/dev/null 2>&1; then
      pass "F1: CLAUDE.md copy is content-identical to portable-spec-kit.md (no drift)"
    else
      fail "F1: CLAUDE.md copy has drifted from portable-spec-kit.md — stale install"
    fi
  fi
else
  fail "F1: CLAUDE.md agent-entry-point MISSING (installer must symlink or copy it)"
fi

# Framework file must contain core anchor sections
if grep -q "Portable Spec Kit" "$PROJ/portable-spec-kit.md"; then
  pass "F1: portable-spec-kit.md has product header"
else
  fail "F1: portable-spec-kit.md missing product header"
fi

if grep -q "Framework Version" "$PROJ/portable-spec-kit.md" 2>/dev/null || \
   grep -q "^**Version:**" "$PROJ/portable-spec-kit.md" 2>/dev/null || \
   grep -qE "Version.*v[0-9]" "$PROJ/portable-spec-kit.md"; then
  pass "F1: framework declares a version"
else
  fail "F1: framework version marker missing"
fi

if kit_grep "Reflex Finding Classification" -q; then
  pass "F1: §Reflex Finding Classification present"
else
  fail "F1: §Reflex Finding Classification missing"
fi

if kit_grep "Bootstrap-first" -q; then
  pass "F1: §Bootstrap-first rule present"
else
  fail "F1: §Bootstrap-first rule missing"
fi

if kit_grep "Skill-Based Architecture" -q; then
  pass "F1: §Skill-Based Architecture present"
else
  fail "F1: §Skill-Based Architecture missing"
fi

# Framework file is non-trivial (>100 lines)
if [ $(wc -l < "$PROJ/portable-spec-kit.md") -gt 100 ]; then
  pass "F1: framework file > 100 lines"
else
  fail "F1: framework file too short"
fi
