#!/usr/bin/env bash
# mechanical-script: §Kit Fidelity wrapper — routes canonical kit commands
# via inventory lookup + rationale gating; no AI invocation, pure bash/awk.
# =============================================================
# psk-kit-cmd.sh — §Kit Fidelity (8th reliability layer) wrapper
#
# Routes canonical kit commands through a single wrapper that enforces:
#   1. Canonical default form     — non-canonical variants require --rationale
#   2. Friction = kit bug         — every friction encountered must be logged
#                                    as KIT-GAP-* in agent/.kit-gap-log
#
# Usage:
#   bash agent/scripts/psk-kit-cmd.sh <command> [args...]
#   bash agent/scripts/psk-kit-cmd.sh <command> [args...] --rationale "<text>"
#
# Examples:
#   bash agent/scripts/psk-kit-cmd.sh reflex                    # canonical autoloop
#   bash agent/scripts/psk-kit-cmd.sh reflex single --rationale "operator approved single-pass for debug"
#   bash agent/scripts/psk-kit-cmd.sh prepare-release           # canonical bump+ceremony
#   bash agent/scripts/psk-kit-cmd.sh prepare-release refresh --rationale "no-bump per ADR-NNN"
#
#   bash agent/scripts/psk-kit-cmd.sh --list                    # show inventory
#   bash agent/scripts/psk-kit-cmd.sh --check reflex single     # would this require rationale? (dry-run)
#   bash agent/scripts/psk-kit-cmd.sh --log-gap "<command>" "<friction>" "<proposed-fix>"
#
# Exit codes:
#   0   = canonical invocation OR --rationale provided + logged + executed
#   2   = AWAITING_RATIONALE (non-canonical without --rationale)
#   3   = unknown command (not in inventory)
#   1   = underlying command failed
#
# Emergency bypass: PSK_KIT_FIDELITY_DISABLED=1 logs to .bypass-log per PSK027.
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
INVENTORY="$PROJ_ROOT/.portable-spec-kit/kit-commands.yml"
DEVIATION_LOG="$PROJ_ROOT/agent/.kit-deviation-log"
KIT_GAP_LOG="$PROJ_ROOT/agent/.kit-gap-log"
BYPASS_LOG="$PROJ_ROOT/agent/.bypass-log"

if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; CYAN=''; NC=''
fi

# ---------- bypass handling ----------
# B7 fix (QA-D7-BYPASS-LOG-NORMAL-PATH): a `--check` invocation is a DRY-RUN
# classification ("would this command need --rationale?") that executes NOTHING —
# it is not an actual gate bypass. Logging it inflates PSK027's abuse counter with
# non-bypasses, and because reflex dry-run-checks its own `reflex single` invocation
# every pass, those phantom entries trip reflex's OWN sync-check gate (PSK027 ERROR)
# and falsely DENY otherwise-clean passes. Only log a bypass for a real (non-check)
# command execution.
if [ "${PSK_KIT_FIDELITY_DISABLED:-0}" = "1" ]; then
  # The bypass warning is informational and always prints when the env var is set.
  printf "%b⚠ Kit-fidelity wrapper bypassed via PSK_KIT_FIDELITY_DISABLED=1%b\n" "$YELLOW" "$NC" >&2
  if [ "${1:-}" = "--check" ]; then
    # B7: a --check invocation is a DRY-RUN classification that executes nothing —
    # it is NOT an actual gate bypass. Do NOT log it (logging inflates PSK027's abuse
    # counter, and because reflex dry-run-checks its own `reflex single` every pass,
    # those phantom entries trip reflex's OWN sync-check gate → false DENY). Fall
    # through to the normal --check dry-run handler below; no bypass is recorded.
    :
  else
    # Real command under the bypass — record it and dispatch without enforcement.
    # QA-D7-BYPASS-LOG fix (v0.6.83): route through the canonical JSON logger so
    # PSK027's counter (JSON-only) actually SEES this bypass. Raw-TSV append kept
    # only as a fallback when the logger is absent.
    _bypass_logger="$(dirname "${BASH_SOURCE[0]}")/psk-bypass-log.sh"
    if [ -x "$_bypass_logger" ]; then
      bash "$_bypass_logger" log --env-var PSK_KIT_FIDELITY_DISABLED \
        --command "psk-kit-cmd.sh $*" \
        --justification "${PSK_BYPASS_REASON:-not provided}" >/dev/null 2>&1 || true
    else
      ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      mkdir -p "$(dirname "$BYPASS_LOG")"
      echo "$ts PSK_KIT_FIDELITY_DISABLED psk-kit-cmd.sh args=$*" >> "$BYPASS_LOG"
    fi
    printf "%b  (logged to agent/.bypass-log per PSK027)%b\n" "$YELLOW" "$NC" >&2
    # Dispatch directly without enforcement
    ACTION="${1:-}"
    shift || true
    case "$ACTION" in
      reflex)             exec bash "$PROJ_ROOT/reflex/run.sh" "$@" ;;
      prepare-release)    exec bash "$PROJ_ROOT/agent/scripts/psk-release.sh" prepare "$@" ;;
      refresh-release)    exec bash "$PROJ_ROOT/agent/scripts/psk-release.sh" refresh "$@" ;;
      init)               exec bash "$PROJ_ROOT/agent/scripts/psk-init.sh" "$@" ;;
      orchestrate)        exec bash "$PROJ_ROOT/agent/scripts/psk-orchestrate.sh" build "$@" ;;
      feature-complete)   exec bash "$PROJ_ROOT/agent/scripts/psk-feature-complete.sh" "$@" ;;
      new-setup)          exec bash "$PROJ_ROOT/agent/scripts/psk-new-setup.sh" "$@" ;;
      existing-setup)     exec bash "$PROJ_ROOT/agent/scripts/psk-existing-setup.sh" "$@" ;;
      run-plan)           exec bash "$PROJ_ROOT/agent/scripts/psk-run-plan.sh" "$@" ;;
      *)                  echo "Unknown command: $ACTION" >&2; exit 3 ;;
    esac
  fi
