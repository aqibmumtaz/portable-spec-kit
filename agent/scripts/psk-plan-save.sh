#!/bin/bash
# mechanical-script: psk-plan-save.sh — plan persistence + schema validation (no AI invocation)
# psk-plan-save.sh — Persist conversation-drafted plans to agent/plans/
#
# Plans drafted in chat live in IDE-local ephemeral storage and are lost on
# context switch. This script saves them to agent/plans/YYYY-MM-DD-<slug>.md
# with lifecycle frontmatter (draft → approved → executing → done) so any
# interruption point leaves the latest plan state on disk and in git history.
#
# Usage:
#   psk-plan-save.sh save <slug> [<file>|-]        # draft (creates or rewrites)
#   psk-plan-save.sh approve <slug>                 # draft → approved (schema-validated)
#   psk-plan-save.sh start <slug>                   # approved → executing
#   psk-plan-save.sh done <slug> [<sha-range>]      # executing → done
#   psk-plan-save.sh abandon <slug> [reason]        # any → abandoned
#   psk-plan-save.sh list                           # show all plans with status
#   psk-plan-save.sh show <slug>                    # print plan file path
#   psk-plan-save.sh --validate-schema <slug>       # one-shot schema lint (no side effects)
#
# Schema validation (B0.3, v0.6.57-pre): `approve` runs PSK024 schema validation
# against the plan's `phases:` frontmatter before flipping status to approved.
# Error codes:
#   PSK024-N: missing `schema_version` field (must be integer)
#   PSK024-P: missing `phases:` array (or empty)
#   PSK024-F: phase missing required field (id, name, prompt, artifact, gate)
#   PSK024-D: phase `depends_on:` references nonexistent phase id
#   PSK024-L: phase prompt/artifact path violates canonical layout
# Bypass: PSK_PLAN_EXEC_DISABLED=1 skips schema validation with stderr warning.
# Compat-mode (frontmatter sets `compat_mode: true` and has no `phases:`)
# bypasses schema validation — one-shot run allowed before conversion.
#
# Body-preservation (B0.3, v0.6.57-pre): `save` writes frontmatter via tempfile
# and preserves the markdown body byte-for-byte. Only the `updated:` field is
# refreshed on re-save; every other frontmatter key (multi-line values, arrays,
# nested keys, revision_history, etc.) round-trips intact. When called with no
# stdin AND no source AND an existing plan, save acts as a no-op refresh of
# only the `updated:` field — the body is read from the existing file verbatim.

set -eo pipefail   # -e: exit on error; -o pipefail: catch failures through pipes too

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PLANS_DIR="$PROJ_ROOT/agent/plans"
TODAY="$(date +%Y-%m-%d)"

mkdir -p "$PLANS_DIR"

_find_plan_file() {
  local slug="$1"
  local f
  f=$(ls -1 "$PLANS_DIR"/*-"$slug".md 2>/dev/null | head -1)
  [ -z "$f" ] && f=$(ls -1 "$PLANS_DIR"/"$slug".md 2>/dev/null | head -1)
  echo "$f"
}

# _read_frontmatter_field — single-line top-level field reader.
# Skips multi-line values and indented nested keys.
_read_frontmatter_field() {
  local file="$1" field="$2"
  awk -v fld="$field" '
    BEGIN { fm = 0 }
    /^---$/ { fm++; next }
    fm == 1 && $0 ~ "^"fld":" {
      sub(/^[^:]+:[[:space:]]*/, "")
      print
      exit
    }
    fm >= 2 { exit }
  ' "$file"
}

# _split_frontmatter — extracts frontmatter (between two `---` lines) and body
# (everything after the closing `---`) to two tempfiles. Echoes the two paths.
# If file has no frontmatter, frontmatter tempfile is empty.
_split_frontmatter() {
  local file="$1"
  local fm_tmp body_tmp
  fm_tmp=$(mktemp)
  body_tmp=$(mktemp)
  awk -v fm_out="$fm_tmp" -v body_out="$body_tmp" '
    BEGIN { fm = 0 }
    /^---$/ {
      fm++
      if (fm == 1) next
      if (fm == 2) next
    }
    fm == 1 { print > fm_out; next }
    fm >= 2 { print > body_out; next }
    fm == 0 { print > body_out; next }
  ' "$file"
  echo "$fm_tmp"
  echo "$body_tmp"
}

