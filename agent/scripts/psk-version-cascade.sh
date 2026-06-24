#!/bin/bash
# mechanical-script: psk-version-cascade.sh — version cascade Phase C (no AI invocation)
# agent/scripts/psk-version-cascade.sh — Phase C of Loop 6 (kit v0.6.34).
#
# Comprehensive version-cascade sweep: when the kit version bumps, propagate
# the new version to ALL artifacts pinned to a kit version, not just the
# obvious main ones. Closes G-KIT-V0633-SWEEP-CASCADE-01 (doc 19 §15.3) where
# the v0.6.32 → v0.6.33 bump shipped without updating examples' agent/* Kit
# fields and test-spd-benchmarking.sh fixture, breaking 5 tests in
# tests/sections/02-pipeline.sh under "docs consistency".
#
# Field-anchored: only bumps the SPECIFIC fields that pin to current version.
# Historical version mentions (CHANGELOG entries, ADL rows, RELEASES history,
# example-projects own version history) are preserved untouched.
#
# Usage:
#   bash agent/scripts/psk-version-cascade.sh [--to <ver>] [--check-only]
#
# --to:           target version. Auto-detected from agent/AGENT_CONTEXT.md.
# --check-only:   report drift, do not modify files. Exit 0 = clean,
#                 exit 1 = drift detected.

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

CHECK_ONLY=0
TO_VER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check-only) CHECK_ONLY=1; shift ;;
    --to)         TO_VER="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$TO_VER" ]; then
  TO_VER=$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "$PROJ_ROOT/agent/AGENT_CONTEXT.md" 2>/dev/null | head -1)
fi

if [ -z "$TO_VER" ]; then
  echo -e "${RED}cannot determine target version (--to or AGENT_CONTEXT.md)${NC}" >&2
  exit 2
fi

echo -e "${CYAN}═══ version-cascade sweep ═══${NC}"
echo "  target: $TO_VER"

drift_found=0
files_changed=0

# Helper: BSD/GNU-portable sed -i
sed_inplace() {
  local pattern="$1" file="$2"
  [ -f "$file" ] || return 0
  sed -i.bak "$pattern" "$file" 2>/dev/null && rm -f "$file.bak"
}

# Helper: check if FILE has LINE matching PATTERN with version != TO_VER
# Returns 0 = drift exists, 1 = clean
has_field_drift() {
  local file="$1" line_pattern="$2"
  [ -f "$file" ] || return 1
  # Find lines matching the field pattern, extract version, compare
  grep -E "$line_pattern" "$file" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | grep -qv "^${TO_VER}\$"
}

# Helper: process one (file, line_pattern, description) tuple
process_field() {
  local file="$1" line_pattern="$2" description="$3"
  [ -f "$file" ] || return 0

  if ! has_field_drift "$file" "$line_pattern"; then
    return 0
  fi

  drift_found=1
  if [ "$CHECK_ONLY" = "1" ]; then
    local stale
    stale=$(grep -E "$line_pattern" "$file" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | grep -v "^${TO_VER}\$" | sort -u | tr '\n' ' ')
    echo -e "  ${YELLOW}drift: ${file#$PROJ_ROOT/} — $description (stale: $stale)${NC}"
    return 0
  fi

  # Replace v{X.Y.Z} with TO_VER on lines matching line_pattern.
  # Use perl for cross-platform line-scoped replacement (awk's regex is BSD-fragile
  # for patterns with literal asterisks; sed BRE/ERE syntax varies BSD vs GNU).
  perl -i -pe "s/v\\d+\\.\\d+\\.\\d+/${TO_VER}/g if /${line_pattern}/" "$file"
  files_changed=$((files_changed + 1))
  echo -e "  ${GREEN}✓${NC} ${file#$PROJ_ROOT/} — $description"
}

