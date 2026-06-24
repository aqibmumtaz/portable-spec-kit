#!/usr/bin/env bash
# mechanical-script: psk-version-bump.sh — patch-version increment helper
# agent/scripts/psk-version-bump.sh — KIT-GAP-0002/0007 fix (v0.6.66).
#
# ROOT CAUSE OF KIT-GAP-0002 + KIT-GAP-0007:
#
# The release ceremony's phase 6 (step-6-version) calls
# `psk-version-cascade.sh`. The cascade script auto-detects target version
# from `agent/AGENT_CONTEXT.md` (`**Version:** vX.Y.Z` line) and propagates
# that target to ALL version-pinned artifacts. But during phase 6,
# AGENT_CONTEXT.md still has the OLD version (the current one we're
# bumping AWAY from). So the cascade has no NEW target and emits zero
# bumps — phase 6 marks done without actually changing anything.
#
# THE FIX: phase 6 must SEED the patch increment in AGENT_CONTEXT.md FIRST,
# then call cascade. This helper script does the seed step. It is intended
# to be called as the FIRST half of step-6-version's command, with
# psk-version-cascade.sh as the SECOND half.
#
# Usage:
#   bash agent/scripts/psk-version-bump.sh               # auto-increment patch
#   bash agent/scripts/psk-version-bump.sh --to vX.Y.Z   # explicit target
#   bash agent/scripts/psk-version-bump.sh --print       # print next patch, no edit
#
# Exit codes:
#   0 = bumped (or already at target)
#   1 = AGENT_CONTEXT.md missing or version line not findable
#   2 = invalid argument
#
# Field-anchored: only edits the SINGLE `**Version:** vX.Y.Z` line in
# AGENT_CONTEXT.md. The rest of the cascade is handled by psk-version-cascade.sh
# (or psk-version-cascade.sh's Phase Q machinery propagation).

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CTX="$PROJ_ROOT/agent/AGENT_CONTEXT.md"

ACTION="bump"
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --to)     TARGET="${2:-}"; shift 2 ;;
    --print)  ACTION="print"; shift ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [ ! -f "$CTX" ]; then
  echo "✗ AGENT_CONTEXT.md missing at $CTX" >&2
  exit 1
fi

# Read current version
CUR=$(grep -E '^- \*\*Version:\*\* v[0-9]+\.[0-9]+\.[0-9]+' "$CTX" \
  | head -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [ -z "$CUR" ]; then
  echo "✗ Could not find '- **Version:** vX.Y.Z' line in $CTX" >&2
  exit 1
fi

if [ -z "$TARGET" ]; then
  # Auto-increment patch: vM.N.P → vM.N.(P+1)
  M=$(echo "$CUR" | cut -d. -f1 | sed 's/^v//')
  N=$(echo "$CUR" | cut -d. -f2)
  P=$(echo "$CUR" | cut -d. -f3)
  NEXT_P=$((P + 1))
  TARGET="v${M}.${N}.${NEXT_P}"
fi

if [ "$ACTION" = "print" ]; then
  echo "$TARGET"
  exit 0
fi

if [ "$CUR" = "$TARGET" ]; then
  echo "✓ AGENT_CONTEXT.md Version already at $TARGET — no bump needed"
  exit 0
fi

# KIT-GAP-0010 fix (v0.6.66): idempotency via per-run marker. If this
# release run already triggered a bump, skip subsequent invocations to
# avoid overshooting (e.g. v0.6.65 → v0.6.66 → v0.6.67 on retry after
# phase 5 PSK029 failure → dispatcher re-runs phase 6 → second bump).
#
# Marker stored at agent/.workflow-state/release.last-bumped-run-id.
# Cleared automatically when release.state is reset (new prepare invocation).
RELEASE_STATE="$PROJ_ROOT/agent/.workflow-state/release.state"
BUMP_MARKER="$PROJ_ROOT/agent/.workflow-state/release.last-bumped-run-id"
if [ -f "$RELEASE_STATE" ]; then
  CURRENT_RUN_ID=$(grep '^RUN_ID=' "$RELEASE_STATE" | head -1 | cut -d= -f2)
  LAST_BUMPED=""
  [ -f "$BUMP_MARKER" ] && LAST_BUMPED=$(cat "$BUMP_MARKER" 2>/dev/null | head -1)
  if [ -n "$CURRENT_RUN_ID" ] && [ "$LAST_BUMPED" = "$CURRENT_RUN_ID" ]; then
    echo "✓ Phase 6 already bumped during this release run (RUN_ID=$CURRENT_RUN_ID)"
    echo "  Skipping bump — current version $CUR is correct for this in-progress release"
    exit 0
  fi
fi

# Atomic edit: write to tmp, then mv. Avoids partial-write states.
TMP=$(mktemp)
sed "s/^- \*\*Version:\*\* $CUR$/- **Version:** $TARGET/" "$CTX" > "$TMP"

# Verify the substitution actually fired (sed is silent on no-match)
if ! grep -q "^- \*\*Version:\*\* $TARGET$" "$TMP"; then
  rm -f "$TMP"
  echo "✗ sed substitution failed — Version line did not match expected format" >&2
  exit 1
fi

mv "$TMP" "$CTX"
echo "✓ AGENT_CONTEXT.md Version bumped: $CUR → $TARGET"

# Record this bump against the current release RUN_ID so idempotency check
# above kicks in on retries (KIT-GAP-0010 fix).
if [ -f "$RELEASE_STATE" ]; then
  CURRENT_RUN_ID=$(grep '^RUN_ID=' "$RELEASE_STATE" | head -1 | cut -d= -f2)
  [ -n "$CURRENT_RUN_ID" ] && echo "$CURRENT_RUN_ID" > "$BUMP_MARKER"
fi

echo "  (next step: bash agent/scripts/psk-version-cascade.sh to propagate to remaining artifacts)"