# _rewrite_frontmatter — rewrite frontmatter tempfile so that:
#   - `updated:` is set to today's date (added if missing)
#   - if new_status is non-empty, `status:` is set (added if missing)
#   - if extra_key/extra_val are non-empty, that key is set (added if missing)
#   - every other line is preserved byte-for-byte
# The output is the new frontmatter content written to stdout.
_rewrite_frontmatter() {
  local fm_file="$1" new_status="$2" today="$3" extra_key="${4:-}" extra_val="${5:-}"
  awk -v new_status="$new_status" -v today="$today" -v extra_key="$extra_key" -v extra_val="$extra_val" '
    BEGIN {
      wrote_status = 0
      wrote_updated = 0
      wrote_extra = 0
      in_multiline = 0
      multiline_indent = 0
    }
    # Detect top-level key (no leading whitespace, contains `:`)
    function is_top_level_key(line,  re) {
      return (line ~ /^[A-Za-z_][A-Za-z0-9_]*:/)
    }
    {
      line = $0
      # Multi-line block-scalar continuation (lines indented under a `key: |`)
      if (in_multiline) {
        if (line ~ /^[[:space:]]/ || line == "") {
          print line
          next
        }
        in_multiline = 0
      }
      # YAML array item or nested key under a parent (indented line)
      if (line ~ /^[[:space:]]/) {
        print line
        next
      }
      # Top-level key line
      if (line ~ /^updated:/) {
        print "updated: " today
        wrote_updated = 1
        next
      }
      if (new_status != "" && line ~ /^status:/) {
        print "status: " new_status
        wrote_status = 1
        next
      }
      if (extra_key != "" && line ~ "^"extra_key":") {
        print extra_key ": " extra_val
        wrote_extra = 1
        next
      }
      # Detect start of multi-line block scalar value
      if (line ~ /:[[:space:]]*[|>]/) {
        print line
        in_multiline = 1
        next
      }
      print line
    }
    END {
      # Status takes precedence — write before updated for stable ordering when both new
      if (new_status != "" && !wrote_status) {
        print "status: " new_status
      }
      if (!wrote_updated) {
        print "updated: " today
      }
      if (extra_key != "" && !wrote_extra) {
        print extra_key ": " extra_val
      }
    }
  ' "$fm_file"
}

# _write_plan — assemble plan file from frontmatter tempfile + body tempfile.
# Output format: `---\n<frontmatter>\n---\n<body>` exactly.
_write_plan() {
  local out_file="$1" fm_file="$2" body_file="$3"
  local tmp; tmp=$(mktemp)
  {
    echo "---"
    cat "$fm_file"
    echo "---"
    cat "$body_file"
  } > "$tmp"
  mv "$tmp" "$out_file"
}

# _frontmatter_has — does the frontmatter tempfile contain a top-level key?
_frontmatter_has() {
  local fm_file="$1" key="$2"
  grep -qE "^${key}:" "$fm_file"
}

# _transition_status — change status in an existing plan file, preserving body
# byte-for-byte. Optionally inject one extra top-level key (e.g. commits).
_transition_status() {
  local file="$1" new_status="$2" extra_key="${3:-}" extra_val="${4:-}"
  local pair fm_tmp body_tmp
  pair=$(_split_frontmatter "$file")
  fm_tmp=$(echo "$pair" | sed -n '1p')
  body_tmp=$(echo "$pair" | sed -n '2p')

  local new_fm_tmp; new_fm_tmp=$(mktemp)
  _rewrite_frontmatter "$fm_tmp" "$new_status" "$TODAY" "$extra_key" "$extra_val" > "$new_fm_tmp"
  # If `status:` was never in original frontmatter, prepend it for clarity
  if ! _frontmatter_has "$new_fm_tmp" "status"; then
    local tmp; tmp=$(mktemp)
    { echo "status: $new_status"; cat "$new_fm_tmp"; } > "$tmp"
    mv "$tmp" "$new_fm_tmp"
  fi

  _write_plan "$file" "$new_fm_tmp" "$body_tmp"
  rm -f "$fm_tmp" "$body_tmp" "$new_fm_tmp"
}

