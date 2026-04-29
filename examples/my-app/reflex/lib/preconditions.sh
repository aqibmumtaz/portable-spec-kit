#!/bin/bash
# reflex/lib/preconditions.sh
#
# Verifies reflex can safely run on the current repo state.
# Called by run.sh before spawning any agent.
#
# Rules (fail-fast, each check is a separate gate):
#   1. Working tree must be clean (no uncommitted changes).
#   2. HEAD must equal the commit recorded in agent/.release-state/last-prep-release
#      (marker written by psk-release.sh Step 10). This enforces the "reflex
#      only runs on post-prep-release state" precondition.
#   3. No uncommitted changes inside reflex/ itself — avoids running a
#      half-edited reflex against the repo.
#
# Exits non-zero with a clear message if any gate fails.

set -uo pipefail

PROJ_ROOT="${REFLEX_PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

fail() { echo -e "${RED}✗ reflex precondition failed:${NC} $1"; echo -e "${CYAN}  $2${NC}"; exit 1; }

cd "$PROJ_ROOT"

# Gate 1 — working tree clean
if [ -n "$(git status --porcelain)" ]; then
  fail "working tree has uncommitted changes" "commit or stash, run prepare release, then retry"
fi

# Gate 2 — HEAD is a prep-release commit (detected via commit message pattern)
# Convention: prep-release commits are titled "v0.N.N: <summary>" or contain
# "prep release" / "refresh release" in the subject line. This avoids a circular
# marker-file dependency (which would require committing a file that records its
# own commit SHA).
head_msg="$(git log -1 --pretty=%s 2>/dev/null || echo "")"
if [ -z "$head_msg" ]; then
  fail "cannot read HEAD commit message" "repo must have at least one commit"
fi

if ! echo "$head_msg" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+:|prep release|refresh release'; then
  fail "HEAD commit message does not match prep-release pattern" "run 'prepare release' first — reflex operates on post-prep-release state. HEAD message: '$head_msg'"
fi

head_sha="$(git rev-parse --short HEAD 2>/dev/null)"

# Gate 3 — no modifications inside reflex/
if git status --porcelain reflex/ 2>/dev/null | grep -q .; then
  fail "uncommitted changes inside reflex/" "commit reflex changes first so the loop is reproducible"
fi

echo -e "${GREEN}✓ preconditions passed${NC} (HEAD = $head_sha, prep-release commit, tree clean)"