# --- 1. Kit's own current-version fields (Step 6 already handles these,
#        but include for standalone-invocation safety) ---
process_field "$PROJ_ROOT/agent/AGENT_CONTEXT.md" "^- \*\*Version:\*\*" "Version field"
# KIT-GAP-0100 (cycle-01/pass-002): the kit's OWN AGENT_CONTEXT.md **Kit:** field
# was never bumped here (only the examples' Kit field at step 2 and --target
# projects below were), so kit-self shipped a Version!=Kit drift that test-spec-kit
# caught only post-release. For the kit itself Kit == Version, so bump it too.
process_field "$PROJ_ROOT/agent/AGENT_CONTEXT.md" "^- \*\*Kit:\*\*" "Kit field"
process_field "$PROJ_ROOT/portable-spec-kit.md"   "^<!-- Framework Version:" "Framework Version comment"
process_field "$PROJ_ROOT/portable-spec-kit.md"   "^\*\*Version:\*\*" "Version header"
process_field "$PROJ_ROOT/README.md"              "version-v[0-9]" "README version badge"
# KIT-GAP (QA-P006-CONFIG-VERSION-STALE-01): .portable-spec-kit/config.md kit_version
# is written by install.sh and is a team-visible kit-managed claim, but was never bumped
# by the cascade — so it went stale between installs (sync-check check_config_kit_version
# now flags this as advisory). Refresh it here so a version bump keeps config.md current
# without a full re-install. Generic: every kit install has this config.md kit_version field.
process_field "$PROJ_ROOT/.portable-spec-kit/config.md" "kit_version" "config.md kit_version"

# --- 2. Examples' kit-pinned fields (CASCADE GAP from v0.6.33) ---
for ex in starter my-app; do
  process_field "$PROJ_ROOT/examples/$ex/agent/AGENT_CONTEXT.md" \
    "^- \*\*Kit:\*\*" "examples/$ex Kit field"
  process_field "$PROJ_ROOT/examples/$ex/agent/RELEASES.md" \
    "^Kit:" "examples/$ex RELEASES.md Kit field"
  process_field "$PROJ_ROOT/examples/$ex/portable-spec-kit.md" \
    "^<!-- Framework Version:" "examples/$ex Framework Version comment"
  process_field "$PROJ_ROOT/examples/$ex/portable-spec-kit.md" \
    "^\*\*Version:\*\*" "examples/$ex Version header"
done

# --- 3. Benchmarking fixture (CASCADE GAP from v0.6.33) ---
process_field "$PROJ_ROOT/tests/test-spd-benchmarking.sh" \
  "^Kit:" "test-spd-benchmarking.sh Kit fixture"