# _build_initial_frontmatter — for a brand new plan with no caller-supplied
# frontmatter, build a minimal frontmatter tempfile and echo its path.
_build_initial_frontmatter() {
  local slug="$1" status="$2" created="$3" updated="$4"
  local fm_tmp; fm_tmp=$(mktemp)
  {
    echo "status: $status"
    echo "slug: $slug"
    echo "created: $created"
    echo "updated: $updated"
  } > "$fm_tmp"
  echo "$fm_tmp"
}

# _has_frontmatter — does a tempfile start with `---`?
_body_starts_with_frontmatter() {
  local body_file="$1"
  [ -s "$body_file" ] && head -n 1 "$body_file" | grep -q '^---$'
}

cmd_save() {
  local slug="$1" src="${2:-}"
  [ -z "$slug" ] && { echo "usage: psk-plan-save.sh save <slug> [<file>|-]" >&2; exit 2; }
  # QA-D2-P5-001 (POSIX filename safety; §Plan Execution Protocol — plan slug must
  # be kebab-case): the slug becomes a filename component (YYYY-MM-DD-<slug>.md)
  # and is later matched with shell globs in _find_plan_file. A slug with spaces
  # or special characters produced a malformed, glob-fragile filename and was
  # accepted silently (exit 0). Reject anything that is not lowercase
  # kebab-case before creating the file.
  if [[ ! "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "slug must be kebab-case (lowercase letters, digits, single hyphens): '$slug'" >&2
    exit 2
  fi

  local file; file=$(_find_plan_file "$slug")
  local is_new=0
  if [ -z "$file" ]; then
    file="$PLANS_DIR/${TODAY}-${slug}.md"
    is_new=1
  fi

  # Determine the body source
  # - explicit file arg → read from file
  # - explicit "-" arg → read from stdin
  # - no arg AND stdin is not a tty → read from stdin
  # - no arg AND stdin IS a tty AND existing plan → preserve existing body verbatim
  # - no arg AND stdin IS a tty AND new plan → empty body (will create stub)
  local input_tmp; input_tmp=$(mktemp)
  if [ -n "$src" ] && [ "$src" != "-" ]; then
    [ ! -f "$src" ] && { echo "source file not found: $src" >&2; exit 1; }
    cat "$src" > "$input_tmp"
  elif [ "$src" = "-" ]; then
    cat > "$input_tmp"
  elif [ ! -t 0 ]; then
    # No explicit src; stdin is a pipe — consume it
    cat > "$input_tmp"
  else
    # No src, stdin is a tty (interactive). For existing plans this is a
    # refresh-only call; for new plans we use empty body.
    : > "$input_tmp"
  fi

  if [ "$is_new" -eq 1 ] && [ ! -s "$input_tmp" ] && [ -z "$src" ] && [ -t 0 ]; then
    echo "save: no plan body provided for new plan ($slug). Pass a file, pipe stdin, or use '-'." >&2
    rm -f "$input_tmp"
    exit 2
  fi

  # If there's no caller-supplied content AND an existing plan exists, this is
  # a pure refresh — preserve existing frontmatter and body byte-for-byte,
  # refresh only `updated:`.
  if [ "$is_new" -eq 0 ] && [ ! -s "$input_tmp" ]; then
    rm -f "$input_tmp"
    local pair fm_tmp body_tmp
    pair=$(_split_frontmatter "$file")
    fm_tmp=$(echo "$pair" | sed -n '1p')
    body_tmp=$(echo "$pair" | sed -n '2p')
    local new_fm_tmp; new_fm_tmp=$(mktemp)
    _rewrite_frontmatter "$fm_tmp" "" "$TODAY" "" "" > "$new_fm_tmp"
    _write_plan "$file" "$new_fm_tmp" "$body_tmp"
    rm -f "$fm_tmp" "$body_tmp" "$new_fm_tmp"
    local cur_status; cur_status=$(_read_frontmatter_field "$file" status)
    echo "saved: $file (status=${cur_status:-draft}, refresh-only)"
    return 0
  fi

  # Caller supplied content — body may or may not include its own frontmatter.
  local supplied_fm_tmp supplied_body_tmp
  supplied_fm_tmp=$(mktemp)
  supplied_body_tmp=$(mktemp)
  if _body_starts_with_frontmatter "$input_tmp"; then
    # Caller provided frontmatter + body — split them
    local pair
    pair=$(_split_frontmatter "$input_tmp")
    rm -f "$supplied_fm_tmp" "$supplied_body_tmp"
    supplied_fm_tmp=$(echo "$pair" | sed -n '1p')
    supplied_body_tmp=$(echo "$pair" | sed -n '2p')
  else
    # Caller provided body only — frontmatter is empty
    cat "$input_tmp" > "$supplied_body_tmp"
  fi
  rm -f "$input_tmp"

  if [ "$is_new" -eq 1 ]; then
    # New plan — use supplied frontmatter if any, else build minimal
    local fm_to_use
    if [ -s "$supplied_fm_tmp" ]; then
      fm_to_use="$supplied_fm_tmp"
      # Ensure mandatory fields (slug, created, status) are present
      if ! _frontmatter_has "$fm_to_use" "slug"; then
        local tmp; tmp=$(mktemp); { echo "slug: $slug"; cat "$fm_to_use"; } > "$tmp"; mv "$tmp" "$fm_to_use"
      fi
      if ! _frontmatter_has "$fm_to_use" "created"; then
        local tmp; tmp=$(mktemp); { echo "created: $TODAY"; cat "$fm_to_use"; } > "$tmp"; mv "$tmp" "$fm_to_use"
      fi
      if ! _frontmatter_has "$fm_to_use" "status"; then
        local tmp; tmp=$(mktemp); { echo "status: draft"; cat "$fm_to_use"; } > "$tmp"; mv "$tmp" "$fm_to_use"
      fi
    else
      fm_to_use=$(_build_initial_frontmatter "$slug" "draft" "$TODAY" "$TODAY")
    fi
    # Always refresh updated:
    local new_fm_tmp; new_fm_tmp=$(mktemp)
    _rewrite_frontmatter "$fm_to_use" "" "$TODAY" "" "" > "$new_fm_tmp"
    _write_plan "$file" "$new_fm_tmp" "$supplied_body_tmp"
    rm -f "$fm_to_use" "$new_fm_tmp"
    local cur_status; cur_status=$(_read_frontmatter_field "$file" status)
    echo "saved: $file (status=${cur_status:-draft})"
  else
    # Existing plan — merge caller content with existing lifecycle state.
    # Strategy:
    #  - If caller supplied frontmatter: use caller's frontmatter as the base,
    #    but inject preserved lifecycle fields (status, created, commits,
    #    abandon_reason) from the existing plan when caller didn't include them.
    #  - If caller didn't supply frontmatter: keep existing frontmatter intact.
    #  - Always refresh `updated:`.
    local existing_pair existing_fm_tmp existing_body_tmp
    existing_pair=$(_split_frontmatter "$file")
    existing_fm_tmp=$(echo "$existing_pair" | sed -n '1p')
    existing_body_tmp=$(echo "$existing_pair" | sed -n '2p')

    local fm_to_use
    if [ -s "$supplied_fm_tmp" ]; then
      fm_to_use="$supplied_fm_tmp"
      # Preserve lifecycle fields the caller may have dropped
      for key in status created commits abandon_reason slug; do
        if ! _frontmatter_has "$fm_to_use" "$key"; then
          local val
          val=$(_read_frontmatter_field "$file" "$key")
          if [ -n "$val" ]; then
            local tmp; tmp=$(mktemp); { echo "$key: $val"; cat "$fm_to_use"; } > "$tmp"; mv "$tmp" "$fm_to_use"
          fi
        fi
      done
    else
      fm_to_use="$existing_fm_tmp"
    fi

    local new_fm_tmp; new_fm_tmp=$(mktemp)
    _rewrite_frontmatter "$fm_to_use" "" "$TODAY" "" "" > "$new_fm_tmp"
    # Determine body: caller's body if supplied, else preserved existing body
    local body_to_use
    if [ -s "$supplied_body_tmp" ]; then
      body_to_use="$supplied_body_tmp"
    else
      body_to_use="$existing_body_tmp"
    fi
    _write_plan "$file" "$new_fm_tmp" "$body_to_use"
    rm -f "$existing_fm_tmp" "$existing_body_tmp" "$new_fm_tmp"
    [ "$fm_to_use" != "$supplied_fm_tmp" ] || rm -f "$supplied_fm_tmp"
    local cur_status; cur_status=$(_read_frontmatter_field "$file" status)
    echo "saved: $file (status=${cur_status:-draft})"
  fi
  rm -f "$supplied_fm_tmp" "$supplied_body_tmp" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Schema validation (PSK024) — for `approve` and `--validate-schema`
# ---------------------------------------------------------------------------

# _validate_schema — read a plan file's frontmatter, validate executable-plan
# schema. Echoes PSK024-* error lines on stderr, returns 0 on valid / 2 on
# invalid. Compat-mode plans (`compat_mode: true` and no `phases:`) are valid.
_validate_schema() {
  local file="$1"
  local errors=0

  # Compat-mode bypass
  local compat
  compat=$(_read_frontmatter_field "$file" compat_mode)
  # has_phases: yes iff a `phases:` top-level key appears INSIDE the
  # frontmatter (between the two `---` lines). A `phases:` token elsewhere
  # in the body must NOT register, otherwise narrative plans that mention
  # `phases:` in prose would be misclassified as executable.
  local has_phases="no"
  if awk '
    BEGIN { fm = 0; found = 0 }
    /^---$/ { fm++; if (fm >= 2) { exit (found ? 0 : 1) } next }
    fm == 1 && /^phases:/ { found = 1; exit 0 }
    END { exit (found ? 0 : 1) }
  ' "$file"; then
    has_phases="yes"
  fi

  if [ "$compat" = "true" ] && [ "$has_phases" = "no" ]; then
    return 0
  fi

  # PSK024-N — schema_version present and integer
  local schema_version
  schema_version=$(_read_frontmatter_field "$file" schema_version)
  if [ -z "$schema_version" ]; then
    echo "PSK024-N: missing 'schema_version' field in frontmatter (required integer)" >&2
    errors=$((errors + 1))
  elif ! echo "$schema_version" | grep -qE '^[0-9]+$'; then
    echo "PSK024-N: 'schema_version' must be an integer (got: '$schema_version')" >&2
    errors=$((errors + 1))
  fi

  # PSK024-P — phases: array present and non-empty
  if [ "$has_phases" = "no" ]; then
    echo "PSK024-P: missing 'phases:' array in frontmatter" >&2
    errors=$((errors + 1))
    return 2
  fi

  # Parse phases array into a list of (id, has_name, has_prompt, has_artifact,
  # has_gate, depends_on, prompt_path, artifact_path) records using awk.
  local phases_tmp; phases_tmp=$(mktemp)
  awk '
    BEGIN { fm = 0; in_phases = 0; cur_id = ""; in_depends_inline = 0 }
    /^---$/ { fm++; if (fm >= 2) { if (cur_id != "") print_phase(); exit } next }
    fm != 1 { next }
    # Detect entering phases:
    /^phases:[[:space:]]*$/ { in_phases = 1; next }
    # Other top-level key while in phases means phases block ended
    /^[A-Za-z_][A-Za-z0-9_]*:/ && in_phases == 1 {
      if (cur_id != "") print_phase()
      cur_id = ""
      in_phases = 0
      next
    }
    in_phases == 1 {
      line = $0
      # New phase: `  - id: <value>`
      if (line ~ /^[[:space:]]*-[[:space:]]+id:/) {
        if (cur_id != "") print_phase()
        cur_id = line
        sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, "", cur_id)
        gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", cur_id)
        has_name = 0; has_prompt = 0; has_artifact = 0; has_gate = 0
        depends_on = ""; prompt_path = ""; artifact_path = ""
        next
      }
      if (cur_id == "") next
      if (line ~ /^[[:space:]]+name:/) { has_name = 1; next }
      if (line ~ /^[[:space:]]+prompt:/) {
        has_prompt = 1
        v = line
        sub(/^[[:space:]]+prompt:[[:space:]]*/, "", v)
        gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", v)
        prompt_path = v
        next
      }
      if (line ~ /^[[:space:]]+artifact:/) {
        has_artifact = 1
        v = line
        sub(/^[[:space:]]+artifact:[[:space:]]*/, "", v)
        gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", v)
        artifact_path = v
        next
      }
      if (line ~ /^[[:space:]]+gate:/) { has_gate = 1; next }
      if (line ~ /^[[:space:]]+depends_on:[[:space:]]*\[/) {
        v = line
        sub(/^[[:space:]]+depends_on:[[:space:]]*\[/, "", v)
        sub(/\].*$/, "", v)
        gsub(/[[:space:]"'\'']/, "", v)
        depends_on = v
        next
      }
    }
    function print_phase() {
      printf("%s|%d|%d|%d|%d|%s|%s|%s\n", cur_id, has_name, has_prompt, has_artifact, has_gate, depends_on, prompt_path, artifact_path)
    }
    END {
      if (cur_id != "" && in_phases == 1) print_phase()
    }
  ' "$file" > "$phases_tmp"

  local phase_count
  phase_count=$(wc -l < "$phases_tmp" | tr -d ' ')
  if [ "$phase_count" -eq 0 ]; then
    echo "PSK024-P: 'phases:' array is empty (must contain at least one phase)" >&2
    errors=$((errors + 1))
    rm -f "$phases_tmp"
    return 2
  fi

  # Collect all phase IDs for depends_on validation
  local all_ids
  all_ids=$(awk -F'|' '{print $1}' "$phases_tmp" | tr '\n' ' ')

  # Slug — derive from filename for path validation
  local slug
  slug=$(_read_frontmatter_field "$file" slug)
  [ -z "$slug" ] && slug=$(basename "$file" .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')

  # Per-phase checks: PSK024-F (required fields) + PSK024-D (deps) + PSK024-L (layout)
  while IFS='|' read -r pid has_name has_prompt has_artifact has_gate deps prompt_path artifact_path; do
    [ -z "$pid" ] && continue
    if [ "$has_name" != "1" ]; then
      echo "PSK024-F: phase $pid missing 'name' field" >&2
      errors=$((errors + 1))
    fi
    if [ "$has_prompt" != "1" ]; then
      echo "PSK024-F: phase $pid missing 'prompt' field" >&2
      errors=$((errors + 1))
    fi
    if [ "$has_artifact" != "1" ]; then
      echo "PSK024-F: phase $pid missing 'artifact' field" >&2
      errors=$((errors + 1))
    fi
    if [ "$has_gate" != "1" ]; then
      echo "PSK024-F: phase $pid missing 'gate' field" >&2
      errors=$((errors + 1))
    fi
    # PSK024-D — every dep must reference an existing phase id
    if [ -n "$deps" ]; then
      IFS=',' read -ra dep_arr <<< "$deps"
      for dep in "${dep_arr[@]}"; do
        [ -z "$dep" ] && continue
        if ! echo " $all_ids " | grep -qE " $dep "; then
          echo "PSK024-D: phase $pid 'depends_on: [$dep]' references nonexistent phase id" >&2
          errors=$((errors + 1))
        fi
      done
    fi
    # PSK024-L — canonical layout for prompt/artifact paths
    if [ -n "$prompt_path" ]; then
      local expected_prompt_prefix="agent/plans/${slug}/prompts/"
      if ! echo "$prompt_path" | grep -qE "^${expected_prompt_prefix}.+\.md$"; then
        echo "PSK024-L: phase $pid prompt path '$prompt_path' violates canonical layout (expected: ${expected_prompt_prefix}<id>.md)" >&2
        errors=$((errors + 1))
      fi
    fi
    if [ -n "$artifact_path" ]; then
      local expected_artifact_prefix="agent/plans/${slug}/artifacts/"
      if ! echo "$artifact_path" | grep -qE "^${expected_artifact_prefix}.+\.done\.md$"; then
        echo "PSK024-L: phase $pid artifact path '$artifact_path' violates canonical layout (expected: ${expected_artifact_prefix}<id>.done.md)" >&2
        errors=$((errors + 1))
      fi
    fi
  done < "$phases_tmp"

  rm -f "$phases_tmp"

  if [ "$errors" -gt 0 ]; then
    return 2
  fi
  return 0
}

cmd_validate_schema() {
  local slug="$1"
  [ -z "$slug" ] && { echo "usage: psk-plan-save.sh --validate-schema <slug>" >&2; exit 2; }
  local file; file=$(_find_plan_file "$slug")
  [ -z "$file" ] && { echo "plan not found for slug: $slug" >&2; exit 1; }
  if _validate_schema "$file"; then
    echo "schema-ok: $file"
    return 0
  else
    echo "schema-invalid: $file" >&2
    exit 2
  fi
}

cmd_approve() {
  local slug="$1"
  [ -z "$slug" ] && { echo "usage: psk-plan-save.sh approve <slug>" >&2; exit 2; }
  local file; file=$(_find_plan_file "$slug")
  [ -z "$file" ] && { echo "plan not found for slug: $slug" >&2; exit 1; }

  if [ "${PSK_PLAN_EXEC_DISABLED:-0}" = "1" ]; then
    # HF9 (v0.6.60): durable bypass-tamper audit trail.
    _bypass_log_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/psk-bypass-log.sh"
    if [ -x "$_bypass_log_script" ]; then
      bash "$_bypass_log_script" log \
        --env-var "PSK_PLAN_EXEC_DISABLED" \
        --command "psk-plan-save.sh approve $slug" \
        --justification "${PSK_BYPASS_REASON:-not provided}" 2>/dev/null || true
    fi
    echo "WARNING: PSK_PLAN_EXEC_DISABLED=1 — skipping schema validation on approve" >&2
  else
    if ! _validate_schema "$file"; then
      echo "approve refused: $file failed PSK024 schema validation (see errors above)" >&2
      echo "Hint: see .portable-spec-kit/templates/plan-executable.md for the required schema." >&2
      echo "      Bypass for emergencies: PSK_PLAN_EXEC_DISABLED=1 bash $0 approve $slug" >&2
      exit 2
    fi
  fi

  _transition_status "$file" "approved" "" ""
  echo "transitioned: $file (status=approved)"
}

cmd_transition() {
  local new_status="$1" slug="$2" extra="${3:-}"
  [ -z "$slug" ] && { echo "usage: psk-plan-save.sh $new_status <slug>" >&2; exit 2; }
  local file; file=$(_find_plan_file "$slug")
  [ -z "$file" ] && { echo "plan not found for slug: $slug" >&2; exit 1; }

  if [ "$new_status" = "done" ] && [ -n "$extra" ]; then
    _transition_status "$file" "$new_status" "commits" "$extra"
  elif [ "$new_status" = "abandoned" ] && [ -n "$extra" ]; then
    _transition_status "$file" "$new_status" "abandon_reason" "\"$extra\""
  else
    _transition_status "$file" "$new_status" "" ""
  fi

  echo "transitioned: $file (status=$new_status)"
}

cmd_list() {
  if [ ! -d "$PLANS_DIR" ] || [ -z "$(ls -1 "$PLANS_DIR"/*.md 2>/dev/null)" ]; then
    echo "No plans saved yet."
    return 0
  fi
  printf '%-40s %-12s %s\n' "PLAN" "STATUS" "FILE"
  printf '%-40s %-12s %s\n' "----" "------" "----"
  for f in "$PLANS_DIR"/*.md; do
    local slug status
    slug=$(_read_frontmatter_field "$f" slug)
    [ -z "$slug" ] && slug=$(basename "$f" .md)
    status=$(_read_frontmatter_field "$f" status)
    [ -z "$status" ] && status="(no frontmatter)"
    printf '%-40s %-12s %s\n' "$slug" "$status" "${f#$PROJ_ROOT/}"
  done
}

cmd_show() {
  local slug="$1"
  [ -z "$slug" ] && { echo "usage: psk-plan-save.sh show <slug>" >&2; exit 2; }
  local file; file=$(_find_plan_file "$slug")
  [ -z "$file" ] && { echo "plan not found for slug: $slug" >&2; exit 1; }
  echo "$file"
}

case "${1:-}" in
  save)              shift; cmd_save "$@" ;;
  approve)           shift; cmd_approve "$@" ;;
  start)             shift; cmd_transition executing "$@" ;;
  done)              shift; cmd_transition done "$@" ;;
  abandon)           shift; cmd_transition abandoned "$@" ;;
  list)              cmd_list ;;
  show)              shift; cmd_show "$@" ;;
  --validate-schema) shift; cmd_validate_schema "$@" ;;
  -h|--help|"")
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "unknown subcommand: $1" >&2
    echo "run with --help for usage" >&2
    exit 2
    ;;
esac
