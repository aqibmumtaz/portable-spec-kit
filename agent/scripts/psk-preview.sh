#!/bin/bash
# mechanical-script: psk-preview.sh — universal workflow + plan previewer (no AI invocation)
# psk-preview.sh — Pure read-only previewer for kit workflow declarations and executable plans
#
# Reads `.portable-spec-kit/workflows/<name>/phases.yml` for workflows and
# `agent/plans/<dated>-<slug>.md` for executable plans, and renders a
# human-skimmable summary or a machine-parseable JSON view. Has zero side
# effects (no writes, no mutations, no external dependencies beyond bash +
# awk). Single source of truth — never duplicates declaration content, only
# reads + renders it.
#
# Usage:
#   psk-preview.sh <workflow>                 Render full preview for a workflow
#   psk-preview.sh plan <slug>                Render preview for an executable plan
#   psk-preview.sh <target> --phase <id>      Drill into one phase only
#   psk-preview.sh <target> --graph           Output dependency graph (ASCII)
#   psk-preview.sh <target> --json            Emit JSON for tooling
#   psk-preview.sh --list-workflows           List discovered workflows
#   psk-preview.sh --list-plans               List executable plans
#   psk-preview.sh --help | -h                Print usage summary
#
# Exit codes:
#   0  success
#   1  user error (bad CLI args)
#   2  data error (missing file / malformed declaration)

set -eu

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
WORKFLOWS_DIR="$PROJ_ROOT/.portable-spec-kit/workflows"
PLANS_DIR="$PROJ_ROOT/agent/plans"

# Token cost rate (USD per 1M tokens) — used for TOTALS / cost computations.
TOKEN_COST_PER_M="${PSK_PREVIEW_TOKEN_COST_PER_M:-4}"

# ASCII Unit Separator used by AWK parser to disambiguate field boundaries.
SEP=$'\x1f'

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────

_usage() {
  cat <<'EOF'
psk-preview.sh — universal workflow + plan previewer

USAGE
  psk-preview.sh <workflow>                 Render full preview for a workflow declaration
  psk-preview.sh plan <slug>                Render preview for an executable plan
  psk-preview.sh <target> --phase <id>      Drill into one phase only
  psk-preview.sh <target> --graph           Output dependency graph (ASCII)
  psk-preview.sh <target> --json            Emit JSON for tooling
  psk-preview.sh --list-workflows           List discovered workflows (one per line)
  psk-preview.sh --list-plans               List executable plans (slug + status + phase-count)
  psk-preview.sh --help | -h                Print this usage summary

EXAMPLES
  psk-preview.sh release
  psk-preview.sh reflex-autoloop --graph
  psk-preview.sh feature-complete --json
  psk-preview.sh plan unified-workflow-declarations
  psk-preview.sh release --phase step-9-validation

EXIT CODES
  0  success
  1  user error (bad CLI args)
  2  data error (missing file / malformed declaration)
EOF
}

