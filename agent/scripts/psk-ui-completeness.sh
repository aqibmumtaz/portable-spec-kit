#!/usr/bin/env bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist — v0.6.60 HF7b)
# psk-ui-completeness.sh — Stack-aware UI completeness audit (Phase B1 of workflow-fidelity plan, v0.6.57+).
#
# Prevents the v5-skeletal-UI failure: when project Stack table declares a
# frontend framework, the UI must meet a measurable completeness bar before
# workflows can mark "done". Empty-shell pages (the v5 signature) are flagged.
#
# Stack detection from agent/PLANS.md Stack table. No frontend → skip cleanly.
#
# 10 check categories, sub-codes (P L D S A T F I R E):
#   P primitives    — ≥12 of: button/input/textarea/select/checkbox/radio/card/
#                      modal/toast/tabs/badge/avatar/dropdown/menu/dialog
#   L layout        — 4-of-5 of: header/nav/footer/sidebar/container
#   D dark-mode     — any of: useTheme(, data-theme, dark: ≥20, --bg/--fg, prefers-color-scheme
#   S states        — every page has loading/empty/error scaffolding
#   A a11y          — aria-label ≥10, role= ≥5, no native dialogs
#   T tokens        — tailwind colors:, tokens.ts, OR :root with ≥6 --vars
#   F per-feature   — every [x] feature with UI keyword has a page file
#   I input-fb      — ≥5 inputs with associated error messaging
#   R responsive    — sm:|md:|lg:|xl: ≥10 OR @media ≥3 OR Platform.
#   E empty-shell   — flag page files with TODO body or <20 LOC
#
# Commands:
#   psk-ui-completeness.sh             — full audit, exit 0 clean | 1 violations
#   psk-ui-completeness.sh --check     — advisory, exit 0 always
#   psk-ui-completeness.sh --strict    — exit 1 on any violation
#   psk-ui-completeness.sh --json      — machine-readable
#   psk-ui-completeness.sh --feature F — single-feature page-presence check
#
# Bypass: PSK_UI_COMPLETENESS_DISABLED=1 short-circuits to exit 0.

set -uo pipefail

MODE="default"
FEATURE=""
JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check)   MODE="check"; shift ;;
    --strict)  MODE="strict"; shift ;;
    --json)    JSON=1; shift ;;
    --feature) FEATURE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,/^$/p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

PROJ_ROOT="${PSK_PROJ_ROOT:-$(pwd)}"
cd "$PROJ_ROOT" || exit 2

if [ "${PSK_UI_COMPLETENESS_DISABLED:-0}" = "1" ]; then
  [ $JSON -eq 1 ] && echo '{"rule":"PSK025","skipped":"PSK_UI_COMPLETENESS_DISABLED=1"}'
  [ $JSON -eq 0 ] && echo "PSK025: skipped (PSK_UI_COMPLETENESS_DISABLED=1)"
  exit 0
fi

# --- Stack detection ---
detect_stack() {
  local plans="agent/PLANS.md"
  # Prefer package.json — strongest signal
  if [ -f "package.json" ]; then
    local pkg; pkg=$(cat package.json 2>/dev/null)
    if echo "$pkg" | grep -qE '"(next|react|vue|svelte|@sveltejs/kit|vite|nuxt|remix|astro|expo|react-native)"\s*:'; then
      echo "$pkg" | grep -oE '"(next|sveltekit|svelte|nuxt|remix|astro|expo|react-native|vue|vite|react)"\s*:' | head -1 | sed 's/[":]*//g; s/ //g' | head -1 | tr '[:upper:]' '[:lower:]'
      return
    fi
  fi
  # Fallback: agent/PLANS.md Stack TABLE only (between ## Stack and next ##)
  [ -f "$plans" ] || { echo ""; return; }
  local stack_section; stack_section=$(awk '/^## Stack[[:space:]]*$/{flag=1; next} /^## /{flag=0} flag' "$plans" 2>/dev/null)
  echo "$stack_section" | grep -ioE 'next\.?js|sveltekit|svelte|nuxt|remix|astro|react.native|react|vue|vite' | head -1 | tr '[:upper:]' '[:lower:]'
}

STACK="$(detect_stack)"

if [ -z "$STACK" ]; then
  if [ $JSON -eq 1 ]; then
    echo '{"rule":"PSK025","stack":"none","skipped":"no frontend declared in agent/PLANS.md"}'
  else
    echo "PSK025: no frontend framework declared in agent/PLANS.md Stack table — skip"
  fi
  exit 0
fi

# --- UI root resolution ---
UI_ROOT=""
for candidate in src/app src/pages src/ui src/components pages app frontend/src; do
  if [ -d "$candidate" ]; then UI_ROOT="$candidate"; break; fi
done