# --- 4. ARD HTML — only current-version anchors (Version field, badge, footer) ---
# ARD docs contain CHANGELOG-like history with many version refs; only the
# current-version anchors should be bumped. Three known patterns:
#   - <strong ...>Version:</strong> vX.Y.Z
#   - <div class="badge">vX.Y.Z &bull; ...
#   - Portable Spec Kit &bull; vX.Y.Z &bull; ...    (footer)
for f in "$PROJ_ROOT"/ard/*.html; do
  [ -f "$f" ] || continue
  # Check if any of the three anchor lines have stale version
  ard_drift=0
  for anchor in 'Version:</strong>' 'class="badge">v' 'Portable Spec Kit &bull; v'; do
    if grep -F "$anchor" "$f" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | grep -qv "^${TO_VER}\$"; then
      ard_drift=1
      break
    fi
  done

  if [ "$ard_drift" = "1" ]; then
    drift_found=1
    if [ "$CHECK_ONLY" = "1" ]; then
      echo -e "  ${YELLOW}drift: ard/$(basename "$f") — current-version anchor has stale ref${NC}"
    else
      # Use perl line-scoped: only on lines matching one of the three anchors
      perl -i -pe '
        if (/Version:<\/strong>|class="badge">v|Portable Spec Kit &bull; v/) {
          s/v\d+\.\d+\.\d+(?!\d)(?!\.)/'"${TO_VER}"'/g;
        }
      ' "$f"
      files_changed=$((files_changed + 1))
      echo -e "  ${GREEN}✓${NC} ard/$(basename "$f") — current-version anchors bumped to $TO_VER"
    fi
  fi
done

# --- 5. CHANGELOG "Built over: vX — vY" range END only ---
# Only the trailing version after em-dash is "current"; range start is historical.
if [ -f "$PROJ_ROOT/CHANGELOG.md" ]; then
  range_line=$(grep -E "Built over.*— v[0-9]+\.[0-9]+\.[0-9]+" "$PROJ_ROOT/CHANGELOG.md" 2>/dev/null | head -1)
  if [ -n "$range_line" ]; then
    range_end=$(echo "$range_line" | grep -oE '— v[0-9]+\.[0-9]+\.[0-9]+' | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -n "$range_end" ] && [ "$range_end" != "$TO_VER" ]; then
      drift_found=1
      if [ "$CHECK_ONLY" = "1" ]; then
        echo -e "  ${YELLOW}drift: CHANGELOG.md — range end $range_end (should be $TO_VER)${NC}"
      else
        sed_inplace "s/— $range_end/— $TO_VER/" "$PROJ_ROOT/CHANGELOG.md"
        files_changed=$((files_changed + 1))
        echo -e "  ${GREEN}✓${NC} CHANGELOG.md — range end bumped: $range_end → $TO_VER"
      fi
    fi
  fi
fi

# --- 6. Phase Q (Loop 7 v0.6.36) — kit machinery propagation ---
# When invoked from kit-self with --sync-projects flag (or env REFLEX_SYNC_PROJECTS=1),
# also propagate kit's reflex/lib/, reflex/run.sh, reflex/prompts/, and
# agent/scripts/psk-*.sh to specified target projects. Closes Loop 6 §16.2 —
# project's reflex/ no longer drifts out of sync with kit on version bumps.
#
# Detect kit-self via portable-spec-kit.md being a regular file (not symlink).
# Target projects passed via --target /path/to/project (repeatable) or via
# config file at .portable-spec-kit/sync-targets.txt.
#
# Skip when running on a non-kit project (would be wrong direction).
SYNC_PROJECTS="${REFLEX_SYNC_PROJECTS:-0}"
SYNC_TARGETS=()
# CLI args were already consumed; re-scan original args via a state file? Simpler:
# look for a sync-targets file at well-known path
if [ -f "$PROJ_ROOT/.portable-spec-kit/sync-targets.txt" ]; then
  while IFS= read -r tgt; do
    [ -z "$tgt" ] && continue
    [[ "$tgt" =~ ^# ]] && continue   # comments
    SYNC_TARGETS+=("$tgt")
  done < "$PROJ_ROOT/.portable-spec-kit/sync-targets.txt"
fi

# Kit-self detection: kit's portable-spec-kit.md is a regular file; user projects
# typically symlink or copy it. We only propagate FROM kit-self.
is_kit_self=0
if [ -f "$PROJ_ROOT/portable-spec-kit.md" ] && [ ! -L "$PROJ_ROOT/portable-spec-kit.md" ] && \
   [ -d "$PROJ_ROOT/reflex/lib" ] && [ -f "$PROJ_ROOT/install.sh" ]; then
  is_kit_self=1
fi

# KIT-GAP-0082: keep the workspace-root mirror copy in sync with the canonical
# checkout copy on every version bump. The kit-dev test suite (02-pipeline.sh)
# asserts the ROOT=$PROJ/../.. mirror matches the checkout copy; before this, the
# bump touched only the checkout copy and the mirror drifted, forcing a manual cp.
# Guarded: kit-self only, and only when the mirror already exists AND is a kit copy
# (carries "Framework Version:") — so it is a safe no-op for any user project where
# the parent path holds an unrelated file or nothing.
# KIT-GAP-0088: keep the workspace-root mirror of portable-spec-kit.md in sync AND
# committed on every version bump. TWO root causes were behind the recurring drift:
#  (1) Path/guard fragility: the old block keyed off `$PROJ_ROOT` (is_kit_self via
#      `$PROJ_ROOT/reflex/lib`, path via `$PROJ_ROOT/../..`). Callers export PROJ_ROOT
#      as the OUTER git toplevel in a nested-repo layout → `$PROJ_ROOT/reflex/lib`
#      absent → is_kit_self=0 → sync skipped; `$PROJ_ROOT/../..` also overshot. Fixed
#      by anchoring the kit checkout to THIS script's location (immune to PROJ_ROOT
#      override) and locating the mirror at the git toplevel (any nesting depth).
#  (2) THE ACTUAL DRIFT CAUSE: even when the sync ran, it only touched the WORKING
#      TREE. The release commit's `git add -A .` runs from the kit subdir, so it never
#      stages the PARENT-dir mirror → the synced mirror is never committed → the next
#      checkout reverts it. The mirror sat un-updated in git since v0.6.57. Fix: after
#      syncing, `git add` the mirror in the outer repo so the surrounding bump/release
#      commit persists it. Sync without staging is the workaround; staging is the fix.
_kit_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -f "$_kit_root/portable-spec-kit.md" ] && [ ! -L "$_kit_root/portable-spec-kit.md" ] && \
   [ -d "$_kit_root/reflex/lib" ] && [ "${CHECK_ONLY:-0}" != "1" ]; then
  _git_top="$(git -C "$_kit_root" rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$_git_top" ] && [ "$_git_top" != "$_kit_root" ]; then
    root_mirror="$_git_top/portable-spec-kit.md"
    if [ -f "$root_mirror" ] && grep -q "Framework Version:" "$root_mirror" 2>/dev/null; then
      if cp -p "$_kit_root/portable-spec-kit.md" "$root_mirror" 2>/dev/null; then
        # Stage the mirror in the outer repo so the surrounding commit persists it —
        # without this, the working-tree sync is lost on the next checkout (the drift).
        git -C "$_git_top" add -- "$root_mirror" 2>/dev/null || true
        echo -e "  ${GREEN:-}✓${NC:-} synced + staged workspace-root mirror copy ($root_mirror)${NC:-}"
      fi
    fi
  fi
fi

if [ "$is_kit_self" = "1" ] && [ "${#SYNC_TARGETS[@]}" -gt 0 ] && [ "$CHECK_ONLY" != "1" ]; then
  echo ""
  echo -e "${CYAN}═══ kit machinery propagation (Phase Q) ═══${NC}"
  for tgt in "${SYNC_TARGETS[@]}"; do
    if [ ! -d "$tgt" ]; then
      echo -e "  ${YELLOW}⊘ skip${NC} ${tgt} (does not exist)"
      continue
    fi
    if [ ! -d "$tgt/reflex/lib" ]; then
      echo -e "  ${YELLOW}⊘ skip${NC} ${tgt} (not a kit-installed project — no reflex/lib/)"
      continue
    fi

    # Propagate reflex/lib/*.sh (preserves project-only files via cp -p, no rm)
    cp -p "$PROJ_ROOT"/reflex/lib/*.sh "$tgt/reflex/lib/" 2>/dev/null
    # Propagate reflex/run.sh
    cp -p "$PROJ_ROOT/reflex/run.sh" "$tgt/reflex/" 2>/dev/null
    # Propagate reflex/prompts/*.md
    cp -p "$PROJ_ROOT"/reflex/prompts/*.md "$tgt/reflex/prompts/" 2>/dev/null
    # Propagate agent/scripts/psk-*.sh (project may have its own scripts; kit ones are psk-prefixed)
    cp -p "$PROJ_ROOT"/agent/scripts/psk-*.sh "$tgt/agent/scripts/" 2>/dev/null
    # reflex/config.yml: do NOT bulk-overwrite (project may have customized
    # mandate_compliance_block_severity, e2e_console_allow, etc.). Leave config
    # in place; document that kit upgrades may add new keys to manually adopt.
    # If forcing overwrite needed, set REFLEX_SYNC_CONFIG_OVERWRITE=1.
    if [ "${REFLEX_SYNC_CONFIG_OVERWRITE:-0}" = "1" ]; then
      cp -p "$PROJ_ROOT/reflex/config.yml" "$tgt/reflex/" 2>/dev/null
    fi

    files_changed=$((files_changed + 1))
    echo -e "  ${GREEN}✓${NC} ${tgt} — kit machinery synced (reflex/lib/ · run.sh · prompts/ · psk-*.sh)"

    # Also update the project's agent/AGENT_CONTEXT.md Kit field so it
    # reflects the kit version just propagated (v0.6.39+ — CASCADE-KIT-FIELD).
    tgt_ctx="$tgt/agent/AGENT_CONTEXT.md"
    if [ -f "$tgt_ctx" ]; then
      if grep -qE '^\- \*\*Kit:\*\*' "$tgt_ctx" 2>/dev/null; then
        perl -i -pe "s/(?<=\\*\\*Kit:\\*\\* )v\\d+\\.\\d+\\.\\d+/${TO_VER}/" "$tgt_ctx"
        echo -e "  ${GREEN}✓${NC} ${tgt} — AGENT_CONTEXT.md Kit field → $TO_VER"
        files_changed=$((files_changed + 1))
      fi
    fi
  done
fi

# Final report
if [ "$drift_found" -eq 0 ]; then
  echo -e "${GREEN}✓ no version drift — all cascade artifacts at $TO_VER${NC}"
  exit 0
fi

if [ "$CHECK_ONLY" = "1" ]; then
  echo -e "${RED}✗ version drift detected — re-run without --check-only to fix${NC}"
  exit 1
fi

echo -e "${GREEN}✓ cascade complete — $files_changed file(s) bumped/synced to $TO_VER${NC}"
exit 0