_die() { echo "psk-preview: $*" >&2; exit 2; }
_die_usage() { echo "psk-preview: $*" >&2; echo "Run 'psk-preview.sh --help' for usage." >&2; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# YAML parsing (AWK — no yq/python dependency)
# ─────────────────────────────────────────────────────────────────────────────
#
# Parses a workflow phases.yml. Emits one record per phase with the following
# Unit-Separator-delimited fields, in order:
#   id|name|goal|spawn_type|prompt|artifact|command|gate|
#   inputs|files_written|files_modified|depends_on|
#   commit_required|estimated_tokens|estimated_wall_clock_min
# List fields (inputs, files_written, files_modified, depends_on) are emitted
# as comma-separated strings (no surrounding spaces); empty list = empty string.

_parse_workflow_phases() {
  local file="$1"
  awk -v SEP="$SEP" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    function strip_quotes(s) {
      s = trim(s)
      if (s ~ /^".*"$/) { s = substr(s, 2, length(s) - 2) }
      else if (s ~ /^'\''.*'\''$/) { s = substr(s, 2, length(s) - 2) }
      return s
    }
    function strip_inline_list(s,    inner, n, arr, i, out) {
      # "[a, b, c]" -> "a,b,c"
      s = trim(s)
      if (s !~ /^\[.*\]$/) { return s }
      inner = substr(s, 2, length(s) - 2)
      n = split(inner, arr, ",")
      out = ""
      for (i = 1; i <= n; i++) {
        a = strip_quotes(trim(arr[i]))
        if (a == "") continue
        out = (out == "" ? a : out "," a)
      }
      return out
    }
    function flush() {
      if (have_id == 0) return
      printf "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
        ph_id, SEP, ph_name, SEP, ph_goal, SEP, ph_spawn, SEP,
        ph_prompt, SEP, ph_artifact, SEP, ph_command, SEP, ph_gate, SEP,
        ph_inputs, SEP, ph_files_written, SEP, ph_files_modified, SEP, ph_depends, SEP,
        ph_commit, SEP, ph_tokens, SEP, ph_wall_clock
      have_id = 0
      ph_id = ""; ph_name = ""; ph_goal = ""; ph_spawn = ""
      ph_prompt = ""; ph_artifact = ""; ph_command = ""; ph_gate = ""
      ph_inputs = ""; ph_files_written = ""; ph_files_modified = ""; ph_depends = ""
      ph_commit = ""; ph_tokens = ""; ph_wall_clock = ""
      cur_list = ""
    }
    BEGIN {
      in_phases = 0
      have_id = 0
      cur_list = ""
      block_key = ""
      block_indent = -1
    }
    # Strip end-of-line YAML comments outside of strings (simple heuristic)
    {
      # remove # ... comments (best-effort: lines starting with # or after whitespace)
      raw = $0
    }
    raw ~ /^#/ { next }
    raw ~ /^[[:space:]]*$/ {
      # blank lines do not end a list; just skip
      next
    }
    # Detect top-level "phases:" marker
    raw ~ /^phases:[[:space:]]*$/ { in_phases = 1; next }
    in_phases == 0 { next }
    # A new top-level key (no leading space, colon) ends the phases section
    raw ~ /^[A-Za-z_][A-Za-z0-9_]*:/ && raw !~ /^phases:/ {
      flush()
      in_phases = 0
      next
    }
    # Detect indented "- id: <value>" — start of a new phase entry
    raw ~ /^[[:space:]]*-[[:space:]]*id:[[:space:]]*/ {
      flush()
      have_id = 1
      v = raw
      sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", v)
      ph_id = strip_quotes(v)
      cur_list = ""
      next
    }
    # Detect block list continuation: "  - <item>"
    raw ~ /^[[:space:]]+-[[:space:]]+/ && cur_list != "" {
      v = raw
      sub(/^[[:space:]]+-[[:space:]]+/, "", v)
      item = strip_quotes(v)
      if (cur_list == "inputs") {
        ph_inputs = (ph_inputs == "" ? item : ph_inputs "," item)
      } else if (cur_list == "files_written") {
        ph_files_written = (ph_files_written == "" ? item : ph_files_written "," item)
      } else if (cur_list == "files_modified") {
        ph_files_modified = (ph_files_modified == "" ? item : ph_files_modified "," item)
      } else if (cur_list == "depends_on") {
        ph_depends = (ph_depends == "" ? item : ph_depends "," item)
      }
      next
    }
    # Match indented scalar key:value lines (within current phase)
    raw ~ /^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*:/ && have_id == 1 {
      cur_list = ""
      key = raw
      sub(/:.*$/, "", key)
      key = trim(key)
      val = raw
      sub(/^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/, "", val)
      val_trim = trim(val)

      # Inline list?  [a, b, c]
      if (val_trim ~ /^\[.*\]$/) {
        list_val = strip_inline_list(val_trim)
        if (key == "inputs") ph_inputs = list_val
        else if (key == "files_written") ph_files_written = list_val
        else if (key == "files_modified") ph_files_modified = list_val
        else if (key == "depends_on") ph_depends = list_val
        next
      }
      # Empty value → start of block list (or block scalar)
      if (val_trim == "") {
        if (key == "inputs" || key == "files_written" || key == "files_modified" || key == "depends_on") {
          cur_list = key
          next
        }
        if (key == "goal" || key == "name" || key == "command" || key == "gate") {
          # Block scalar (rare) — leave empty for simplicity
          next
        }
        next
      }
      # Multi-line block scalar marker (| or >)
      if (val_trim == "|" || val_trim == ">") {
        # Block scalar follow-on not parsed in detail; ignore for goal/name/etc.
        next
      }

      # Scalar assignment
      v_clean = strip_quotes(val_trim)
      if (key == "name") ph_name = v_clean
      else if (key == "goal") ph_goal = v_clean
      else if (key == "spawn_type") ph_spawn = v_clean
      else if (key == "prompt") ph_prompt = v_clean
      else if (key == "artifact") ph_artifact = v_clean
      else if (key == "command") ph_command = v_clean
      else if (key == "gate") ph_gate = v_clean
      else if (key == "commit_required") ph_commit = v_clean
      else if (key == "estimated_tokens") ph_tokens = v_clean
      else if (key == "estimated_wall_clock_min") ph_wall_clock = v_clean
      next
    }
    END { flush() }
  ' "$file"
}

# Parse executable-plan frontmatter. Emits records with the schema used by
# psk-run-plan.sh, but mapped onto the workflow-style record shape so the
# rendering code is shared:
#   id|name|goal|spawn_type|prompt|artifact|command|gate|inputs|...|depends_on|
#   commit_required|estimated_tokens|estimated_wall_clock_min
_parse_plan_phases() {
  local file="$1"
  awk -v SEP="$SEP" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    function strip_quotes(s) {
      s = trim(s)
      if (s ~ /^".*"$/) { s = substr(s, 2, length(s) - 2) }
      else if (s ~ /^'\''.*'\''$/) { s = substr(s, 2, length(s) - 2) }
      return s
    }
    function strip_inline_list(s,    inner, n, arr, i, out, a) {
      s = trim(s)
      if (s !~ /^\[.*\]$/) { return s }
      inner = substr(s, 2, length(s) - 2)
      n = split(inner, arr, ",")
      out = ""
      for (i = 1; i <= n; i++) {
        a = strip_quotes(trim(arr[i]))
        if (a == "") continue
        out = (out == "" ? a : out "," a)
      }
      return out
    }
    function flush() {
      if (have_id == 0) return
      printf "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
        ph_id, SEP, ph_name, SEP, "", SEP, ph_spawn, SEP,
        ph_prompt, SEP, ph_artifact, SEP, "", SEP, ph_gate, SEP,
        "", SEP, "", SEP, "", SEP, ph_depends, SEP,
        ph_commit, SEP, ph_tokens, SEP, ph_wall_clock
      have_id = 0
      ph_id = ""; ph_name = ""; ph_spawn = "sub-agent"
      ph_prompt = ""; ph_artifact = ""; ph_gate = ""
      ph_depends = ""; ph_commit = ""; ph_tokens = ""; ph_wall_clock = ""
    }
    BEGIN {
      fm = 0; in_phases = 0; have_id = 0
      ph_spawn = "sub-agent"
    }
    /^---[[:space:]]*$/ {
      fm++
      if (fm == 2) { flush(); exit }
      next
    }
    fm != 1 { next }
    /^phases:[[:space:]]*$/ { in_phases = 1; next }
    in_phases == 0 { next }
    /^[A-Za-z_][A-Za-z0-9_]*:/ && $0 !~ /^phases:/ {
      flush(); in_phases = 0; next
    }
    /^[[:space:]]*-[[:space:]]*id:[[:space:]]*/ {
      flush()
      have_id = 1
      v = $0
      sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", v)
      ph_id = strip_quotes(v)
      ph_spawn = "sub-agent"
      next
    }
    /^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*:/ && have_id == 1 {
      key = $0
      sub(/:.*$/, "", key)
      key = trim(key)
      val = $0
      sub(/^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/, "", val)
      val_trim = trim(val)
      if (val_trim ~ /^\[.*\]$/) {
        list_val = strip_inline_list(val_trim)
        if (key == "depends_on") ph_depends = list_val
        next
      }
      v_clean = strip_quotes(val_trim)
      if (key == "name") ph_name = v_clean
      else if (key == "prompt") ph_prompt = v_clean
      else if (key == "artifact") ph_artifact = v_clean
      else if (key == "gate") ph_gate = v_clean
      else if (key == "commit_required") ph_commit = v_clean
      else if (key == "estimated_tokens") ph_tokens = v_clean
      else if (key == "estimated_wall_clock_min") ph_wall_clock = v_clean
      else if (key == "spawn_type") ph_spawn = v_clean
      next
    }
    END { flush() }
  ' "$file"
}

# Extract top-level scalar fields from a workflow phases.yml.
# Args: <file> <key>
_yaml_top_scalar() {
  local file="$1" key="$2"
  awk -v key="$key" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    /^---[[:space:]]*$/ { fm++; next }
    {
      if (match($0, "^" key ":[[:space:]]*")) {
        v = substr($0, RLENGTH + 1)
        sub(/[[:space:]]+$/, "", v)
        # Strip surrounding quotes if any
        if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
        else if (v ~ /^'\''.*'\''$/) v = substr(v, 2, length(v) - 2)
        print v
        exit
      }
    }
  ' "$file"
}

# Read the description block scalar (`description: |\n  ...`).
_yaml_description() {
  local file="$1"
  awk '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    BEGIN { in_desc = 0; indent = -1; out = "" }
    /^description:[[:space:]]*[|>][[:space:]]*$/ { in_desc = 1; next }
    /^description:[[:space:]]*/ && !/[|>][[:space:]]*$/ && in_desc == 0 {
      v = $0
      sub(/^description:[[:space:]]*/, "", v)
      print trim(v)
      exit
    }
    in_desc == 1 {
      if ($0 ~ /^[A-Za-z_][A-Za-z0-9_]*:/) { exit }
      if ($0 ~ /^[[:space:]]*$/) {
        if (out != "") out = out " "
        next
      }
      line = $0
      sub(/^[[:space:]]+/, "", line)
      out = (out == "" ? line : out " " line)
    }
    END { if (out != "") print out }
  ' "$file"
}

# Extract a top-level frontmatter scalar from an executable plan markdown file.
_plan_frontmatter_scalar() {
  local file="$1" key="$2"
  awk -v key="$key" '
    BEGIN { fm = 0 }
    /^---[[:space:]]*$/ { fm++; if (fm == 2) exit; next }
    fm == 1 {
      if (match($0, "^" key ":[[:space:]]*")) {
        v = substr($0, RLENGTH + 1)
        sub(/[[:space:]]+$/, "", v)
        if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
        print v
        exit
      }
    }
  ' "$file"
}

# Detect whether a plan file has a `phases:` frontmatter array.
_plan_has_phases() {
  local file="$1"
  awk '
    BEGIN { fm = 0; found = 0 }
    /^---[[:space:]]*$/ { fm++; if (fm == 2) exit; next }
    fm == 1 && /^phases:[[:space:]]*$/ { found = 1; exit }
    END { exit (found ? 0 : 1) }
  ' "$file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Listings
# ─────────────────────────────────────────────────────────────────────────────

_list_workflows() {
  [ -d "$WORKFLOWS_DIR" ] || _die "workflows directory not found: $WORKFLOWS_DIR"
  local d name
  for d in "$WORKFLOWS_DIR"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    # Skip private dirs (start with _ or .)
    case "$name" in
      _*|.*) continue ;;
    esac
    [ -f "$d/phases.yml" ] && echo "$name"
  done | sort
}

_list_plans() {
  [ -d "$PLANS_DIR" ] || _die "plans directory not found: $PLANS_DIR"
  local f slug status count
  for f in "$PLANS_DIR"/*.md; do
    [ -f "$f" ] || continue
    if _plan_has_phases "$f"; then
      slug="$(_plan_frontmatter_scalar "$f" slug)"
      [ -z "$slug" ] && slug="$(basename "$f" .md)"
      status="$(_plan_frontmatter_scalar "$f" status)"
      [ -z "$status" ] && status="unknown"
      count="$(_parse_plan_phases "$f" | wc -l | tr -d ' ')"
      printf '%s  %s  %sp\n' "$slug" "$status" "$count"
    fi
  done | sort
}

# Resolve a slug to its most recent dated plan file under agent/plans/.
_resolve_plan_file() {
  local slug="$1"
  local f
  f=$(ls -1 "$PLANS_DIR"/[0-9]*-"$slug".md 2>/dev/null | sort -r | head -1)
  [ -z "$f" ] && f=$(ls -1 "$PLANS_DIR"/"$slug".md 2>/dev/null | head -1)
  echo "$f"
}

# ─────────────────────────────────────────────────────────────────────────────
# Cost + workflow-script lookup helpers
# ─────────────────────────────────────────────────────────────────────────────

# Maps a workflow name to the canonical script that runs it.
# Hardcoded lookup table — kept explicit so reviewers see the mapping at a glance.
_workflow_script() {
  case "$1" in
    release)                  echo "bash agent/scripts/psk-release.sh prepare" ;;
    orchestrate)   echo "bash agent/scripts/psk-orchestrate.sh build \"<raw req>\"" ;;
    feature-complete)         echo "bash agent/scripts/psk-feature-complete.sh <FEATURE_ID>" ;;
    init)                     echo "bash agent/scripts/psk-init.sh" ;;
    new-setup)                echo "bash agent/scripts/psk-new-setup.sh" ;;
    existing-setup)           echo "bash agent/scripts/psk-existing-setup.sh" ;;
    reflex-autoloop)          echo "bash reflex/run.sh" ;;
    reflex-single-pass)       echo "bash reflex/run.sh single" ;;
    *)                        echo "bash agent/scripts/psk-${1}.sh" ;;
  esac
}

_classify_workflow() {
  # Class A canonical: kit's already plan-driven shapes.
  case "$1" in
    psk-run-plan) echo "Class A canonical" ;;
    *)                                   echo "retrofitted (v0.6.62+)" ;;
  esac
}

# Compute dollars from tokens. Args: <total-tokens>. Echoes "0.00"-style string.
_cost_usd() {
  local tokens="$1"
  awk -v t="${tokens:-0}" -v r="$TOKEN_COST_PER_M" 'BEGIN { printf "%.2f", (t * r) / 1000000.0 }'
}

# Compute hours from minutes. Args: <total-minutes>. Echoes "N.N"-style.
_hours_from_min() {
  local mins="$1"
  awk -v m="${mins:-0}" 'BEGIN { printf "%.1f", m / 60.0 }'
}

# Count comma-separated list entries; empty -> 0.
_count_csv() {
  local v="$1"
  [ -z "$v" ] && { echo 0; return; }
  echo "$v" | awk -F',' '{ n=0; for (i=1; i<=NF; i++) if ($i != "") n++; print n }'
}

# ─────────────────────────────────────────────────────────────────────────────
# Rendering — human mode
# ─────────────────────────────────────────────────────────────────────────────

_render_phase_block() {
  # Args (positional, US-delimited fields the parsers emit):
  #   1=id 2=name 3=goal 4=spawn_type 5=prompt 6=artifact 7=command 8=gate
  #   9=inputs 10=files_written 11=files_modified 12=depends_on
  #   13=commit_required 14=tokens 15=wall_clock_min
  local id="$1" name="$2" goal="$3" spawn="$4" prompt="$5" artifact="$6"
  local command="$7" gate="$8" inputs="$9" files_w="${10}" files_m="${11}"
  local depends="${12}" commit_req="${13}" tokens="${14}" wall="${15}"

  local tokens_n="${tokens:-0}"
  [ -z "$tokens_n" ] && tokens_n=0
  local wall_n="${wall:-0}"
  [ -z "$wall_n" ] && wall_n=0
  local cost_usd; cost_usd=$(_cost_usd "$tokens_n")
  local tokens_k; tokens_k=$(awk -v t="$tokens_n" 'BEGIN { printf "%.1f", t/1000.0 }')

  printf -- "──── PHASE %s: %s " "$id" "$name"
  # Pad rule line to ~76 cols
  local _padlen=$((76 - ${#id} - ${#name} - 13))
  [ "$_padlen" -lt 4 ] && _padlen=4
  local i
  for ((i = 0; i < _padlen; i++)); do printf -- "─"; done
  printf "\n"

  printf "GOAL:        %s\n" "${goal:-(none)}"
  printf "SPAWN_TYPE:  %s\n" "${spawn:-(none)}"

  if [ -n "$inputs" ]; then
    printf "INPUTS:      %s\n" "$(echo "$inputs" | tr ',' ',' | sed 's/,/, /g')"
  else
    printf "INPUTS:      (none)\n"
  fi

  if [ -n "$files_w" ] || [ -n "$files_m" ]; then
    printf "PRODUCES:"
    local first=1
    if [ -n "$files_w" ]; then
      local f
      IFS=',' read -r -a _arr <<<"$files_w"
      for f in "${_arr[@]}"; do
        if [ "$first" = 1 ]; then printf "    + %s\n" "$f"; first=0
        else printf "             + %s\n" "$f"; fi
      done
    fi
    if [ -n "$files_m" ]; then
      IFS=',' read -r -a _arr <<<"$files_m"
      for f in "${_arr[@]}"; do
        if [ "$first" = 1 ]; then printf "    ↻ %s\n" "$f"; first=0
        else printf "             ↻ %s\n" "$f"; fi
      done
    fi
  else
    printf "PRODUCES:    (none)\n"
  fi

  if [ "$spawn" = "mechanical" ] && [ -n "$command" ]; then
    printf "COMMAND:     %s\n" "$command"
  fi
  if [ "$spawn" = "sub-agent" ] && [ -n "$prompt" ]; then
    printf "PROMPT:      %s\n" "$prompt"
    [ -n "$artifact" ] && printf "ARTIFACT:    %s\n" "$artifact"
  fi

  printf "GATE:        %s\n" "${gate:-(none)}"
  printf "COST:        ~%sk tokens (~\$%s) · ~%s min wall-clock\n" \
    "$tokens_k" "$cost_usd" "$wall_n"
  printf "DEPENDS:     %s\n" "${depends:-none}"
  printf "\n"
}

_render_workflow_human() {
  local name="$1" file="$2"
  local desc; desc=$(_yaml_description "$file")
  local class; class=$(_classify_workflow "$name")
  local script; script=$(_workflow_script "$name")

  # First pass — collect phases into arrays for totals computation.
  local -a ids names goals spawns prompts artifacts commands gates
  local -a inputs_arr files_w_arr files_m_arr depends_arr
  local -a commits tokens_arr walls
  local total_tokens=0 total_wall=0
  local files_w_count=0 files_m_count=0

  while IFS="$SEP" read -r id name_ goal spawn prompt artifact command gate \
        in_ fw fm dep commit toks wall; do
    [ -z "$id" ] && continue
    ids+=("$id"); names+=("$name_"); goals+=("$goal"); spawns+=("$spawn")
    prompts+=("$prompt"); artifacts+=("$artifact"); commands+=("$command"); gates+=("$gate")
    inputs_arr+=("$in_"); files_w_arr+=("$fw"); files_m_arr+=("$fm"); depends_arr+=("$dep")
    commits+=("$commit"); tokens_arr+=("$toks"); walls+=("$wall")
    total_tokens=$((total_tokens + ${toks:-0}))
    total_wall=$((total_wall + ${wall:-0}))
    files_w_count=$((files_w_count + $(_count_csv "$fw")))
    files_m_count=$((files_m_count + $(_count_csv "$fm")))
  done < <(_parse_workflow_phases "$file")

  local phase_count=${#ids[@]}
  [ "$phase_count" -eq 0 ] && _die "no phases parsed from $file"

  # Header
  printf "═══════════════════════════════════════════════════════════════════════\n"
  printf "WORKFLOW: %s (%d phases · status: %s)\n" "$name" "$phase_count" "$class"
  if [ -n "$desc" ]; then
    printf "Description: %s\n" "$desc"
  fi
  printf "═══════════════════════════════════════════════════════════════════════\n\n"

  # Phase graph
  printf "PHASE GRAPH (dependency-ordered):\n"
  _render_graph_simple "${ids[@]}"
  # Pass deps separately via a parallel stream
  printf "\n"

  # Per-phase blocks
  local i
  for ((i = 0; i < phase_count; i++)); do
    _render_phase_block \
      "${ids[$i]}" "${names[$i]}" "${goals[$i]}" "${spawns[$i]}" \
      "${prompts[$i]}" "${artifacts[$i]}" "${commands[$i]}" "${gates[$i]}" \
      "${inputs_arr[$i]}" "${files_w_arr[$i]}" "${files_m_arr[$i]}" \
      "${depends_arr[$i]}" "${commits[$i]}" "${tokens_arr[$i]}" "${walls[$i]}"
  done

  # Totals
  local hours; hours=$(_hours_from_min "$total_wall")
  local cost; cost=$(_cost_usd "$total_tokens")
  printf "═══════════════════════════════════════════════════════════════════════\n"
  printf "TOTALS:  %d phases · %d files modified · %d new files · ~%s hours · ~\$%s cost\n" \
    "$phase_count" "$files_m_count" "$files_w_count" "$hours" "$cost"
  printf "═══════════════════════════════════════════════════════════════════════\n"
  printf "→ Run: %s\n" "$script"
  printf "→ Edit: .portable-spec-kit/workflows/%s/phases.yml + phases/*.md\n" "$name"
}

_render_plan_human() {
  local slug="$1" file="$2"
  local status; status=$(_plan_frontmatter_scalar "$file" status)
  [ -z "$status" ] && status="unknown"
  local created; created=$(_plan_frontmatter_scalar "$file" created)
  local updated; updated=$(_plan_frontmatter_scalar "$file" updated)
  local revision; revision=$(_plan_frontmatter_scalar "$file" revision)
  [ -z "$revision" ] && revision="1"

  local -a ids names spawns prompts artifacts gates depends_arr
  local -a commits tokens_arr walls
  local total_tokens=0 total_wall=0

  while IFS="$SEP" read -r id name_ goal spawn prompt artifact command gate \
        in_ fw fm dep commit toks wall; do
    [ -z "$id" ] && continue
    ids+=("$id"); names+=("$name_"); spawns+=("$spawn")
    prompts+=("$prompt"); artifacts+=("$artifact"); gates+=("$gate")
    depends_arr+=("$dep"); commits+=("$commit")
    tokens_arr+=("$toks"); walls+=("$wall")
    total_tokens=$((total_tokens + ${toks:-0}))
    total_wall=$((total_wall + ${wall:-0}))
  done < <(_parse_plan_phases "$file")

  local phase_count=${#ids[@]}
  [ "$phase_count" -eq 0 ] && _die "no phases parsed from $file (plan may be narrative, not executable)"

  printf "═══════════════════════════════════════════════════════════════════════\n"
  printf "PLAN: %s (%d phases · status: %s)\n" "$slug" "$phase_count" "$status"
  printf "Created: %s  ·  Updated: %s  ·  Revision: %s\n" \
    "${created:-?}" "${updated:-?}" "$revision"
  printf "═══════════════════════════════════════════════════════════════════════\n\n"

  printf "PHASE GRAPH (dependency-ordered):\n"
  _render_graph_simple "${ids[@]}"
  printf "\n"

  local i
  for ((i = 0; i < phase_count; i++)); do
    _render_phase_block \
      "${ids[$i]}" "${names[$i]}" "" "${spawns[$i]}" \
      "${prompts[$i]}" "${artifacts[$i]}" "" "${gates[$i]}" \
      "" "" "" \
      "${depends_arr[$i]}" "${commits[$i]}" "${tokens_arr[$i]}" "${walls[$i]}"
  done

  local hours; hours=$(_hours_from_min "$total_wall")
  printf "═══════════════════════════════════════════════════════════════════════\n"
  printf "TOTALS: %d phases · status: %s · ~%s hours estimated\n" \
    "$phase_count" "$status" "$hours"
  printf "═══════════════════════════════════════════════════════════════════════\n"
  printf "→ Resume: bash agent/scripts/psk-run-plan.sh next %s\n" "$slug"
  printf "→ Show:   bash agent/scripts/psk-plan-save.sh show %s\n" "$slug"
}

# ─────────────────────────────────────────────────────────────────────────────
# Graph mode
# ─────────────────────────────────────────────────────────────────────────────

# Simple inline phase-id chain (when phase IDs form a linear order).
_render_graph_simple() {
  local n=$#
  if [ "$n" -le 0 ]; then return; fi
  local i=1
  local out=""
  for id in "$@"; do
    if [ -z "$out" ]; then out="  $id"
    else out="$out ──► $id"
    fi
    i=$((i + 1))
  done
  # If the chain would exceed ~76 cols, line-wrap into multiple lines.
  if [ "${#out}" -le 76 ]; then
    printf "%s\n" "$out"
  else
    # Fallback: one-per-line with dependency annotation (will be filled by --graph
    # detailed mode); for the inline view we just wrap arrows.
    local line="" id_
    for id_ in "$@"; do
      if [ -z "$line" ]; then line="  $id_"
      elif [ "$((${#line} + ${#id_} + 5))" -gt 76 ]; then
        printf "%s ──►\n" "$line"
        line="  $id_"
      else
        line="$line ──► $id_"
      fi
    done
    [ -n "$line" ] && printf "%s\n" "$line"
  fi
}

# Detailed graph rendering — used by --graph mode.
# Args: <workflow|plan-file> <"workflow"|"plan">
_render_graph_detailed() {
  local file="$1" kind="$2"
  local -a ids deps
  local parser
  if [ "$kind" = "workflow" ]; then parser=_parse_workflow_phases
  else parser=_parse_plan_phases
  fi
  while IFS="$SEP" read -r id name_ goal spawn prompt artifact command gate \
        in_ fw fm dep commit toks wall; do
    [ -z "$id" ] && continue
    ids+=("$id")
    deps+=("$dep")
  done < <("$parser" "$file")

  local n=${#ids[@]}
  [ "$n" -eq 0 ] && _die "no phases to graph"

  # Detect linear chain: every phase[i] depends_on phase[i-1] (or none for first).
  local linear=1
  local i
  for ((i = 0; i < n; i++)); do
    local d="${deps[$i]}"
    if [ "$i" -eq 0 ]; then
      [ -n "$d" ] && linear=0
    else
      local prev="${ids[$((i - 1))]}"
      if [ "$d" != "$prev" ]; then linear=0; fi
    fi
  done

  if [ "$linear" = "1" ]; then
    # Inline chain
    _render_graph_simple "${ids[@]}"
  else
    # Fallback DAG-style listing
    for ((i = 0; i < n; i++)); do
      local d="${deps[$i]}"
      [ -z "$d" ] && d="none"
      printf "  %s (depends_on: %s)\n" "${ids[$i]}" "$d"
    done
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# JSON mode
# ─────────────────────────────────────────────────────────────────────────────

# Escape a string for JSON output.
_json_escape() {
  awk 'BEGIN { ORS = "" }
    {
      gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t");
      gsub(/\r/, "\\r"); gsub(/\n/, "\\n");
      print
    }
  ' <<<"$1"
}

# Render a comma-separated list as a JSON array.
_json_array() {
  local csv="$1"
  if [ -z "$csv" ]; then echo "[]"; return; fi
  local out="[" first=1 item
  IFS=',' read -r -a _arr <<<"$csv"
  for item in "${_arr[@]}"; do
    [ -z "$item" ] && continue
    local esc; esc=$(_json_escape "$item")
    if [ "$first" = 1 ]; then out="$out\"$esc\""; first=0
    else out="$out,\"$esc\""; fi
  done
  out="$out]"
  echo "$out"
}

_render_workflow_json() {
  local name="$1" file="$2"
  local desc; desc=$(_yaml_description "$file")
  local desc_esc; desc_esc=$(_json_escape "$desc")

  printf '{\n'
  printf '  "workflow": "%s",\n' "$name"
  printf '  "schema_version": 1,\n'
  printf '  "description": "%s",\n' "$desc_esc"

  local total_tokens=0 total_wall=0 files_w_count=0 files_m_count=0
  local phase_json="" first=1
  local phase_count=0

  while IFS="$SEP" read -r id name_ goal spawn prompt artifact command gate \
        in_ fw fm dep commit toks wall; do
    [ -z "$id" ] && continue
    phase_count=$((phase_count + 1))
    total_tokens=$((total_tokens + ${toks:-0}))
    total_wall=$((total_wall + ${wall:-0}))
    files_w_count=$((files_w_count + $(_count_csv "$fw")))
    files_m_count=$((files_m_count + $(_count_csv "$fm")))

    local commit_bool="false"
    case "$commit" in true|True|TRUE|yes|1) commit_bool="true" ;; esac

    local one=""
    one+=$(printf '    {\n')
    one+=$'\n'
    one+=$(printf '      "id": "%s",\n' "$(_json_escape "$id")")
    one+=$'\n'
    one+=$(printf '      "name": "%s",\n' "$(_json_escape "$name_")")
    one+=$'\n'
    one+=$(printf '      "goal": "%s",\n' "$(_json_escape "$goal")")
    one+=$'\n'
    one+=$(printf '      "spawn_type": "%s",\n' "$(_json_escape "$spawn")")
    one+=$'\n'
    one+=$(printf '      "prompt": "%s",\n' "$(_json_escape "$prompt")")
    one+=$'\n'
    one+=$(printf '      "artifact": "%s",\n' "$(_json_escape "$artifact")")
    one+=$'\n'
    one+=$(printf '      "command": "%s",\n' "$(_json_escape "$command")")
    one+=$'\n'
    one+=$(printf '      "gate": "%s",\n' "$(_json_escape "$gate")")
    one+=$'\n'
    one+=$(printf '      "inputs": %s,\n' "$(_json_array "$in_")")
    one+=$'\n'
    one+=$(printf '      "files_written": %s,\n' "$(_json_array "$fw")")
    one+=$'\n'
    one+=$(printf '      "files_modified": %s,\n' "$(_json_array "$fm")")
    one+=$'\n'
    one+=$(printf '      "depends_on": %s,\n' "$(_json_array "$dep")")
    one+=$'\n'
    one+=$(printf '      "estimated_tokens": %d,\n' "${toks:-0}")
    one+=$'\n'
    one+=$(printf '      "estimated_wall_clock_min": %d,\n' "${wall:-0}")
    one+=$'\n'
    one+=$(printf '      "commit_required": %s\n' "$commit_bool")
    one+=$'\n'
    one+=$(printf '    }')

    if [ "$first" = 1 ]; then phase_json="$one"; first=0
    else phase_json="$phase_json,"$'\n'"$one"
    fi
  done < <(_parse_workflow_phases "$file")

  printf '  "phase_count": %d,\n' "$phase_count"
  printf '  "phases": [\n'
  printf '%s\n' "$phase_json"
  printf '  ],\n'

  local hours; hours=$(_hours_from_min "$total_wall")
  local cost; cost=$(_cost_usd "$total_tokens")
  printf '  "totals": {\n'
  printf '    "phase_count": %d,\n' "$phase_count"
  printf '    "files_modified": %d,\n' "$files_m_count"
  printf '    "files_written": %d,\n' "$files_w_count"
  printf '    "estimated_tokens_total": %d,\n' "$total_tokens"
  printf '    "estimated_hours": %s,\n' "$hours"
  printf '    "estimated_cost_usd": %s\n' "$cost"
  printf '  }\n'
  printf '}\n'
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase drill-down (--phase <id>)
# ─────────────────────────────────────────────────────────────────────────────

_render_one_phase() {
  local kind="$1" file="$2" target_id="$3"
  local parser
  if [ "$kind" = "workflow" ]; then parser=_parse_workflow_phases
  else parser=_parse_plan_phases
  fi

  local found=0
  while IFS="$SEP" read -r id name_ goal spawn prompt artifact command gate \
        in_ fw fm dep commit toks wall; do
    [ "$id" = "$target_id" ] || continue
    found=1
    _render_phase_block \
      "$id" "$name_" "$goal" "$spawn" \
      "$prompt" "$artifact" "$command" "$gate" \
      "$in_" "$fw" "$fm" \
      "$dep" "$commit" "$toks" "$wall"
    break
  done < <("$parser" "$file")

  if [ "$found" = 0 ]; then
    echo "psk-preview: phase '$target_id' not found in $file" >&2
    exit 2
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# CLI dispatch
# ─────────────────────────────────────────────────────────────────────────────

main() {
  if [ $# -eq 0 ]; then _usage; exit 1; fi

  # Flag-only forms
  case "$1" in
    -h|--help) _usage; exit 0 ;;
    --list-workflows) _list_workflows; exit 0 ;;
    --list-plans) _list_plans; exit 0 ;;
  esac

  # Subcommand: plan <slug> [...]
  local mode="workflow"
  local target=""
  local target_file=""
  if [ "$1" = "plan" ]; then
    [ $# -ge 2 ] || _die_usage "plan subcommand requires <slug>"
    mode="plan"
    target="$2"
    shift 2
    target_file=$(_resolve_plan_file "$target")
    [ -z "$target_file" ] && _die "plan not found: $target (looked under $PLANS_DIR)"
    _plan_has_phases "$target_file" || _die "plan $target has no phases: frontmatter (narrative-only plan)"
  else
    target="$1"
    shift
    target_file="$WORKFLOWS_DIR/$target/phases.yml"
    if [ ! -f "$target_file" ]; then
      local avail
      avail=$(_list_workflows 2>/dev/null | tr '\n' ' ')
      echo "psk-preview: workflow '$target' not found." >&2
      echo "Available: $avail" >&2
      exit 2
    fi
  fi

  # Parse remaining flags
  local action="full" phase_id=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --phase)
        [ $# -ge 2 ] || _die_usage "--phase requires <id>"
        action="phase"; phase_id="$2"; shift 2 ;;
      --graph) action="graph"; shift ;;
      --json) action="json"; shift ;;
      -h|--help) _usage; exit 0 ;;
      *) _die_usage "unknown option: $1" ;;
    esac
  done

  case "$action" in
    full)
      if [ "$mode" = "workflow" ]; then _render_workflow_human "$target" "$target_file"
      else _render_plan_human "$target" "$target_file"
      fi
      ;;
    phase)
      _render_one_phase "$mode" "$target_file" "$phase_id"
      ;;
    graph)
      _render_graph_detailed "$target_file" "$mode"
      ;;
    json)
      if [ "$mode" = "workflow" ]; then _render_workflow_json "$target" "$target_file"
      else
        # Plan-JSON: emit minimal-shape JSON (reuse workflow shape with mapped fields)
        _render_workflow_json "$target" "$target_file"
      fi
      ;;
  esac
}

main "$@"
