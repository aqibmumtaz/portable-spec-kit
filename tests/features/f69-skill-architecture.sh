#!/usr/bin/env bash
# F69 — Skill-Based Architecture
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F69 — Skill-Based Architecture"

if [ -d "$PROJ/.portable-spec-kit/skills" ]; then
  pass "F69: .portable-spec-kit/skills/ dir present"
else
  fail "F69: skills/ dir missing"
fi

skill_count=$(ls "$PROJ/.portable-spec-kit/skills/"*.md 2>/dev/null | wc -l)
if [ "$skill_count" -ge 6 ]; then
  pass "F69: $skill_count skill files (>=6)"
else
  fail "F69: too few skill files ($skill_count)"
fi

if kit_grep "Skill-Based Architecture" -q; then
  pass "F69: §Skill-Based Architecture documented"
else
  fail "F69: §Skill-Based Architecture missing"
fi

if kit_grep "lazy load" -qi || kit_grep "loaded on demand" -qi || kit_grep "skill files loaded" -qi; then
  pass "F69: lazy-loading principle documented"
else
  fail "F69: lazy-loading missing"
fi
