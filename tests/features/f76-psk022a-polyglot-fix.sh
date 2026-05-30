#!/usr/bin/env bash
# f76-psk022a-polyglot-fix.sh — Adversarial assertions for F76 (PSK022a word-boundary fix).
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F73-F82-CLASS instance).
#
# The fix: PSK022a `check_template_choice` regex matched "Gin" inside
# "messaGINg" / "enGINe" / "loGINg" without word-boundary anchors. The
# resolution mandated `\b(Keyword)\b` everywhere, plus exclusion of
# library-only names from runtime detection.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f76-psk022a-polyglot-fix — word-boundary anchors in check_template_choice"

SYNC="$PROJ/agent/scripts/psk-sync-check.sh"

# AC1 — psk-sync-check.sh defines check_template_choice (PSK022a function)
if grep -qE '^check_template_choice\(\)' "$SYNC"; then
  pass "f76 AC1: check_template_choice() defined in psk-sync-check.sh"
else
  fail "f76 AC1: check_template_choice() not found"
fi

# AC2 — word-boundary anchors present in the function body (\b ... \b in grep -E pattern)
if grep -A100 '^check_template_choice()' "$SYNC" | head -200 | grep -qE '\\b'; then
  pass "f76 AC2: word-boundary anchors (\\b) present in check_template_choice"
else
  fail "f76 AC2: no word-boundary anchors in check_template_choice"
fi

# AC3 — library names excluded from runtime detection (Drizzle / Twilio / Upstash / NextAuth
# should NOT be treated as runtime languages by the polyglot detector)
if grep -A200 '^check_template_choice()' "$SYNC" | head -200 | grep -qE 'Drizzle|Twilio|Upstash|NextAuth'; then
  pass "f76 AC3: library-name exclusions referenced in check_template_choice"
else
  fail "f76 AC3: library-name exclusions missing from check_template_choice"
fi

# AC4 — PSK022a error code defined
if grep -qE 'PSK022a' "$SYNC"; then
  pass "f76 AC4: PSK022a error code wired in psk-sync-check.sh"
else
  fail "f76 AC4: PSK022a error code not found"
fi

# AC5 — PSK022a definition references "no app-shape" / kit-library / docs path
# (source-level check; avoid running full sync-check to keep test fast)
if grep -qE 'no app-shape|kit/library|docs project' "$SYNC"; then
  pass "f76 AC5: PSK022a non-app-shape skip-path branch present"
else
  fail "f76 AC5: PSK022a non-app-shape skip-path not found"
fi