fi

# ---------- helpers ----------
log_deviation() {
  local cmd="$1"
  local variant_flag="$2"
  local rationale="$3"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  # Hash the rationale text (POSIX-friendly — sha1sum or shasum)
  local rationale_hash=""
  if command -v sha1sum >/dev/null 2>&1; then
    rationale_hash=$(printf '%s' "$rationale" | sha1sum | awk '{print substr($1,1,12)}')
  elif command -v shasum >/dev/null 2>&1; then
    rationale_hash=$(printf '%s' "$rationale" | shasum | awk '{print substr($1,1,12)}')
  else
    rationale_hash="nohash"
  fi
  # Tab-separated for grep-friendliness; format: ts CMD FLAG hash rationale
  printf '%s\t%s\t%s\t%s\t%s\n' "$ts" "$cmd" "$variant_flag" "$rationale_hash" "$rationale" >> "$DEVIATION_LOG"
}

log_gap() {
  local cmd="$1"
  local friction="$2"
  local proposed_fix="$3"
  # v0.6.67: optional positional args 4 + 5 are disposition + defer_target.
  # Caller (main --log-gap dispatch) parses --defer/--bypassed/--outside-repo
  # flags and passes the resolved values here. Defaults preserve old behavior.
  local disposition="${4:-pending}"
  local defer_target="${5:-}"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  # Generate sequential KIT-GAP-NNNN id
  local next_id=1
  if [ -s "$KIT_GAP_LOG" ]; then
    local last_id
    last_id=$(grep -oE 'KIT-GAP-[0-9]+' "$KIT_GAP_LOG" | sort -t- -k3 -n | tail -1 | sed 's/KIT-GAP-//')
    if [ -n "$last_id" ]; then
      # KIT-GAP-0008 fix: force base-10 via 10# prefix.
      next_id=$((10#$last_id + 1))
    fi
  fi
  local gap_id
  gap_id=$(printf "KIT-GAP-%04d" "$next_id")
  # G27 (QA-D22-001/002): sanitize embedded tabs/newlines/CRs in every field to a single
  # space, so a multi-line or tab-containing description can never split one logical entry
  # into a malformed "continuation block" or shift the field columns. Guarantees the line
  # is always a single 5-field TSV record (ISO ts first) regardless of input length/shape.
  cmd=$(printf '%s' "$cmd" | tr '\t\r\n' '   ')
  friction=$(printf '%s' "$friction" | tr '\t\r\n' '   ')
  proposed_fix=$(printf '%s' "$proposed_fix" | tr '\t\r\n' '   ')
  printf '%s\t%s\t%s\t%s\t%s\n' "$ts" "$gap_id" "$cmd" "$friction" "$proposed_fix" >> "$KIT_GAP_LOG"

  # PSK041 marker — disposition state determines whether PSK041 enforces the
  # filed-then-workaround anti-pattern. v0.6.67 adds explicit non-pending
  # states (deferred / bypassed / outside-repo / escalated / kit-fixed) so
  # legitimate cases are not flagged as workarounds.
  local pending_dir="$PROJ_ROOT/agent/.workflow-state/pending-kit-gap"
  mkdir -p "$pending_dir"
  local marker="$pending_dir/$gap_id.pending"
  {
    echo "ts=$ts"
    echo "id=$gap_id"
    echo "cmd=$cmd"
    echo "disposition=$disposition"
    [ -n "$defer_target" ] && echo "defer_target=$defer_target"
    echo "# Disposition values recognized by PSK041:"
    echo "#   pending       — needs fix; PSK041 enforces"
    echo "#   deferred      — postponed to a future version (operator set via --defer)"
    echo "#   bypassed      — used canonical kit bypass flag (e.g. --skip-preconditions)"
    echo "#   outside-repo  — fix lives outside tracked files (.git/hooks/, etc.)"
    echo "#   escalated     — operator-only decision, routed elsewhere"
    echo "#   kit-fixed     — commit message contained KIT-GAP-NNNN"
  } > "$marker"

  echo "$gap_id"
}

extract_rationale() {
  # Scans argv for --rationale "<text>" or --rationale=<text>
  # Echoes the rationale text (or empty string if not found)
  # Also strips the --rationale arg from argv via the global RATIONALE_STRIPPED_ARGS
  RATIONALE=""
  RATIONALE_STRIPPED_ARGS=()
  local skip_next=0
  for arg in "$@"; do
    if [ "$skip_next" = "1" ]; then
      RATIONALE="$arg"
      skip_next=0
      continue
    fi
    case "$arg" in
      --rationale)
        skip_next=1
        ;;
      --rationale=*)
        RATIONALE="${arg#--rationale=}"
        ;;
      *)
        RATIONALE_STRIPPED_ARGS+=("$arg")
        ;;
    esac
  done
}

