#!/bin/bash
# mechanical-script: psk-env.sh — env detection + persistence (no AI invocation)
# ════════════════════════════════════════════════════════════════════
# psk-env.sh — runtime environment detector + selector + persister
#
# Generic across all stacks the kit supports: Python, Node, Ruby, Go,
# Rust. Per-project env config lives in .portable-spec-kit/env-config.yml
# (committed to repo so every contributor + every machine + every
# AI agent uses the same env). The interactive selection (asking the
# user) is driven by the env-management skill — this script provides
# the mechanical building blocks the skill calls.
#
# Modes:
#   psk-env.sh detect              — list project types found in repo
#   psk-env.sh status              — show current env-config.yml
#   psk-env.sh list-envs <stack>   — available envs for a stack
#   psk-env.sh set <stack> <manager> <name-or-version>
#                                  — write env-config.yml entry
#   psk-env.sh activate-cmd <stack>
#                                  — output activation prefix string
#                                    (e.g. "conda run -n my-env" or
#                                    "source .venv/bin/activate &&")
#   psk-env.sh check               — verify saved env still works
#
# Author: Portable Spec Kit (kit-author maintained)
# ════════════════════════════════════════════════════════════════════

# QA-D5-P5-001: errexit (-e) added to match the strict-mode convention used by
# psk-sync-check.sh and psk-bypass-log.sh (set -euo pipefail). Without -e a
# command that exits non-zero inside a function (e.g. a corrupt-config awk read
# in cmd_set) would NOT abort, and the script could write an incomplete
# env-config.yml. Probe lines that legitimately exit non-zero (e.g.
# `command -v X && echo …` when X is absent, or intentional `return 1` paths)
# are either the final statement of their function (safe under -e) or guarded
# with `|| true` where they appear mid-function.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$PROJ_ROOT/.portable-spec-kit"
CONFIG_FILE="$CONFIG_DIR/env-config.yml"

if [ -t 1 ]; then
  RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  RED=''; YELLOW=''; GREEN=''; CYAN=''; NC=''
fi

# ---------- Detection ----------

# Output: one project-type token per line. Examples: python, node, ruby, go, rust.
# Never errors — outputs nothing when no recognized stack found.
cmd_detect() {
  # QA-D5-P5-001: under `set -e` a chain like `[ -f a ] || [ -f b ] && echo`
  # exits non-zero when no file matches — which, as the final statement, would
  # make the function (and script) exit 1 even though "no stack found" is a
  # legitimate, non-error outcome. Each probe is `|| true`-guarded and the
  # function ends with an explicit `return 0` so detection never errors.
  { [ -f "$PROJ_ROOT/requirements.txt" ] || \
    [ -f "$PROJ_ROOT/pyproject.toml" ] || \
    [ -f "$PROJ_ROOT/setup.py" ] || \
    [ -f "$PROJ_ROOT/Pipfile" ]; } && echo "python" || true

  { [ -f "$PROJ_ROOT/package.json" ] && echo "node"; } || true

  { [ -f "$PROJ_ROOT/Gemfile" ] && echo "ruby"; } || true

  { [ -f "$PROJ_ROOT/go.mod" ] && echo "go"; } || true

  { [ -f "$PROJ_ROOT/Cargo.toml" ] && echo "rust"; } || true

  return 0
}

# ---------- List available envs per stack ----------

