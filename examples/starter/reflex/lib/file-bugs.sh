#!/bin/bash
# reflex/lib/file-bugs.sh
#
# Parses qa-result.md (YAML-ish "## Findings" list) and appends findings to
# agent/TASKS.md under a version-stamped "QA Findings" subsection.
#
# Idempotent: skips findings whose ID already appears in TASKS.md (so running
# the same cycle twice doesn't double-file).
#
# Respects the [~] acknowledged-non-fix marker: if a prior cycle's finding was
# marked [~] by a human, we don't re-file it even if the current QA run
# surfaces it again.

set -uo pipefail

PROJ_ROOT="${REFLEX_PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RESULT_FILE="$PROJ_ROOT/agent/.release-state/qa-result.md"
TASKS_FILE="$PROJ_ROOT/agent/TASKS.md"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

[ -f "$RESULT_FILE" ] || { echo "No qa-result.md — nothing to file"; exit 0; }
[ -f "$TASKS_FILE" ]  || { echo "No agent/TASKS.md in project — skipping bug-file step"; exit 0; }

# Current version from AGENT_CONTEXT.md
CTX="$PROJ_ROOT/agent/AGENT_CONTEXT.md"
cur_ver=$(grep -E '^\- \*\*Version:\*\*' "$CTX" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
cur_ver="${cur_ver:-v?.?.?}"

date_stamp=$(date -u +%Y-%m-%d)

# Build a list of existing IDs (filed before, or acknowledged [~])
existing_ids=$(grep -oE 'QA-[A-Z0-9]+-[0-9]+(-[A-Z0-9]+)?' "$TASKS_FILE" 2>/dev/null | sort -u | tr '\n' '|' | sed 's/|$//')

# Parse qa-result.md in a single awk pass. Emit one TASKS.md-ready entry per
# finding, separated by a form-feed (\f) so bash can split cleanly.
entries=$(awk -v existing="$existing_ids" '
  function reset() {
    id = ""; severity = ""; assignee = ""; title = ""; spec = ""; accept = ""; evidence = ""
  }
  function emit() {
    if (id == "") return
    # Skip if already filed
    n = split(existing, ids, "|")
    for (i = 1; i <= n; i++) {
      if (ids[i] == id) { reset(); return }
    }
    sev = (severity != "") ? severity : "MINOR"
    asg = (assignee != "") ? assignee : "reflex-dev"
    ref = (spec != "") ? spec : "n/a"
    acc = (accept != "") ? " — \"" accept "\"" : ""
    ev  = (evidence != "") ? evidence : "n/a"
    printf "- [ ] **%s** @%s: %s.\n      Ref: %s%s. Severity: %s.\n      Evidence: %s\n", id, asg, title, ref, acc, sev, ev
    printf "\f"
    reset()
  }
  BEGIN { in_findings = 0; reset() }
  /^## Findings/ { in_findings = 1; next }
  /^## / && in_findings { emit(); in_findings = 0; next }
  !in_findings { next }
  /^- id:/ { emit(); sub(/^- id:[[:space:]]*/, ""); id = $0; gsub(/[[:space:]]+$/, "", id); next }
  /^[[:space:]]+severity:/ { sub(/^[[:space:]]+severity:[[:space:]]*/, ""); severity = $0; gsub(/[[:space:]"]+$/, "", severity); next }
  /^[[:space:]]+assignee:/ { sub(/^[[:space:]]+assignee:[[:space:]]*/, ""); assignee = $0; gsub(/[[:space:]"]+$/, "", assignee); next }
  /^[[:space:]]+title:/    { sub(/^[[:space:]]+title:[[:space:]]*/,    ""); title = $0;    gsub(/[[:space:]"]+$/, "", title);    next }
  /^[[:space:]]+spec_ref:/ { sub(/^[[:space:]]+spec_ref:[[:space:]]*/, ""); spec = $0;     gsub(/[[:space:]"]+$/, "", spec);     next }
  /^[[:space:]]+acceptance_ref:/ { sub(/^[[:space:]]+acceptance_ref:[[:space:]]*/, ""); accept = $0; gsub(/^"|"[[:space:]]*$/, "", accept); next }
  /^[[:space:]]+evidence:/ { sub(/^[[:space:]]+evidence:[[:space:]]*/, ""); evidence = $0; gsub(/[[:space:]"]+$/, "", evidence); next }
  END { emit() }
' "$RESULT_FILE")

if [ -z "$entries" ]; then
  echo -e "${GREEN}✓ no new findings to file${NC} (qa-result empty or all already-tracked)"
  exit 0
fi

# Count entries (form-feed separated)
new_count=$(printf '%s' "$entries" | awk 'BEGIN{RS="\f"} NF {c++} END {print c+0}')
[ "$new_count" -eq 0 ] && { echo -e "${GREEN}✓ no new findings to file${NC}"; exit 0; }

# Build the combined block (form-feeds → blank lines)
entries_block=$(printf '%s' "$entries" | awk 'BEGIN{RS="\f"} NF { print; print "" }')

# Total findings in qa-result.md (for the skip count message)
total=$(grep -c '^- id:' "$RESULT_FILE" 2>/dev/null | tr -d '\n')
total="${total:-0}"
skip_count=$((total - new_count))

# Append new entries under a new (or existing same-day) subsection
heading="### ${cur_ver} — QA Findings (reflex ${date_stamp})"

entries_file=$(mktemp)
printf '%s\n' "$entries_block" > "$entries_file"

if grep -qF "$heading" "$TASKS_FILE"; then
  # Heading already exists today — insert entries immediately after heading
  tmp=$(mktemp)
  awk -v heading="$heading" -v efile="$entries_file" '
    BEGIN {
      while ((getline line < efile) > 0) entries = entries line "\n"
      close(efile)
    }
    { print }
    $0 == heading && !done { printf "\n%s", entries; done = 1 }
  ' "$TASKS_FILE" > "$tmp" && mv "$tmp" "$TASKS_FILE"
else
  if grep -q '^## Backlog' "$TASKS_FILE"; then
    tmp=$(mktemp)
    awk -v heading="$heading" -v efile="$entries_file" '
      BEGIN {
        while ((getline line < efile) > 0) entries = entries line "\n"
        close(efile)
      }
      /^## Backlog/ && !done { printf "%s\n\n%s\n", heading, entries; done = 1 }
      { print }
    ' "$TASKS_FILE" > "$tmp" && mv "$tmp" "$TASKS_FILE"
  else
    printf '\n%s\n\n%s\n' "$heading" "$entries_block" >> "$TASKS_FILE"
  fi
fi

rm -f "$entries_file"

echo -e "${GREEN}✓ filed $new_count new QA finding(s)${NC} to TASKS.md (skipped $skip_count already-tracked)"