# Match a single argv token against the variant patterns for the given command.
# Returns 0 if argv contains any non-canonical variant; sets MATCHED_FLAG to the
# pattern name. Returns 1 if all argv tokens are canonical.
detect_non_canonical() {
  local cmd="$1"
  shift
  MATCHED_FLAG=""
  MATCHED_REASON=""
  # Read variants from inventory using awk (POSIX, no yq dependency)
  # Format expected:
  #   - name: <cmd>
  #     variants:
  #       - pattern: "<p>"
  #         flag: "<f>"
  #         why_non_canonical: "<r>"
  local variants
  variants=$(awk -v cmd="$cmd" '
    BEGIN { in_block=0; in_variants=0 }
    /^  - name:/ {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      sub(/^- name: */, "", $0)
      in_block = ($0 == cmd) ? 1 : 0
      in_variants = 0
      next
    }
    in_block && /^    variants:/ { in_variants=1; next }
    in_block && in_variants && /^      - pattern:/ {
      gsub(/^[[:space:]]+- pattern: */, "", $0)
      gsub(/^"|"$/, "", $0)
      pattern = $0
      printf "%s|", pattern
    }
    in_block && in_variants && /^        why_non_canonical:/ {
      gsub(/^[[:space:]]+why_non_canonical: */, "", $0)
      gsub(/^"|"$/, "", $0)
      printf "%s\n", $0
    }
    in_block && /^  - name:/ { in_block=0; in_variants=0 }
  ' "$INVENTORY")

  # Now check each argv token against each variant pattern
  for arg in "$@"; do
    while IFS='|' read -r pattern reason; do
      [ -z "$pattern" ] && continue
      # Wildcard match (e.g. --skip-* matches --skip-env)
      case "$arg" in
        $pattern)
          MATCHED_FLAG="$pattern"
          MATCHED_REASON="$reason"
          return 0
          ;;
      esac
    done <<< "$variants"
  done
  return 1
}

show_list() {
  printf "%bCanonical kit-command inventory%b (read from .portable-spec-kit/kit-commands.yml):\n\n" "$CYAN" "$NC"
  awk '
    /^  - name:/ {
      gsub(/^[[:space:]]+- name: */, "", $0)
      printf "\n  %s\n", $0
    }
    /^    canonical:/ {
      gsub(/^[[:space:]]+canonical: */, "", $0)
      gsub(/^"|"$/, "", $0)
      printf "    canonical: %s\n", $0
    }
    /^    canonical_description:/ {
      gsub(/^[[:space:]]+canonical_description: */, "", $0)
      gsub(/^"|"$/, "", $0)
      printf "    └─ %s\n", $0
    }
  ' "$INVENTORY"
  echo ""
  printf "Run via: %bbash agent/scripts/psk-kit-cmd.sh <name> [args]%b\n" "$CYAN" "$NC"
  printf "Non-canonical variants require: %b--rationale \"<text>\"%b\n" "$YELLOW" "$NC"
}