cmd_list_envs() {
  # QA-D5-P5-001: `list-envs` runs many optional-tool probes whose pipelines
  # (e.g. the nvm `sort | awk` chain, the conda `grep | awk` chain) can exit
  # non-zero under `set -o pipefail` — including a SIGPIPE race when stdout is a
  # fast consumer. Listing "what envs exist" is purely informational and must
  # NEVER fail because an optional manager is absent or a probe pipeline saw a
  # broken pipe. The whole body runs in a subshell with errexit disabled so the
  # flaky probe-pipeline exits are isolated; an unknown stack still surfaces a
  # non-zero status via the explicit `exit 1` on the `*)` arm.
  ( set +e +o pipefail
  local stack="${1:-}"
  case "$stack" in
    python)
      if command -v conda >/dev/null 2>&1; then
        echo "# conda envs:"
        # `| grep -vE | awk` exits non-zero (via pipefail) when grep filters
        # every line; guard so an empty conda env list is not treated as a fault.
        conda env list 2>/dev/null | grep -vE '^#|^$' | awk '{print "conda:" $1}' || true
      fi
      # Look for venv/.venv in current dir
      [ -d "$PROJ_ROOT/.venv" ] && echo "venv:$PROJ_ROOT/.venv" || true
      [ -d "$PROJ_ROOT/venv" ] && echo "venv:$PROJ_ROOT/venv" || true
      # System Python
      if command -v python3 >/dev/null 2>&1; then
        local sys_py
        sys_py=$(python3 --version 2>&1 | awk '{print $2}')
        echo "system:python3 $sys_py"
      fi
      # Poetry
      if [ -f "$PROJ_ROOT/pyproject.toml" ] && command -v poetry >/dev/null 2>&1; then
        echo "poetry:$(poetry env info --path 2>/dev/null || echo 'available')"
      fi
      # uv
      { command -v uv >/dev/null 2>&1 && echo "uv:available"; } || true
      ;;
    node)
      if command -v nvm >/dev/null 2>&1 || [ -s "$HOME/.nvm/nvm.sh" ]; then
        echo "# nvm versions:"
        if [ -s "$HOME/.nvm/nvm.sh" ]; then
          # QA-D5-P5-001: capture the nvm version list into a variable FIRST,
          # then echo it. Piping `sort -uV | awk` directly to the function's
          # stdout races against the consumer closing the pipe (SIGPIPE on
          # `sort`); under `set -o pipefail` that non-zero tail intermittently
          # leaked out as the function's exit status when stdout was a fast
          # consumer (e.g. /dev/null in tests). Buffering into $nvm_versions
          # removes the live pipe-to-stdout, so the exit is deterministic.
          local nvm_versions
          # shellcheck source=/dev/null
          nvm_versions="$( (. "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 && nvm ls --no-colors 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sort -uV | awk '{print "nvm:" $1}') 2>/dev/null || true )"
          [ -n "$nvm_versions" ] && printf '%s\n' "$nvm_versions" || true
        fi
      fi
      { command -v volta >/dev/null 2>&1 && echo "volta:$(volta list node 2>/dev/null | head -1)"; } || true
      { command -v fnm >/dev/null 2>&1 && echo "fnm:$(fnm current 2>/dev/null || echo 'available')"; } || true
      { command -v asdf >/dev/null 2>&1 && echo "asdf:$(asdf current nodejs 2>/dev/null || echo 'available')"; } || true
      { command -v node >/dev/null 2>&1 && echo "system:node $(node --version 2>&1)"; } || true
      ;;
    ruby)
      { command -v rbenv >/dev/null 2>&1 && echo "rbenv:$(rbenv versions --bare 2>/dev/null | tr '\n' ',')"; } || true
      { command -v rvm >/dev/null 2>&1 && echo "rvm:available"; } || true
      { command -v ruby >/dev/null 2>&1 && echo "system:ruby $(ruby --version 2>&1 | awk '{print $2}')"; } || true
      ;;
    go)
      { command -v go >/dev/null 2>&1 && echo "system:go $(go version 2>&1 | awk '{print $3}')"; } || true
      { command -v asdf >/dev/null 2>&1 && echo "asdf:$(asdf current golang 2>/dev/null || echo 'available')"; } || true
      ;;
    rust)
      { command -v rustup >/dev/null 2>&1 && echo "rustup:$(rustup show active-toolchain 2>/dev/null | awk '{print $1}')"; } || true
      { command -v rustc >/dev/null 2>&1 && echo "system:rustc $(rustc --version 2>&1 | awk '{print $2}')"; } || true
      ;;
    *)
      echo -e "${RED}unknown stack: $stack${NC}" >&2
      exit 1
      ;;
  esac
  # Recognized stack: informational listing always succeeds.
  exit 0
  )
}

