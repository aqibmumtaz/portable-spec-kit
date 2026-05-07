#!/usr/bin/env bash
# tests/shared/mandate-audit.sh — helpers for mandate-audit tests against
# synthetic projects.
#
# Phase T4.6 (Loop 4) — extracted from sections/05-mandate-compliance.sh
# (the Loop 2 Phase F probe that audits a target against framework mandates).
#
# Sourced by features that exercise the 8th mechanical gate (mandate-compliance):
#   features/f50-agent-self-compliance.sh
#   features/f70-reflex-avacr.sh
#
# Builds throwaway "synthetic project" trees under $TEMP for the audit
# script to scan. All helpers idempotent and self-cleaning.

[ -n "${SHARED_MANDATE_AUDIT_LOADED:-}" ] && return 0
SHARED_MANDATE_AUDIT_LOADED=1

# make_synth_project <name> [missing-mandate ...]
# Creates a synthetic project under $TEMP/synth/<name> with the standard
# mandate set (agent/, README, .gitignore, agent/SPECS.md, etc.) BUT omits
# any directories/files passed as additional args. Returns path on stdout.
#
# Example:
#   p=$(make_synth_project basic)              # all mandates present
#   p=$(make_synth_project gap-design design)   # missing agent/design/
make_synth_project() {
  local name="$1"; shift
  local root="$TEMP/synth/$name"
  rm -rf "$root"
  mkdir -p "$root/agent/design" "$root/agent/scripts" "$root/.portable-spec-kit/skills"
  : > "$root/README.md"
  : > "$root/.gitignore"
  : > "$root/agent/AGENT.md"
  : > "$root/agent/AGENT_CONTEXT.md"
  : > "$root/agent/SPECS.md"
  : > "$root/agent/PLANS.md"
  : > "$root/agent/TASKS.md"
  : > "$root/agent/RELEASES.md"
  : > "$root/.env.example"

  # Remove user-specified gaps
  for missing in "$@"; do
    case "$missing" in
      design)        rm -rf "$root/agent/design" ;;
      scripts)       rm -rf "$root/agent/scripts" ;;
      readme)        rm -f  "$root/README.md" ;;
      gitignore)     rm -f  "$root/.gitignore" ;;
      env-example)   rm -f  "$root/.env.example" ;;
      specs)         rm -f  "$root/agent/SPECS.md" ;;
      plans)         rm -f  "$root/agent/PLANS.md" ;;
      tasks)         rm -f  "$root/agent/TASKS.md" ;;
      releases)      rm -f  "$root/agent/RELEASES.md" ;;
      agent-md)      rm -f  "$root/agent/AGENT.md" ;;
      *)             ;; # unknown — ignore so callers can express future gaps
    esac
  done

  echo "$root"
}

# run_mandate_audit <project-root>
# Runs the mandate-audit helper against <project-root> and echoes its raw
# JSON output (or a non-zero string + exit if the audit script is missing).
run_mandate_audit() {
  local target="$1"
  local audit="$PROJ/reflex/lib/mandate-audit.sh"
  if [ ! -x "$audit" ]; then
    echo '{"error":"mandate-audit.sh missing"}'
    return 1
  fi
  bash "$audit" "$target" 2>/dev/null
}

# assert_mandate_audit_finds_gap <project-root> <mandate-id>
# Runs mandate audit and asserts the returned JSON contains <mandate-id>
# in a finding. Lightweight grep — does not parse JSON properly.
assert_mandate_audit_finds_gap() {
  local target="$1"
  local mandate_id="$2"
  local out
  out=$(run_mandate_audit "$target")
  if [[ "$out" == *"$mandate_id"* ]]; then
    pass "mandate-audit detects gap: $mandate_id"
  else
    fail "mandate-audit missed gap: $mandate_id (output: $(echo "$out" | head -c 80))"
  fi
}

# assert_mandate_audit_clean <project-root>
# Asserts the audit returns no MAJOR severity findings against a fully-
# populated synthetic project.
assert_mandate_audit_clean() {
  local target="$1"
  local out
  out=$(run_mandate_audit "$target")
  if [[ "$out" != *'"severity":"MAJOR"'* ]] && [[ "$out" != *"severity: MAJOR"* ]]; then
    pass "mandate-audit clean (no MAJOR findings) on $(basename "$target")"
  else
    fail "mandate-audit unexpectedly found MAJOR findings on $(basename "$target")"
  fi
}