show_help() {
  cat <<EOF
psk-kit-cmd.sh — §Kit Fidelity (8th reliability layer) wrapper

USAGE:
  bash agent/scripts/psk-kit-cmd.sh <command> [args...]
  bash agent/scripts/psk-kit-cmd.sh <command> [args...] --rationale "<text>"

COMMANDS (read from .portable-spec-kit/kit-commands.yml):
  reflex | prepare-release | refresh-release | init | orchestrate
  feature-complete | new-setup | existing-setup | run-plan

UTILITIES:
  --list                        Show full canonical-command inventory
  --check <cmd> <args>          Dry-run: would this require --rationale?
  --log-gap <cmd> <friction> <fix>   Record a KIT-GAP-* entry without running

EMERGENCY BYPASS:
  PSK_KIT_FIDELITY_DISABLED=1 bash agent/scripts/psk-kit-cmd.sh ...
  (logged to .bypass-log per PSK027)

See: portable-spec-kit.md §Kit Fidelity (8th reliability layer)
     docs/work-flows/30-kit-fidelity.md
     .portable-spec-kit/skills/kit-fidelity.md
EOF
}

# ---------- main ----------
if [ ! -f "$INVENTORY" ]; then
  printf "%b✗ Canonical-command inventory missing at %s%b\n" "$RED" "$INVENTORY" "$NC" >&2
  echo "  Cannot enforce §Kit Fidelity without inventory. Restore the file or run install.sh." >&2
  exit 3
fi

ACTION="${1:-}"
case "$ACTION" in
  ""|--help|-h|help)
    show_help
    exit 0
    ;;
  --list)
    show_list
    exit 0
    ;;
  --check)
    shift
    if [ "$#" -lt 1 ]; then
      echo "Usage: --check <cmd> [args...]" >&2
      exit 1
    fi
    cmd="$1"
    shift
    if detect_non_canonical "$cmd" "$@"; then
      printf "%bNon-canonical%b: command '%s' arg '%s' matches variant pattern\n" "$YELLOW" "$NC" "$cmd" "$MATCHED_FLAG"
      printf "  Reason: %s\n" "$MATCHED_REASON"
      printf "  Requires: --rationale \"<text>\"\n"
      exit 2
    else
      printf "%bCanonical%b: command '%s' with given args matches default form\n" "$GREEN" "$NC" "$cmd"
      exit 0
    fi
    ;;
  --log-gap)
    shift
    # Recursion-fix (v0.6.67 KIT-GAP-0014): support --defer <target-version>
    # flag so operator can mark a gap as legitimately postponed. PSK041 skips
    # markers with disposition=deferred. The flag MUST come BEFORE the 3
    # positional args.
    DEFER_TARGET=""
    DISPOSITION="pending"
    while [ "${1:-}" = "--defer" ] || [ "${1:-}" = "--bypassed" ] || [ "${1:-}" = "--outside-repo" ]; do
      case "$1" in
        --defer)
          shift
          DEFER_TARGET="${1:-unspecified}"
          DISPOSITION="deferred"
          shift
          ;;
        --bypassed)
          shift
          DEFER_TARGET="${1:-canonical-flag}"
          DISPOSITION="bypassed"
          shift
          ;;
        --outside-repo)
          shift
          DEFER_TARGET="${1:-untracked-path}"
          DISPOSITION="outside-repo"
          shift
          ;;
      esac
    done
    if [ "$#" -lt 3 ]; then
      echo "Usage: --log-gap [--defer <target>|--bypassed <flag>|--outside-repo <path>] <cmd> <friction> <proposed-fix>" >&2
      exit 1
    fi
    gap_id=$(log_gap "$1" "$2" "$3" "$DISPOSITION" "$DEFER_TARGET")
    printf "%b✓ Logged %s%b" "$GREEN" "$gap_id" "$NC"
    [ "$DISPOSITION" != "pending" ] && printf " %b(disposition=%s, target=%s)%b" "$YELLOW" "$DISPOSITION" "$DEFER_TARGET" "$NC"
    printf "\n"
    printf "  command: %s\n" "$1"
    printf "  friction: %s\n" "$2"
    printf "  proposed-fix: %s\n" "$3"
    printf "  See: agent/.kit-gap-log\n"
    exit 0
    ;;