if [ -z "$UI_ROOT" ]; then
  if [ $JSON -eq 1 ]; then
    echo "{\"rule\":\"PSK025\",\"stack\":\"$STACK\",\"ui_root\":\"\",\"checks\":{\"E\":{\"pass\":false,\"reason\":\"no UI root found — frontend declared but no src/app, src/pages, src/ui, pages, app, or frontend/src directory\"}},\"summary\":{\"violations\":1,\"sub_codes\":[\"E\"]}}"
  else
    echo "PSK025 UI Completeness Audit (stack: $STACK)"
    echo "  ✗ PSK025-E ui-root: no UI directory found (tried src/app, src/pages, src/ui, src/components, pages, app, frontend/src)"
    echo "1 violations"
  fi
  [ "$MODE" = "check" ] && exit 0 || exit 1
fi

# --- Helpers (bash 3.2 compatible — no associative arrays) ---
violations=()
CHECK_CODES=""
# Parallel arrays
CHECK_KEYS=()
CHECK_PASS_VALS=()
CHECK_DETAIL_VALS=()

record() {
  local code="$1" pass="$2" detail="$3"
  CHECK_KEYS+=("$code")
  CHECK_PASS_VALS+=("$pass")
  CHECK_DETAIL_VALS+=("$detail")
  [ "$pass" = "false" ] && violations+=("$code")
}