# ---------- Activation command builder ----------

# Builds the prefix string used to run commands inside the saved env.
# Examples:
#   conda env "myproj"         → "conda run -n myproj"
#   venv "/path/to/.venv"      → "source /path/to/.venv/bin/activate &&"
#   poetry                     → "poetry run"
#   uv                         → "uv run"
#   nvm version "20"           → "source $NVM_DIR/nvm.sh && nvm use 20 &&"
#   system                     → "" (empty — use whatever's on PATH)
build_activate_cmd() {
  local manager="$1" arg="${2:-}"
  case "$manager" in
    conda)
      # Use absolute env-bin path prepended to PATH instead of `conda run -n`.
      # `conda run` is unreliable when the user's shell init hardcodes a
      # different conda env in $PATH (a real-world issue observed: shell rc
      # file pinning a different env's bin first defeats conda run's
      # PATH manipulation). Absolute-path PATH-prefix is robust against
      # shell config quirks.
      local conda_base
      conda_base=$(conda info --base 2>/dev/null || echo "$HOME/anaconda3")
      echo "PATH=\"$conda_base/envs/$arg/bin:\$PATH\""
      ;;
    venv)    echo "source $arg/bin/activate &&" ;;
    poetry)  echo "poetry run" ;;
    uv)      echo "uv run" ;;
    nvm)
      if [ -s "$HOME/.nvm/nvm.sh" ]; then
        echo "source $HOME/.nvm/nvm.sh && nvm use $arg --silent &&"
      else
        echo "nvm use $arg &&"
      fi ;;
    volta)   echo "" ;;  # volta intercepts via shims, no prefix needed
    fnm)     echo "fnm use $arg &&" ;;
    asdf)    echo "" ;;  # asdf .tool-versions in repo handles routing
    rbenv)   echo "rbenv shell $arg &&" ;;
    rvm)     echo "rvm use $arg &&" ;;
    rustup)  echo "" ;;  # rustup-toolchain.toml handles routing
    system)  echo "" ;;  # PATH default
    *)       echo "" ;;
  esac
}

