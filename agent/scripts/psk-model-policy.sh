#!/bin/bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist)
# =============================================================
# psk-model-policy.sh — kit-wide model selection resolver
#
# Reads .portable-spec-kit/model-policy.yml and resolves which model a given
# spawn should use, based on the spawn's PHASE (or WORKFLOW substring) → role →
# model. Used by psk-spawn.sh to inject the model into every spawn request so
# model choice is mechanical (data-driven), not memory-driven.
#
# Usage:
#   psk-model-policy.sh lookup <phase> [workflow]   # → prints model (e.g. "sonnet")
#   psk-model-policy.sh role   <phase> [workflow]   # → prints resolved role
#   psk-model-policy.sh roles                       # → prints role → model table
#   psk-model-policy.sh list                        # → prints full policy
#   psk-model-policy.sh path                        # → prints policy file path
#
# Resolution order for lookup/role:
#   1. phase_roles[<phase>]            (exact phase match — qa/dev/critic)
#   2. phase_roles[k] where <phase> or <workflow> contains k   (substring)
#   3. <phase> itself if it is a roles: key
#   4. default
#
# Exit: 0 always (prints `inherit` when nothing maps / policy absent — safe no-op).
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="${PSK_PROJ_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
POLICY="$PROJ_ROOT/.portable-spec-kit/model-policy.yml"

# Built-in default policy — used when model-policy.yml has not yet propagated to a
# project (e.g. an older install). Keeps the cost/perf optimization working out of
# the box; the yml, when present, fully overrides this. Mirrors the shipped yml.
_builtin_role() {   # <phase> [wf] → role (echoes empty if none)
  case "$1" in
    qa-synthesis) echo qa_synthesis ;;
    qa)           echo qa ;;
    dev)          echo dev ;;
    critic)       echo critic ;;
    *synthesis*)  echo qa_synthesis ;;
    *build*)      echo implement ;;
    *) case "${2:-}" in *build*) echo implement ;; *synthesis*) echo qa_synthesis ;; esac ;;
  esac
}
_builtin_model() {  # <role> → model
  case "$1" in
    qa|critic) echo sonnet ;;
    qa_synthesis|dev|implement) echo opus ;;
    *) echo inherit ;;
  esac
}

# read a key from a nested yml block (2-space indented "key: value" under "<section>:")
_block_lookup() {  # <section> <key>
  local section="$1" key="$2"
  [ -f "$POLICY" ] || return 0
  awk -v section="$section" -v key="$key" '
    $0 ~ "^"section":" { inblk=1; next }
    inblk && /^[^[:space:]]/ { inblk=0 }
    inblk {
      line=$0
      sub(/#.*/, "", line)                       # strip inline comment
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      n=index(line, ":")
      if (n>0) {
        k=substr(line,1,n-1); v=substr(line,n+1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        if (k==key) { print v; exit }
      }
    }
  ' "$POLICY"
}

_default_model() {
  local d
  d=$(awk -F: '/^default:/ { sub(/#.*/,"",$2); gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit }' "$POLICY" 2>/dev/null)
  [ -n "$d" ] && echo "$d" || echo "inherit"
}

# resolve <phase> [workflow] → role
resolve_role() {
  local phase="${1:-}" wf="${2:-}" role=""
  [ -f "$POLICY" ] || { _builtin_role "$phase" "$wf"; return 0; }
  # 1. exact phase match in phase_roles
  role=$(_block_lookup "phase_roles" "$phase")
  # 2. substring: any phase_roles key contained in phase or workflow
  if [ -z "$role" ]; then
    local keys k
    keys=$(awk '
      /^phase_roles:/ { inblk=1; next }
      inblk && /^[^[:space:]]/ { inblk=0 }
      inblk { line=$0; sub(/#.*/,"",line); n=index(line,":");
              if(n>0){ k=substr(line,1,n-1); gsub(/[[:space:]]/,"",k); if(k!="") print k } }
    ' "$POLICY" 2>/dev/null)
    for k in $keys; do
      case "$phase" in *"$k"*) role=$(_block_lookup "phase_roles" "$k"); break;; esac
      [ -n "$wf" ] && case "$wf" in *"$k"*) role=$(_block_lookup "phase_roles" "$k"); break;; esac
    done
  fi
  # 3. phase itself is a roles: key
  if [ -z "$role" ]; then
    local direct; direct=$(_block_lookup "roles" "$phase")
    [ -n "$direct" ] && role="$phase"
  fi
  echo "$role"
}

cmd_lookup() {
  local phase="${1:-}" wf="${2:-}" role model
  role=$(resolve_role "$phase" "$wf")
  if [ -z "$role" ]; then _default_model; return 0; fi
  if [ -f "$POLICY" ]; then
    model=$(_block_lookup "roles" "$role")
  else
    model=$(_builtin_model "$role")    # yml not yet propagated — use built-in default
  fi
  [ -n "$model" ] && echo "$model" || _default_model
}

cmd_role() {
  local role; role=$(resolve_role "${1:-}" "${2:-}")
  [ -n "$role" ] && echo "$role" || echo "(default)"
}

cmd_roles() {
  [ -f "$POLICY" ] || { echo "no policy file"; return 0; }
  echo "role → model  (from $POLICY)"
  awk '
    /^roles:/ { inblk=1; next }
    inblk && /^[^[:space:]]/ { inblk=0 }
    inblk { line=$0; sub(/#.*/,"",line); n=index(line,":");
            if(n>0){ k=substr(line,1,n-1); v=substr(line,n+1);
                     gsub(/^[[:space:]]+|[[:space:]]+$/,"",k); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v);
                     if(k!="") printf "  %-14s %s\n", k, v } }
  ' "$POLICY"
  printf "  %-14s %s\n" "(default)" "$(_default_model)"
}

case "${1:-}" in
  lookup) shift; cmd_lookup "$@" ;;
  role)   shift; cmd_role "$@" ;;
  roles)  cmd_roles ;;
  list)   [ -f "$POLICY" ] && cat "$POLICY" || echo "no policy file: $POLICY" ;;
  path)   echo "$POLICY" ;;
  *) echo "usage: psk-model-policy.sh {lookup <phase> [wf] | role <phase> [wf] | roles | list | path}" >&2; exit 2 ;;
esac
