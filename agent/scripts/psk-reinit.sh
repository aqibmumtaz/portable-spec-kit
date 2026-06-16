#!/bin/bash
# mechanical-script: psk-reinit.sh — folded into init (thin redirect alias)
# =============================================================
# psk-reinit.sh — RETIRED, folded into `init` (v0.6.62+)
#
# `reinit` no longer exists as a distinct workflow. The registry-driven `init`
# is idempotent and state-detected: it CREATES the pipeline on an empty project
# and REFRESHES (conforms, content-loss-protected) an existing one. There is no
# longer a create-vs-resync split — one command does both.
#
# This script is a thin redirect kept only so existing muscle-memory / scripts
# that call `psk-reinit.sh` get a clear breadcrumb instead of a cryptic failure
# (DISCARD POLICY, reflex-restore-and-rebuild plan round 14). It prints a
# one-line removal notice and delegates to psk-init.sh, forwarding all args.
#
# §Workflow Fidelity (portable-spec-kit.md): init — the workflow this redirects
# to — executes its declared phases faithfully via psk-dispatch.sh. This alias
# adds no behavior of its own; it only forwards.
# =============================================================

# QA-D5-P8 (cycle-01-pass-008): full errexit. This is a pure echo+exec alias
# with no intentional non-zero returns used as control flow, so adding -e is
# safe and brings it onto the kit's strictest-shell convention.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${YELLOW}reinit is folded into init${NC} — use: bash agent/scripts/psk-init.sh" >&2
echo -e "  ${CYAN}init${NC} is idempotent: it CREATEs an empty project's pipeline and REFRESHes an existing one (content-loss-protected)." >&2

exec bash "$SCRIPT_DIR/psk-init.sh" "$@"
