#!/usr/bin/env bash
# F20 — Strict security rule — NEVER expose API key values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F20 — Security rule (API key values)"

if kit_grep "API Keys" -q || kit_grep "Secrets" -q; then
  pass "F20: secrets section documented"
else
  fail "F20: secrets section missing"
fi

if kit_grep "NEVER" -q; then
  pass "F20: NEVER prohibition present"
else
  fail "F20: NEVER prohibition missing"
fi

if kit_grep "NO EXCEPTIONS" -q || kit_grep "ABSOLUTE" -q; then
  pass "F20: absolute prohibition documented"
else
  fail "F20: absolute prohibition missing"
fi

if kit_grep ".env" -q; then
  pass "F20: .env files referenced"
else
  fail "F20: .env files not referenced"
fi

if kit_grep "placeholder" -q; then
  pass "F20: placeholder pattern documented"
else
  fail "F20: placeholder pattern missing"
fi