cmd_activate_cmd() {
  local stack="${1:-}"
  if [ -z "$stack" ]; then
    echo -e "${RED}usage: psk-env.sh activate-cmd <stack>${NC}" >&2
    return 1
  fi
  if [ ! -f "$CONFIG_FILE" ]; then
    # QA-2-02 (cycle-01-pass-001): no env-config.yml means NO stack has been
    # selected for this project. An explicitly-named stack is therefore
    # unconfigured — surface it (exit 1) rather than silently echoing an empty
    # prefix + exit 0, which §Environment Selection forbids ("do not silently
    # fall back to system"). Callers that genuinely want the system default
    # check the exit code instead of treating empty-stdout as success.
    echo -e "${RED}no env selected: $stack (no $CONFIG_FILE — run 'psk-env.sh set <stack> ...')${NC}" >&2
    return 1
  fi
  # Parse manager + name/version for the requested stack from YAML
  local manager arg
  manager=$(awk -v stack="$stack" '
    /^[[:space:]]*[a-z]+:[[:space:]]*$/ {
      if ($0 ~ "^[[:space:]]+"stack":") in_stack=1
      else in_stack=0
    }
    in_stack && /^[[:space:]]+manager:/ { print $2; exit }
  ' "$CONFIG_FILE")
  arg=$(awk -v stack="$stack" '
    /^[[:space:]]*[a-z]+:[[:space:]]*$/ {
      if ($0 ~ "^[[:space:]]+"stack":") in_stack=1
      else in_stack=0
    }
    in_stack && /^[[:space:]]+(env_name|version|env_path):/ { print $2; exit }
  ' "$CONFIG_FILE")
  arg="${arg//\"/}"  # strip any quotes

  # QA-2-02 (cycle-01-pass-001): an unknown / unconfigured stack must surface an
  # error, not echo an empty prefix + exit 0. §Environment Selection's contract
  # is "If broken -> re-prompt user, do not silently fall back to system". A
  # config file that exists but has no manager entry for the requested stack
  # means this stack was never selected — callers must be able to distinguish
  # "no prefix needed (system, intentional)" from "no env selected for <stack>".
  # build_activate_cmd legitimately returns empty for no-prefix managers
  # (system/volta/asdf/rustup), so we gate on the manager being PARSED, not on
  # the prefix being non-empty.
  if [ -z "$manager" ]; then
    echo -e "${RED}unknown stack: $stack (not configured in $CONFIG_FILE)${NC}" >&2
    return 1
  fi
  build_activate_cmd "$manager" "$arg"
}

# ---------- Set / persist env config ----------

cmd_set() {
  local stack="${1:-}" manager="${2:-}" arg="${3:-}"
  if [ -z "$stack" ] || [ -z "$manager" ]; then
    echo -e "${RED}usage: psk-env.sh set <stack> <manager> [<name-or-version>]${NC}" >&2
    return 1
  fi
  # QA-D8-P5-001 (OWASP A03:2021 Injection): the stack name becomes a YAML key
  # written directly to env-config.yml. Without an allowlist, an arbitrary string
  # (e.g. "; echo INJECTED; #") is written as a YAML key and can break the file
  # or smuggle content. The kit supports exactly these five stacks (cmd_detect()
  # above emits only these tokens), so restrict the writable key-space to them.
  case "$stack" in
    python|node|ruby|go|rust) ;;
    *)
      echo -e "${RED}invalid stack name '$stack' — must be one of: python node ruby go rust${NC}" >&2
      return 1 ;;
  esac
  # The manager is also written into the YAML; restrict it to the known set the
  # dispatch below (the case on "$manager") understands. A non-allowlisted
  # manager would otherwise be written verbatim with no arg-shaping.
  case "$manager" in
    conda|venv|nvm|fnm|rbenv|rvm|poetry|uv|volta|asdf|rustup|system) ;;
    *)
      echo -e "${RED}invalid manager '$manager' — must be one of: conda venv nvm fnm rbenv rvm poetry uv volta asdf rustup system${NC}" >&2
      return 1 ;;
  esac
  mkdir -p "$CONFIG_DIR"

  # Load existing config (if any), merge in new stack entry, rewrite.
  # Simple approach: read all stacks except the one being set, append new entry.
  local tmp="${CONFIG_FILE}.tmp.$$"
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  {
    echo "# Generated by agent/scripts/psk-env.sh — do not edit by hand."
    echo "# Per-project env selection. Read by psk-env.sh activate-cmd <stack>"
    echo "# and by every stack-runtime command before invocation."
    echo "schema_version: 1"
    echo "last_updated: $now"
    echo "runtimes:"

    # Preserve other stacks from existing config
    if [ -f "$CONFIG_FILE" ]; then
      awk -v skip="$stack" '
        /^runtimes:/ { in_rt=1; next }
        in_rt && /^[[:space:]]+[a-z]+:[[:space:]]*$/ {
          stack_name=$0; sub(/^[[:space:]]+/, "", stack_name); sub(/:.*/, "", stack_name)
          if (stack_name == skip) skip_block=1
          else skip_block=0
        }
        in_rt && skip_block==0 && /^[[:space:]]+/ { print }
      ' "$CONFIG_FILE"
    fi

    # Append the new entry for the target stack
    echo "  $stack:"
    echo "    manager: $manager"
    case "$manager" in
      conda)            [ -n "$arg" ] && echo "    env_name: \"$arg\"" ;;
      venv)             [ -n "$arg" ] && echo "    env_path: \"$arg\"" ;;
      nvm|fnm|rbenv|rvm) [ -n "$arg" ] && echo "    version: \"$arg\"" ;;
      poetry|uv|volta|asdf|rustup|system) ;;  # no extra arg needed
    esac
  } > "$tmp" && mv "$tmp" "$CONFIG_FILE"

  echo -e "${GREEN}✓ env-config.yml updated:${NC} $stack → $manager${arg:+ ($arg)}"
}

