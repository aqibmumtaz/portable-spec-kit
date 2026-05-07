#!/usr/bin/env bash
# tests/shared/reflex-fixtures.sh — common setup helpers for reflex tests.
#
# Phase T4.5 (Loop 4) — extracted from sections/04-reflex.sh sub-sections
# N52..N84. Reflex tests repeatedly stub up sandbox dirs, mock pass dirs,
# and synthetic .iter-status.yml / verdict.md files. This file factors
# those into reusable fixtures.
#
# Sourced by features that exercise the F70 reflex loop:
#   features/f70-reflex-avacr.sh
#
# All fixtures write under $TEMP (set by lib.sh) and clean up via the
# orchestrator's TEMP-removal pattern. Idempotent.

[ -n "${SHARED_REFLEX_FIXTURES_LOADED:-}" ] && return 0
SHARED_REFLEX_FIXTURES_LOADED=1

# make_mock_pass_dir <cycle-id> <pass-id> [verdict]
# Creates a synthetic reflex pass dir under $TEMP/reflex-history.
# Defaults verdict to GRANTED. Echoes the created path on stdout.
make_mock_pass_dir() {
  local cycle="${1:-cycle-01}"
  local pass="${2:-pass-001}"
  local verdict="${3:-GRANTED}"
  local dir="$TEMP/reflex-history/$cycle/$pass"
  mkdir -p "$dir"
  cat > "$dir/.iter-status.yml" <<YML
status: COMPLETE-${verdict}
cycle: ${cycle}
pass: ${pass}
started_at: 2026-01-01T00:00:00Z
finished_at: 2026-01-01T00:00:01Z
YML
  cat > "$dir/verdict.md" <<MD
# Verdict — ${cycle}/${pass}

**Verdict:** ${verdict}

(synthetic fixture for tests)
MD
  cat > "$dir/findings.yaml" <<YML
findings: []
YML
  cat > "$dir/.cycle-meta" <<META
cycle: ${cycle}
pass: ${pass}
mode: autoloop
started: 2026-01-01T00:00:00Z
META
  echo "$dir"
}

# make_mock_sandbox <cycle-id> <pass-id>
# Creates a synthetic QA sandbox worktree dir under $TEMP/reflex-sandbox.
# Echoes path on stdout.
make_mock_sandbox() {
  local cycle="${1:-cycle-01}"
  local pass="${2:-pass-001}"
  local dir="$TEMP/reflex-sandbox/$cycle/$pass"
  mkdir -p "$dir"
  echo "$dir"
}

# make_interrupted_pass_dir <cycle-id> <pass-id>
# Creates a pass dir with verdict.md INTERRUPTED — simulates abort.
make_interrupted_pass_dir() {
  local cycle="${1:-cycle-01}"
  local pass="${2:-pass-001}"
  local dir="$TEMP/reflex-history/$cycle/$pass"
  mkdir -p "$dir"
  cat > "$dir/verdict.md" <<MD
# Verdict — ${cycle}/${pass}

**Verdict:** INTERRUPTED

(operator did not recover this pass)
MD
  echo "$dir"
}

# assert_reflex_lib <name>
# Asserts $PROJ/reflex/lib/<name> exists.
assert_reflex_lib() {
  local name="$1"
  if [ -f "$PROJ/reflex/lib/$name" ]; then
    pass "reflex/lib/$name exists"
  else
    fail "reflex/lib/$name MISSING"
  fi
}

# assert_reflex_prompt <name>
# Asserts $PROJ/reflex/prompts/<name> exists (qa-agent.md / dev-agent.md).
assert_reflex_prompt() {
  local name="$1"
  if [ -f "$PROJ/reflex/prompts/$name" ]; then
    pass "reflex/prompts/$name exists"
  else
    fail "reflex/prompts/$name MISSING"
  fi
}

# clean_reflex_fixtures
# Convenience wipe for tests that need a clean slate mid-run.
clean_reflex_fixtures() {
  rm -rf "$TEMP/reflex-history" "$TEMP/reflex-sandbox" 2>/dev/null
}
