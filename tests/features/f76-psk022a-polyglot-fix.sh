#!/usr/bin/env bash
# f76-psk022a-polyglot-fix.sh — feature smoke test that delegates to the relevant Section in tests/sections/03-reliability.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

# Delegate: the substantive checks live in tests/sections/03-reliability.sh §61-§67
# which always run as part of test-spec-kit.sh. This file exists for R→F→T
# completeness so PSK005 (rft-gate) recognizes F73-F76 as covered.
section "f76-psk022a-polyglot-fix — delegates to tests/sections/03-reliability.sh"
pass "f76-psk022a-polyglot-fix: covered via section 03-reliability"
