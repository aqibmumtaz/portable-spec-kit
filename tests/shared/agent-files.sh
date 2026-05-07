#!/usr/bin/env bash
# tests/shared/agent-files.sh — assertion helpers for agent/* pipeline files.
#
# Phase T4.2 (Loop 4) — extracted from sections/01-infrastructure.sh §5
# (Agent File Templates) and sections/02-pipeline.sh §27-§50.
#
# Sourced by features that assert kit's agent/ pipeline-file presence /
# template content / template references in framework rules:
#   features/f03-agent-templates.sh           (6 core templates)
#   features/f50-agent-self-compliance.sh     (kit's own agent/ files)
#   features/f64-feature-design-pipeline.sh   (agent/design/)
#   features/f67-requirements-pipeline.sh     (agent/REQS.md)
#   features/f68-research-pipeline.sh         (agent/RESEARCH.md, DESIGN.md)
#
# Idempotent — safe to source multiple times.

[ -n "${SHARED_AGENT_FILES_LOADED:-}" ] && return 0
SHARED_AGENT_FILES_LOADED=1

# Canonical pipeline file list (6 management markdowns at agent/ root).
# Order matches the pipeline narrative: REQS → SPECS → PLANS → TASKS → RELEASES,
# plus AGENT_CONTEXT (running state). AGENT.md (project rules) listed separately
# below since some legacy projects predate it.
AGENT_PIPELINE_FILES=(
  "REQS.md"
  "SPECS.md"
  "PLANS.md"
  "TASKS.md"
  "RELEASES.md"
  "AGENT_CONTEXT.md"
)

AGENT_SUPPORT_FILES=(
  "AGENT.md"
  "RESEARCH.md"
  "DESIGN.md"
)

# assert_agent_file <name> [description]
# Asserts $PROJ/agent/<name> exists.
assert_agent_file() {
  local name="$1"
  local desc="${2:-agent/$name}"
  if [ -f "$PROJ/agent/$name" ]; then
    pass "$desc exists"
  else
    fail "$desc MISSING"
  fi
}

# assert_agent_dir <name> [description]
# Asserts $PROJ/agent/<name>/ exists as a directory.
assert_agent_dir() {
  local name="$1"
  local desc="${2:-agent/$name/}"
  if [ -d "$PROJ/agent/$name" ]; then
    pass "$desc dir exists"
  else
    fail "$desc dir MISSING"
  fi
}

# assert_template_referenced <template-name>
# Asserts the framework file (or any skill) mentions <template-name>.
# Use to verify all 6 core templates documented in framework.
assert_template_referenced() {
  local name="$1"
  if kit_grep "$name" -q; then
    pass "framework references $name template"
  else
    fail "framework missing reference to $name template"
  fi
}

# assert_design_dir_template_present
# Asserts the framework documents the agent/design/ per-feature plan dir
# and the f{N}-feature-name.md naming convention.
assert_design_dir_template_present() {
  if kit_grep "agent/design/" -q && kit_grep "f{N}" -q; then
    pass "framework documents agent/design/f{N}-* template"
  else
    fail "framework missing agent/design/f{N}-* template documentation"
  fi
}

# assert_pipeline_file_in_framework <filename>
# Asserts the framework references a pipeline file by name (e.g. SPECS.md).
assert_pipeline_file_in_framework() {
  local fn="$1"
  if kit_grep "$fn" -q; then
    pass "framework references $fn"
  else
    fail "framework missing reference to $fn"
  fi
}