esac

# Dispatch a real command
shift  # remove ACTION from argv
extract_rationale "$@"
# RATIONALE_STRIPPED_ARGS now has argv minus --rationale
underlying_args=("${RATIONALE_STRIPPED_ARGS[@]:-}")

# Check canonical-vs-non-canonical
if [ "${#underlying_args[@]}" -gt 0 ] && detect_non_canonical "$ACTION" "${underlying_args[@]}"; then
  # Non-canonical detected
  if [ -z "$RATIONALE" ]; then
    # AWAITING_RATIONALE
    printf "%b⏸ AWAITING_RATIONALE%b — non-canonical invocation requires explicit user rationale\n\n" "$YELLOW" "$NC" >&2
    printf "  command:        %s\n" "$ACTION" >&2
    printf "  args:           %s\n" "${underlying_args[*]}" >&2
    printf "  non-canonical:  %s\n" "$MATCHED_FLAG" >&2
    printf "  why:            %s\n\n" "$MATCHED_REASON" >&2
    printf "  Two forward paths (pick ONE):\n" >&2
    printf "  1. Run the CANONICAL form (recommended):\n" >&2
    printf "       bash agent/scripts/psk-kit-cmd.sh %s\n\n" "$ACTION" >&2
    printf "  2. Provide --rationale with user-authored justification:\n" >&2
    printf "       bash agent/scripts/psk-kit-cmd.sh %s %s --rationale \"<user-authored text>\"\n\n" "$ACTION" "${underlying_args[*]}" >&2
    printf "  Before either path, consider logging a KIT-GAP if the canonical form has friction:\n" >&2
    printf "       bash agent/scripts/psk-kit-cmd.sh --log-gap \"%s\" \"<friction>\" \"<proposed-fix>\"\n\n" "$ACTION" >&2
    printf "  Emergency only (logs to .bypass-log per PSK027):\n" >&2
    printf "       PSK_KIT_FIDELITY_DISABLED=1 ...\n" >&2
    exit 2
  fi
  # Has rationale — log + execute
  if [ "${#RATIONALE}" -lt 20 ]; then
    printf "%b✗ Rationale too short (need ≥20 chars, got %d)%b\n" "$RED" "${#RATIONALE}" "$NC" >&2
    printf "  Stub rationales defeat the audit-trail purpose. Provide a real reason.\n" >&2
    exit 2
  fi
  log_deviation "$ACTION" "$MATCHED_FLAG" "$RATIONALE"
  printf "%b✓ Deviation logged%b: %s %s (rationale=%d chars)\n" "$GREEN" "$NC" "$ACTION" "$MATCHED_FLAG" "${#RATIONALE}" >&2
  printf "  agent/.kit-deviation-log updated. Proceeding with non-canonical form.\n\n" >&2
fi

# Dispatch the actual command
case "$ACTION" in
  reflex)             exec bash "$PROJ_ROOT/reflex/run.sh" "${underlying_args[@]:-}" ;;
  prepare-release)    exec bash "$PROJ_ROOT/agent/scripts/psk-release.sh" prepare "${underlying_args[@]:-}" ;;
  refresh-release)    exec bash "$PROJ_ROOT/agent/scripts/psk-release.sh" refresh "${underlying_args[@]:-}" ;;
  init)               exec bash "$PROJ_ROOT/agent/scripts/psk-init.sh" "${underlying_args[@]:-}" ;;
  orchestrate)        exec bash "$PROJ_ROOT/agent/scripts/psk-orchestrate.sh" build "${underlying_args[@]:-}" ;;
  feature-complete)   exec bash "$PROJ_ROOT/agent/scripts/psk-feature-complete.sh" "${underlying_args[@]:-}" ;;
  new-setup)          exec bash "$PROJ_ROOT/agent/scripts/psk-new-setup.sh" "${underlying_args[@]:-}" ;;
  existing-setup)     exec bash "$PROJ_ROOT/agent/scripts/psk-existing-setup.sh" "${underlying_args[@]:-}" ;;
  run-plan)           exec bash "$PROJ_ROOT/agent/scripts/psk-run-plan.sh" "${underlying_args[@]:-}" ;;
  *)
    printf "%b✗ Unknown command: %s%b\n" "$RED" "$ACTION" "$NC" >&2
    printf "  Run: bash agent/scripts/psk-kit-cmd.sh --list  (to see canonical inventory)\n" >&2
    exit 3
    ;;
esac