# ---------- Status / verify ----------

cmd_status() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "No env-config.yml — env not yet selected for this project."
    echo "Run: psk-env.sh detect    # to see what stacks need configuring"
    return 0
  fi
  cat "$CONFIG_FILE"
}

cmd_check() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠ no env-config.yml${NC}"
    return 1
  fi
  local stacks
  stacks=$(awk '
    /^runtimes:/ { in_rt=1; next }
    in_rt && /^[[:space:]]+[a-z]+:[[:space:]]*$/ {
      stack=$0; sub(/^[[:space:]]+/, "", stack); sub(/:.*/, "", stack); print stack
    }
  ' "$CONFIG_FILE")
  local stack rc=0
  for stack in $stacks; do
    local prefix
    prefix=$(cmd_activate_cmd "$stack")
    if [ -z "$prefix" ] && [ "$stack" != "go" ] && [ "$stack" != "rust" ]; then
      echo -e "${YELLOW}⚠ $stack: no activation prefix resolved (manager=system?)${NC}"
      continue
    fi
    # Try a basic version probe
    case "$stack" in
      python)  bash -c "$prefix python3 --version" >/dev/null 2>&1 && echo -e "${GREEN}✓ python: $prefix python3 OK${NC}" || { echo -e "${RED}✗ python env broken${NC}"; rc=1; } ;;
      node)    bash -c "$prefix node --version" >/dev/null 2>&1 && echo -e "${GREEN}✓ node: $prefix node OK${NC}" || { echo -e "${RED}✗ node env broken${NC}"; rc=1; } ;;
      ruby)    bash -c "$prefix ruby --version" >/dev/null 2>&1 && echo -e "${GREEN}✓ ruby: $prefix ruby OK${NC}" || { echo -e "${RED}✗ ruby env broken${NC}"; rc=1; } ;;
      go)      command -v go   >/dev/null 2>&1 && echo -e "${GREEN}✓ go OK${NC}"   || { echo -e "${RED}✗ go missing${NC}";   rc=1; } ;;
      rust)    command -v rustc >/dev/null 2>&1 && echo -e "${GREEN}✓ rust OK${NC}" || { echo -e "${RED}✗ rust missing${NC}"; rc=1; } ;;
    esac
  done
  return $rc
}

# ---------- Dispatch ----------

case "${1:-}" in
  detect)        cmd_detect ;;
  status)        cmd_status ;;
  list-envs)
    shift
    # QA-D5-P5-001: capture cmd_list_envs's status in a tested context. A bare
    # `cmd_list_envs "$@"` under `set -e` would abort the script the instant the
    # function returned non-zero (e.g. a SIGPIPE-driven broken-pipe tail from an
    # optional-tool probe pipeline when stdout is a fast consumer like /dev/null)
    # — never reaching a following assignment. Using `|| _le_rc=$?` keeps the
    # call in an `||`-list (errexit-exempt) so the real status is preserved and
    # re-raised deliberately.
    _le_rc=0
    cmd_list_envs "$@" || _le_rc=$?
    exit "$_le_rc"
    ;;
  set)           shift; cmd_set "$@" ;;
  activate-cmd)  shift; cmd_activate_cmd "$@" ;;
  check)         cmd_check ;;
  help|--help|-h|"")
    sed -n '4,30p' "$0"
    ;;
  *)
    echo -e "${RED}unknown command: $1${NC}" >&2
    echo "Run: psk-env.sh help" >&2
    exit 1 ;;
esac