# Look up a check's pass/detail by code (parallel-array search)
_check_get() {
  local needle="$1" field="$2"  # field: pass | detail
  local i=0
  while [ $i -lt ${#CHECK_KEYS[@]} ]; do
    if [ "${CHECK_KEYS[$i]}" = "$needle" ]; then
      if [ "$field" = "pass" ]; then echo "${CHECK_PASS_VALS[$i]}"; else echo "${CHECK_DETAIL_VALS[$i]}"; fi
      return
    fi
    i=$((i+1))
  done
  echo "false"  # default for missing pass
}

# --- P: primitives ---
check_primitives() {
  local count=0 found=""
  for primitive in button input textarea select checkbox radio card modal toast tabs badge avatar dropdown menu dialog; do
    if find "$UI_ROOT" -type f \( -iname "*${primitive}*" \) 2>/dev/null | grep -q .; then
      count=$((count+1))
      found="$found $primitive"
    fi
  done
  if [ "$count" -ge 12 ]; then
    record P true "$count/12 found:$found"
  else
    record P false "only $count/12 primitives found:$found"
  fi
}

# --- L: layout ---
check_layout() {
  local count=0 found=""
  for elem in header nav navigation footer sidebar container; do
    if find "$UI_ROOT" -type f \( -iname "*${elem}*" \) 2>/dev/null | grep -q . || find "$UI_ROOT" -type d \( -iname "*${elem}*" \) 2>/dev/null | grep -q .; then
      count=$((count+1))
      found="$found $elem"
    fi
  done
  if [ "$count" -ge 4 ]; then
    record L true "$count/5 layout pieces:$found"
  else
    record L false "only $count/5 layout pieces:$found"
  fi
}

# --- D: dark mode ---
check_darkmode() {
  local hits=0 detail=""
  if grep -rE 'useTheme\(|data-theme=' "$UI_ROOT" 2>/dev/null | head -1 | grep -q .; then hits=$((hits+1)); detail="$detail theme-hook"; fi
  local darkcount; darkcount=$(grep -rE 'dark:' "$UI_ROOT" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${darkcount:-0}" -ge 20 ]; then hits=$((hits+1)); detail="$detail dark:×$darkcount"; fi
  if grep -rE 'prefers-color-scheme|--bg|--fg' "$UI_ROOT" 2>/dev/null | head -1 | grep -q .; then hits=$((hits+1)); detail="$detail color-vars"; fi
  if [ "$hits" -ge 1 ]; then
    record D true "dark-mode signals:$detail"
  else
    record D false "no dark-mode signal (need useTheme/data-theme/dark:×20+/--bg/--fg/prefers-color-scheme)"
  fi
}

# --- S: loading/empty/error states ---
check_states() {
  local pages; pages=$(find "$UI_ROOT" -type f \( -name 'page.tsx' -o -name 'page.jsx' -o -name '+page.svelte' -o -name 'index.tsx' -o -name 'index.jsx' \) 2>/dev/null)
  local total=0 with_state=0 missing=""
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    total=$((total+1))
    local dir; dir=$(dirname "$p")
    if grep -qE '<Skeleton|<Spinner|isLoading|<EmptyState|<ErrorBoundary|loading\.tsx|error\.tsx' "$p" 2>/dev/null \
       || [ -f "$dir/loading.tsx" ] || [ -f "$dir/error.tsx" ]; then
      with_state=$((with_state+1))
    else
      missing="$missing ${p#$UI_ROOT/}"
    fi
  done <<< "$pages"
  if [ "$total" -eq 0 ]; then
    record S true "no pages to check"
  elif [ "$with_state" -eq "$total" ]; then
    record S true "$with_state/$total pages have loading/empty/error scaffolding"
  else
    record S false "$with_state/$total pages with states — missing:$missing"
  fi
}

# --- A: a11y ---
check_a11y() {
  local aria_label_count; aria_label_count=$(grep -rE 'aria-label' "$UI_ROOT" 2>/dev/null | wc -l | tr -d ' ')
  local role_count; role_count=$(grep -rE 'role="' "$UI_ROOT" 2>/dev/null | wc -l | tr -d ' ')
  local native_dialogs; native_dialogs=$(grep -rE '(alert|confirm|prompt)\(' "$UI_ROOT" 2>/dev/null | grep -v 'aria-' | wc -l | tr -d ' ')
  local detail="aria-label×${aria_label_count} role×${role_count} native-dialogs×${native_dialogs}"
  if [ "${aria_label_count:-0}" -ge 10 ] && [ "${role_count:-0}" -ge 5 ] && [ "${native_dialogs:-0}" -eq 0 ]; then
    record A true "$detail"
  else
    record A false "$detail (need aria-label≥10 role≥5 native-dialogs=0)"
  fi
}

# --- T: design tokens ---
check_tokens() {
  local found=""
  if find . -maxdepth 3 -type f \( -name 'tailwind.config.js' -o -name 'tailwind.config.ts' -o -name 'tailwind.config.mjs' \) 2>/dev/null | xargs grep -l 'colors:' 2>/dev/null | head -1 | grep -q .; then
    found="$found tailwind-colors"
  fi
  if find "$UI_ROOT" -type f \( -name 'tokens.ts' -o -name 'tokens.js' -o -name 'theme.ts' -o -name 'theme.js' \) 2>/dev/null | head -1 | grep -q .; then
    found="$found tokens-file"
  fi
  local rootvars; rootvars=$(grep -rE -- '--[a-z][a-z0-9-]+:' "$UI_ROOT" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${rootvars:-0}" -ge 6 ]; then found="$found css-vars×$rootvars"; fi
  if [ -n "$found" ]; then
    record T true "tokens:$found"
  else
    record T false "no design-token system (tailwind colors / tokens.ts / :root --vars)"
  fi
}

# --- F: per-feature page presence ---
check_features() {
  local specs="agent/SPECS.md"
  if [ ! -f "$specs" ]; then
    record F true "no SPECS.md — skip"
    return
  fi
  local missing="" total=0 present=0
  # Find done features with UI keywords
  while IFS= read -r line; do
    local has_ui=0
    echo "$line" | grep -qiE '\bpage\b|\bview\b|\bform\b|\bdashboard\b|\badmin\b|\blist\b|\bdetail\b|\bfeed\b|\bprofile\b' && has_ui=1
    [ $has_ui -eq 1 ] || continue
    total=$((total+1))
    # extract feature name slug (heuristic — first 3 alphabetic words)
    local slug; slug=$(echo "$line" | grep -oE '[A-Za-z]+' | head -3 | tr '[:upper:]' '[:lower:]' | tr '\n' '-' | sed 's/-$//')
    if [ -n "$slug" ] && find "$UI_ROOT" -type d -iname "*${slug}*" 2>/dev/null | head -1 | grep -q . \
       || find "$UI_ROOT" -type f -iname "*${slug}*" 2>/dev/null | head -1 | grep -q .; then
      present=$((present+1))
    else
      missing="$missing ${slug:-unknown}"
    fi
  done < <(grep -E '^\|.*\[x\]' "$specs" 2>/dev/null)
  if [ "$total" -eq 0 ]; then
    record F true "no UI-keyword features marked done"
  elif [ "$present" -eq "$total" ]; then
    record F true "$present/$total UI features have page surface"
  else
    record F false "$present/$total UI features have page surface — missing:$missing"
  fi
}

# --- I: input feedback ---
check_input_feedback() {
  local inputs; inputs=$(grep -rE '<(input|textarea|Input|Textarea)\b' "$UI_ROOT" 2>/dev/null | wc -l | tr -d ' ')
  local error_hooks; error_hooks=$(grep -rE 'aria-describedby|<FormMessage|<HelperText|<FieldError|className=.*error' "$UI_ROOT" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${inputs:-0}" -eq 0 ]; then
    record I true "no inputs — skip"
  elif [ "${error_hooks:-0}" -ge 5 ]; then
    record I true "inputs×${inputs} error-feedback×${error_hooks}"
  else
    record I false "inputs×${inputs} but only ${error_hooks} error-feedback hooks (need ≥5)"
  fi
}

# --- R: responsive ---
check_responsive() {
  local twbp; twbp=$(grep -rE '(sm|md|lg|xl|2xl):[a-z]' "$UI_ROOT" 2>/dev/null | wc -l | tr -d ' ')
  local media; media=$(grep -rE '@media' "$UI_ROOT" 2>/dev/null | wc -l | tr -d ' ')
  local platform; platform=$(grep -rE 'Platform\.' "$UI_ROOT" 2>/dev/null | wc -l | tr -d ' ')
  local detail="tailwind-bp×${twbp} @media×${media} Platform×${platform}"
  if [ "${twbp:-0}" -ge 10 ] || [ "${media:-0}" -ge 3 ] || [ "${platform:-0}" -ge 1 ]; then
    record R true "$detail"
  else
    record R false "$detail (need bp≥10 OR @media≥3 OR Platform≥1)"
  fi
}

# --- E: empty-shell ---
check_empty_shell() {
  local pages; pages=$(find "$UI_ROOT" -type f \( -name 'page.tsx' -o -name 'page.jsx' -o -name '+page.svelte' -o -name 'index.tsx' -o -name 'index.jsx' \) 2>/dev/null)
  local empties=""
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if grep -qE '<>\s*\{?\s*/\*\s*TODO\s*\*/\s*\}?\s*</>|<div>\s*Coming soon\s*</div>|<div>\s*TODO\s*</div>|<h1>\s*TODO' "$p" 2>/dev/null; then
      empties="$empties ${p#$UI_ROOT/}"
      continue
    fi
    local loc; loc=$(grep -cvE '^\s*(import|export\s+default\s*$|export\s*\{?|//|/\*|\*|$)' "$p" 2>/dev/null || echo 0)
    if [ "${loc:-0}" -lt 20 ]; then
      empties="$empties ${p#$UI_ROOT/}(${loc}LOC)"
    fi
  done <<< "$pages"
  if [ -z "$empties" ]; then
    record E true "no empty-shell pages"
  else
    record E false "empty-shell:$empties"
  fi
}

# --- Run all checks (or single feature) ---
if [ -n "$FEATURE" ]; then
  # single-feature mode
  if [ ! -f "agent/SPECS.md" ]; then echo "no SPECS.md"; exit 2; fi
  row=$(grep -E "^\|\s*$FEATURE\b" agent/SPECS.md | head -1)
  if [ -z "$row" ]; then echo "feature $FEATURE not in SPECS.md"; exit 2; fi
  slug=$(echo "$row" | grep -oE '[A-Za-z]+' | head -3 | tr '[:upper:]' '[:lower:]' | tr '\n' '-' | sed 's/-$//')
  if find "$UI_ROOT" -iname "*${slug}*" 2>/dev/null | head -1 | grep -q .; then
    echo "$FEATURE: page surface present"
    exit 0
  else
    echo "$FEATURE: no page surface found for slug $slug"
    exit 1
  fi
fi

check_primitives
check_layout
check_darkmode
check_states
check_a11y
check_tokens
check_features
check_input_feedback
check_responsive
check_empty_shell

# --- Output ---
if [ $JSON -eq 1 ]; then
  # Build JSON
  printf '{"rule":"PSK025","stack":"%s","ui_root":"%s","checks":{' "$STACK" "$UI_ROOT"
  first=1
  for c in P L D S A T F I R E; do
    [ $first -eq 0 ] && printf ','
    first=0
    pass="$(_check_get "$c" pass)"
    detail="$(_check_get "$c" detail)"
    # escape detail minimally for JSON
    detail_esc=$(printf '%s' "$detail" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '"%s":{"pass":%s,"detail":"%s"}' "$c" "$pass" "$detail_esc"
  done
  printf '},"summary":{"violations":%d,"sub_codes":[' "${#violations[@]}"
  first=1
  for v in "${violations[@]}"; do
    [ $first -eq 0 ] && printf ','
    first=0
    printf '"%s"' "$v"
  done
  printf ']}}\n'
else
  echo "PSK025 UI Completeness Audit (stack: $STACK)"
  echo "  UI root: $UI_ROOT"
  for c in P L D S A T F I R E; do
    pass="$(_check_get "$c" pass)"
    detail="$(_check_get "$c" detail)"
    if [ "$pass" = "true" ]; then
      echo "  ✓ PSK025-$c $detail"
    else
      echo "  ✗ PSK025-$c $detail"
    fi
  done
  echo "${#violations[@]} violations"
fi

# --- Exit code ---
case "$MODE" in
  check)  exit 0 ;;
  strict) [ ${#violations[@]} -gt 0 ] && exit 1 || exit 0 ;;
  *)      [ ${#violations[@]} -gt 0 ] && exit 1 || exit 0 ;;
esac
