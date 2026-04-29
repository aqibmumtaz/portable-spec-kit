#!/bin/bash
# =============================================================
# psk-jira-sync.sh — Jira REST API v3 Sync Script
#
# Single connection method for Portable Spec Kit → Jira Cloud.
# Agent calls this script; script handles all HTTP, retry, errors.
#
# Usage:
#   bash agent/psk-jira-sync.sh --test              # test connection
#   bash agent/psk-jira-sync.sh --sync <json_file>  # sync tasks
#   bash agent/psk-jira-sync.sh --create <json>     # create issue
#   bash agent/psk-jira-sync.sh --worklog <json>    # post worklog
#   bash agent/psk-jira-sync.sh --transition <json>  # transition issue
#   bash agent/psk-jira-sync.sh --project-info      # get project info
#   bash agent/psk-jira-sync.sh --issue-types       # get issue types
#
# Exit codes:
#   0 = success
#   1 = configuration error (missing .env, bad credentials)
#   2 = authentication error (401/403)
#   3 = network error (timeout, unreachable)
#   4 = API error (404, 422, etc.)
#   5 = lock conflict (another sync in progress)
# =============================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
LOCK_FILE="$AGENT_DIR/.jira-sync.lock"
RESULT_FILE="$AGENT_DIR/SYNC_RESULT.json"
MAX_RETRIES=5
BACKOFF_SCHEDULE=(2 4 8 16 32)
REQUEST_TIMEOUT=15

# --- Color output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

# --- Helper functions ---

log_info()  { echo -e "${GREEN}[psk-jira]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[psk-jira]${NC} $*" >&2; }
log_error() { echo -e "${RED}[psk-jira]${NC} $*" >&2; }

# --- .env discovery (first match wins) ---
discover_env() {
  local env_file=""
  if [ -f "$AGENT_DIR/.env" ]; then
    env_file="$AGENT_DIR/.env"
  elif [ -f "$AGENT_DIR/../.env" ]; then
    env_file="$AGENT_DIR/../.env"
  elif [ -n "${DOTENV_PATH:-}" ] && [ -f "$DOTENV_PATH" ]; then
    env_file="$DOTENV_PATH"
  fi

  if [ -z "$env_file" ]; then
    log_error "No .env found. Create at project root or agent/.env with JIRA_EMAIL, JIRA_API_TOKEN"
    exit 1
  fi

  log_info "Reading credentials from: $env_file"

  # Source .env safely — only export known vars, trim whitespace
  while IFS='=' read -r key value; do
    key=$(echo "$key" | tr -d '[:space:]')
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed "s/^['\"]//;s/['\"]$//")
    case "$key" in
      JIRA_EMAIL)     export JIRA_EMAIL="$value" ;;
      JIRA_API_TOKEN) export JIRA_API_TOKEN="$value" ;;
    esac
  done < <(grep -v '^#' "$env_file" | grep -v '^$')
}

# --- JIRA_URL from AGENT.md (structural config, not secret) ---
discover_jira_url() {
  local agent_md=""
  if [ -f "$AGENT_DIR/AGENT.md" ]; then
    agent_md="$AGENT_DIR/AGENT.md"
  elif [ -f "$AGENT_DIR/../agent/AGENT.md" ]; then
    agent_md="$AGENT_DIR/../agent/AGENT.md"
  fi

  if [ -n "$agent_md" ]; then
    JIRA_URL=$(grep -i 'JIRA_URL' "$agent_md" | head -1 | sed 's/.*: *//;s/^[[:space:]]*//;s/[[:space:]]*$//')
    JIRA_PROJECT_KEY=$(grep -i 'JIRA_PROJECT_KEY' "$agent_md" | head -1 | sed 's/.*: *//;s/^[[:space:]]*//;s/[[:space:]]*$//')
  fi

  # Fallback: check .env for JIRA_URL (backward compat)
  if [ -z "${JIRA_URL:-}" ]; then
    JIRA_URL="${JIRA_URL:-}"
  fi
}

# --- Validate configuration ---
validate_config() {
  local errors=0

  if [ -z "${JIRA_URL:-}" ]; then
    log_error "JIRA_URL not found in agent/AGENT.md"
    errors=$((errors + 1))
  elif [[ ! "$JIRA_URL" =~ ^https:// ]]; then
    # Auto-fix: prepend https:// if missing
    if [[ "$JIRA_URL" =~ ^http:// ]]; then
      JIRA_URL="${JIRA_URL/http:/https:}"
      log_warn "Upgraded JIRA_URL to HTTPS: $JIRA_URL"
    else
      JIRA_URL="https://$JIRA_URL"
      log_warn "Prepended https:// to JIRA_URL: $JIRA_URL"
    fi
  fi

  # Remove trailing slash
  JIRA_URL="${JIRA_URL%/}"

  if [ -z "${JIRA_EMAIL:-}" ]; then
    log_error "JIRA_EMAIL not found in .env"
    errors=$((errors + 1))
  fi

  if [ -z "${JIRA_API_TOKEN:-}" ]; then
    log_error "JIRA_API_TOKEN not found in .env"
    errors=$((errors + 1))
  elif [ ${#JIRA_API_TOKEN} -lt 32 ]; then
    log_warn "JIRA_API_TOKEN seems too short (${#JIRA_API_TOKEN} chars, expected ≥32). Verify it's correct."
  fi

  if [ $errors -gt 0 ]; then
    log_error "Incomplete config. Required: JIRA_URL (in agent/AGENT.md), JIRA_EMAIL + JIRA_API_TOKEN (in .env)"
    exit 1
  fi
}

# --- Lock file management (PID-based) ---
acquire_lock() {
  if [ -f "$LOCK_FILE" ]; then
    local lock_pid lock_started
    lock_pid=$(grep '^PID=' "$LOCK_FILE" 2>/dev/null | cut -d= -f2)
    lock_started=$(grep '^STARTED=' "$LOCK_FILE" 2>/dev/null | cut -d= -f2)

    if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
      log_error "Sync in progress (PID $lock_pid, started $lock_started). Wait or kill that process."
      exit 5
    else
      log_warn "Stale lock removed (previous sync crashed, PID $lock_pid)"
      rm -f "$LOCK_FILE"
    fi
  fi

  echo "PID=$$" > "$LOCK_FILE"
  echo "STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOCK_FILE"
  chmod 0600 "$LOCK_FILE"
}

release_lock() {
  rm -f "$LOCK_FILE"
}

# Always release lock on exit
trap release_lock EXIT

# --- HTTP request with retry + backoff ---
jira_request() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  local attempt=0
  local response http_code body

  while [ $attempt -lt $MAX_RETRIES ]; do
    local curl_args=(
      -s -w "\n%{http_code}"
      --max-time "$REQUEST_TIMEOUT"
      -H "Content-Type: application/json"
      -H "Accept: application/json"
      -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}"
      -X "$method"
    )

    if [ -n "$data" ]; then
      curl_args+=(-d "$data")
    fi

    # Allow --base-url override for testing
    local base_url="${JIRA_BASE_URL_OVERRIDE:-$JIRA_URL}"

    response=$(curl "${curl_args[@]}" "${base_url}${endpoint}" 2>/dev/null) || {
      attempt=$((attempt + 1))
      if [ $attempt -lt $MAX_RETRIES ]; then
        local wait=${BACKOFF_SCHEDULE[$attempt-1]:-32}
        log_warn "Network error. Retry $attempt/$MAX_RETRIES in ${wait}s..."
        sleep "$wait"
        continue
      fi
      log_error "Jira unreachable at ${JIRA_URL}. Check: (1) JIRA_URL correct? (2) Network connected? (3) VPN required?"
      return 3
    }

    # Split response into body + http_code
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    case "$http_code" in
      200|201|204)
        echo "$body"
        return 0
        ;;
      401)
        log_error "401 Unauthorized — Token invalid or expired."
        log_error "Regenerate at: https://id.atlassian.com/manage-profile/security/api-tokens"
        log_error "Then update JIRA_API_TOKEN in .env"
        return 2
        ;;
      403)
        log_error "403 Forbidden — Token lacks write access to ${JIRA_PROJECT_KEY:-project}."
        log_error "Regenerate at: https://id.atlassian.com/manage-profile/security/api-tokens"
        log_error "Required scopes: manage:jira-configuration, write:jira-work, read:jira-work"
        return 2
        ;;
      404)
        # Could be Server/DC detection or missing resource
        if [ "$endpoint" = "/rest/api/3/myself" ]; then
          log_error "REST API v3 not found. psk-jira-sync.sh requires Jira Cloud (REST API v3)."
          log_error "Jira Server/Data Center uses v2 — not supported in this release."
          log_error "Check your Jira version at: ${JIRA_URL}/rest/api/latest/serverInfo"
        else
          log_error "404 Not Found: $endpoint"
        fi
        echo "$body"
        return 4
        ;;
      429)
        # Rate limited — check Retry-After header
        local retry_after
        retry_after=$(echo "$body" | grep -oi '"retry-after":[[:space:]]*[0-9]*' | grep -o '[0-9]*' || echo "")
        if [ -z "$retry_after" ]; then
          retry_after=${BACKOFF_SCHEDULE[$attempt]:-32}
        fi
        attempt=$((attempt + 1))
        if [ $attempt -lt $MAX_RETRIES ]; then
          log_warn "Rate limited (429). Retry $attempt/$MAX_RETRIES in ${retry_after}s..."
          sleep "$retry_after"
          continue
        fi
        log_error "Rate limited after $MAX_RETRIES attempts. Try again later."
        return 4
        ;;
      *)
        log_error "HTTP $http_code on $method $endpoint"
        echo "$body"
        return 4
        ;;
    esac
  done

  return 3
}

# --- Write SYNC_RESULT.json (sanitized — no tokens, no response bodies) ---
write_result() {
  local success="$1"
  local synced="$2"
  local skipped="$3"
  local errors="$4"

  cat > "$RESULT_FILE" <<EOJSON
{
  "success": $success,
  "synced": $synced,
  "skipped": $skipped,
  "errors": $errors,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOJSON
  chmod 0600 "$RESULT_FILE"
}

# --- Command: --test (verify connection + project) ---
cmd_test() {
  log_info "Testing Jira connection..."

  local result
  result=$(jira_request GET "/rest/api/3/myself") || exit $?

  local display_name
  display_name=$(echo "$result" | grep -o '"displayName":"[^"]*"' | head -1 | cut -d'"' -f4)
  local email_addr
  email_addr=$(echo "$result" | grep -o '"emailAddress":"[^"]*"' | head -1 | cut -d'"' -f4)

  log_info "Authenticated as: ${display_name:-unknown} (${email_addr:-unknown})"

  # Validate project key if configured
  if [ -n "${JIRA_PROJECT_KEY:-}" ]; then
    log_info "Validating project key: $JIRA_PROJECT_KEY"
    local project_result
    project_result=$(jira_request GET "/rest/api/3/project/$JIRA_PROJECT_KEY") || {
      log_error "Project key '$JIRA_PROJECT_KEY' not found in Jira."
      log_error "Check JIRA_PROJECT_KEY in agent/AGENT.md."
      log_error "List projects: ${JIRA_URL}/rest/api/3/project"
      exit 4
    }

    local project_name project_style
    project_name=$(echo "$project_result" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
    project_style=$(echo "$project_result" | grep -o '"style":"[^"]*"' | head -1 | cut -d'"' -f4)

    log_info "Project: $project_name ($JIRA_PROJECT_KEY)"

    if [ "$project_style" = "next-gen" ]; then
      log_warn "This is a Next-Gen (team-managed) Jira project."
      log_warn "Epic auto-creation is not supported. Pre-map Epics in agent/AGENT.md or use Task-only mode."
    fi
  fi

  log_info "Connection test passed."
}

# --- Command: --project-info ---
cmd_project_info() {
  if [ -z "${JIRA_PROJECT_KEY:-}" ]; then
    log_error "JIRA_PROJECT_KEY not set in agent/AGENT.md"
    exit 1
  fi

  local result
  result=$(jira_request GET "/rest/api/3/project/$JIRA_PROJECT_KEY") || exit $?
  echo "$result"
}

# --- Command: --issue-types (uses newer endpoint, falls back to createmeta) ---
cmd_issue_types() {
  if [ -z "${JIRA_PROJECT_KEY:-}" ]; then
    log_error "JIRA_PROJECT_KEY not set in agent/AGENT.md"
    exit 1
  fi

  log_info "Fetching issue types for $JIRA_PROJECT_KEY..."

  # Try newer project-level endpoint first
  local result
  result=$(jira_request GET "/rest/api/3/project/$JIRA_PROJECT_KEY/statuses" 2>/dev/null)
  local exit_code=$?

  if [ $exit_code -eq 0 ] && [ -n "$result" ]; then
    echo "$result"
    return 0
  fi

  # Fallback to createmeta (deprecated but still works on older instances)
  log_warn "Project-level endpoint failed, trying createmeta fallback..."
  result=$(jira_request GET "/rest/api/3/issue/createmeta?projectKeys=${JIRA_PROJECT_KEY}&expand=projects.issuetypes") || exit $?
  echo "$result"
}

# --- Command: --create (create issue) ---
# Expects JSON: {"summary":"...", "issuetype":"Story", "parent":"PROJ-10", "description":"..."}
cmd_create() {
  local input="$1"

  local summary issuetype parent description fix_version assignee
  summary=$(echo "$input" | grep -o '"summary":"[^"]*"' | head -1 | cut -d'"' -f4)
  issuetype=$(echo "$input" | grep -o '"issuetype":"[^"]*"' | head -1 | cut -d'"' -f4)
  parent=$(echo "$input" | grep -o '"parent":"[^"]*"' | head -1 | cut -d'"' -f4)
  description=$(echo "$input" | grep -o '"description":"[^"]*"' | head -1 | cut -d'"' -f4)
  fix_version=$(echo "$input" | grep -o '"fixVersion":"[^"]*"' | head -1 | cut -d'"' -f4)
  assignee=$(echo "$input" | grep -o '"assignee":"[^"]*"' | head -1 | cut -d'"' -f4)

  # Build Jira API payload
  local payload="{\"fields\":{\"project\":{\"key\":\"${JIRA_PROJECT_KEY}\"},\"summary\":\"${summary}\",\"issuetype\":{\"name\":\"${issuetype:-Task}\"}"

  if [ -n "$parent" ]; then
    payload="${payload},\"parent\":{\"key\":\"${parent}\"}"
  fi

  if [ -n "$description" ]; then
    payload="${payload},\"description\":{\"type\":\"doc\",\"version\":1,\"content\":[{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"${description}\"}]}]}"
  fi

  if [ -n "$fix_version" ]; then
    payload="${payload},\"fixVersions\":[{\"name\":\"${fix_version}\"}]"
  fi

  if [ -n "$assignee" ]; then
    payload="${payload},\"assignee\":{\"accountId\":\"${assignee}\"}"
  fi

  payload="${payload}}}"

  local result
  result=$(jira_request POST "/rest/api/3/issue" "$payload") || return $?

  local key
  key=$(echo "$result" | grep -o '"key":"[^"]*"' | head -1 | cut -d'"' -f4)
  log_info "Created: $key — $summary"
  echo "$result"
}

# --- Command: --worklog (post worklog to issue) ---
# Expects JSON: {"ticket":"PROJ-101", "seconds":5400, "started":"2026-04-09T14:30:00.000Z", "comment":"..."}
cmd_worklog() {
  local input="$1"

  local ticket seconds started comment
  ticket=$(echo "$input" | grep -o '"ticket":"[^"]*"' | head -1 | cut -d'"' -f4)
  seconds=$(echo "$input" | grep -o '"seconds":[0-9]*' | head -1 | grep -o '[0-9]*')
  started=$(echo "$input" | grep -o '"started":"[^"]*"' | head -1 | cut -d'"' -f4)
  comment=$(echo "$input" | grep -o '"comment":"[^"]*"' | head -1 | cut -d'"' -f4)

  if [ -z "$ticket" ] || [ -z "$seconds" ] || [ "$seconds" -eq 0 ]; then
    log_error "Worklog requires ticket + non-zero seconds"
    return 4
  fi

  # Verify ticket exists and is not already Done
  local issue_result
  issue_result=$(jira_request GET "/rest/api/3/issue/$ticket?fields=status") || {
    log_warn "Ticket $ticket not found in Jira (deleted?). Skipping."
    return 4
  }

  local payload="{\"timeSpentSeconds\":${seconds}"
  if [ -n "$started" ]; then
    payload="${payload},\"started\":\"${started}\""
  fi
  if [ -n "$comment" ]; then
    payload="${payload},\"comment\":{\"type\":\"doc\",\"version\":1,\"content\":[{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"${comment}\"}]}]}"
  fi
  payload="${payload}}"

  local result
  result=$(jira_request POST "/rest/api/3/issue/$ticket/worklog" "$payload") || return $?
  log_info "Worklog posted: $ticket (${seconds}s)"
  echo "$result"
}

# --- Command: --transition (move issue to Done) ---
# Expects JSON: {"ticket":"PROJ-101", "transition":"Done"}
cmd_transition() {
  local input="$1"

  local ticket target_name
  ticket=$(echo "$input" | grep -o '"ticket":"[^"]*"' | head -1 | cut -d'"' -f4)
  target_name=$(echo "$input" | grep -o '"transition":"[^"]*"' | head -1 | cut -d'"' -f4)
  target_name="${target_name:-Done}"

  # Fetch available transitions
  local transitions_result
  transitions_result=$(jira_request GET "/rest/api/3/issue/$ticket/transitions") || return $?

  # Match transition name (case-insensitive) — try configured name, then common names
  local transition_id=""
  local search_names=("$target_name" "Done" "Closed" "Resolved" "Complete" "Merged" "Released" "Deployed")

  for name in "${search_names[@]}"; do
    transition_id=$(echo "$transitions_result" | grep -oi "\"id\":\"[0-9]*\",\"name\":\"${name}\"" | head -1 | grep -o '"id":"[0-9]*"' | grep -o '[0-9]*')
    if [ -n "$transition_id" ]; then
      break
    fi
    # Try reverse order in JSON (name before id)
    transition_id=$(echo "$transitions_result" | grep -oi "\"name\":\"${name}\"[^}]*\"id\":\"[0-9]*\"" | head -1 | grep -o '"id":"[0-9]*"' | grep -o '[0-9]*')
    if [ -n "$transition_id" ]; then
      break
    fi
  done

  if [ -z "$transition_id" ]; then
    log_warn "No matching transition found for $ticket. Worklog posted, status unchanged."
    log_warn "Add mapping to agent/AGENT.md under Jira Config → Transition Mapping"
    return 0
  fi

  local payload="{\"transition\":{\"id\":\"${transition_id}\"}}"
  jira_request POST "/rest/api/3/issue/$ticket/transitions" "$payload" >/dev/null || return $?
  log_info "Transitioned: $ticket → $target_name"
}

# --- Command: --sync (full sync from agent-provided task list) ---
# Expects path to JSON file with task array
cmd_sync() {
  local task_file="$1"

  if [ ! -f "$task_file" ]; then
    log_error "Task file not found: $task_file"
    exit 1
  fi

  acquire_lock

  # Test connection first
  cmd_test || exit $?

  local synced_json="[]"
  local skipped_json="[]"
  local errors_json="[]"
  local total=0 synced_count=0 skipped_count=0 error_count=0

  # Read task file line by line (one JSON object per line)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    total=$((total + 1))

    local ticket summary hours action
    ticket=$(echo "$line" | grep -o '"ticket":"[^"]*"' | head -1 | cut -d'"' -f4)
    summary=$(echo "$line" | grep -o '"summary":"[^"]*"' | head -1 | cut -d'"' -f4)
    hours=$(echo "$line" | grep -o '"hours":[0-9.]*' | head -1 | grep -o '[0-9.]*')
    action=$(echo "$line" | grep -o '"action":"[^"]*"' | head -1 | cut -d'"' -f4)
    action="${action:-sync}"

    log_info "[$total] Processing: $ticket — $summary"

    # Check if ticket exists
    local issue_check
    issue_check=$(jira_request GET "/rest/api/3/issue/$ticket?fields=status" 2>/dev/null)
    local check_code=$?

    if [ $check_code -ne 0 ]; then
      log_warn "  $ticket not found in Jira (deleted?). Skipping."
      errors_json=$(echo "$errors_json" | sed "s/]$/,{\"ticket\":\"$ticket\",\"code\":404,\"message\":\"not found in Jira\"}]/")
      error_count=$((error_count + 1))
      continue
    fi

    # Check if already Done
    local current_status
    current_status=$(echo "$issue_check" | grep -oi '"name":"Done\|"name":"Closed\|"name":"Resolved' | head -1)
    if [ -n "$current_status" ]; then
      log_info "  $ticket already Done — skipped"
      skipped_json=$(echo "$skipped_json" | sed "s/]$/,{\"ticket\":\"$ticket\",\"reason\":\"already Done\"}]/")
      skipped_count=$((skipped_count + 1))
      continue
    fi

    # Post worklog (if hours > 0)
    if [ -n "$hours" ] && [ "$(echo "$hours > 0" | bc 2>/dev/null || echo 0)" = "1" ]; then
      local seconds
      seconds=$(echo "$hours * 3600" | bc 2>/dev/null | cut -d. -f1)
      local started
      started=$(echo "$line" | grep -o '"started":"[^"]*"' | head -1 | cut -d'"' -f4)
      local comment
      comment=$(echo "$line" | grep -o '"comment":"[^"]*"' | head -1 | cut -d'"' -f4)

      cmd_worklog "{\"ticket\":\"$ticket\",\"seconds\":${seconds:-0},\"started\":\"${started:-$(date -u +%Y-%m-%dT%H:%M:%S.000Z)}\",\"comment\":\"${comment:-Completed via Portable Spec Kit}\"}" >/dev/null 2>&1 || {
        log_warn "  Worklog failed for $ticket"
        errors_json=$(echo "$errors_json" | sed "s/]$/,{\"ticket\":\"$ticket\",\"code\":500,\"message\":\"worklog failed\"}]/")
        error_count=$((error_count + 1))
        continue
      }
    fi

    # Transition to Done
    local transition_name
    transition_name=$(echo "$line" | grep -o '"transition":"[^"]*"' | head -1 | cut -d'"' -f4)
    cmd_transition "{\"ticket\":\"$ticket\",\"transition\":\"${transition_name:-Done}\"}" 2>/dev/null || true

    synced_json=$(echo "$synced_json" | sed "s/]$/,{\"ticket\":\"$ticket\",\"hours\":${hours:-0},\"transition\":\"Done\"}]/")
    synced_count=$((synced_count + 1))
    log_info "  $ticket synced (${hours:-0}h logged)"

  done < "$task_file"

  # Clean up JSON (remove leading comma after [)
  synced_json=$(echo "$synced_json" | sed 's/\[,/[/')
  skipped_json=$(echo "$skipped_json" | sed 's/\[,/[/')
  errors_json=$(echo "$errors_json" | sed 's/\[,/[/')

  local success="true"
  [ $error_count -gt 0 ] && success="false"

  write_result "$success" "$synced_json" "$skipped_json" "$errors_json"

  echo ""
  log_info "════════════════════════════════════════════════════"
  log_info "  JIRA SYNC COMPLETE — ${JIRA_PROJECT_KEY:-PROJECT}"
  log_info "  Synced: $synced_count ✅  Skipped: $skipped_count ⏭  Errors: $error_count ⚠"
  log_info "════════════════════════════════════════════════════"

  [ $error_count -gt 0 ] && return 4
  return 0
}

# --- Command: --create-version (create Fix Version in Jira) ---
cmd_create_version() {
  local input="$1"
  local version_name
  version_name=$(echo "$input" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)

  local payload="{\"name\":\"${version_name}\",\"project\":\"${JIRA_PROJECT_KEY}\"}"
  local result
  result=$(jira_request POST "/rest/api/3/version" "$payload") || return $?
  log_info "Created Fix Version: $version_name"
  echo "$result"
}

# --- Main ---
main() {
  local command="${1:-}"

  if [ -z "$command" ]; then
    echo "Usage: bash agent/psk-jira-sync.sh [--test|--sync <file>|--create <json>|--worklog <json>|--transition <json>|--project-info|--issue-types]"
    exit 1
  fi

  # Load configuration
  discover_env
  discover_jira_url
  validate_config

  case "$command" in
    --test)
      cmd_test
      ;;
    --sync)
      cmd_sync "${2:?Missing task file path}"
      ;;
    --create)
      cmd_create "${2:?Missing JSON input}"
      ;;
    --worklog)
      cmd_worklog "${2:?Missing JSON input}"
      ;;
    --transition)
      cmd_transition "${2:?Missing JSON input}"
      ;;
    --project-info)
      cmd_project_info
      ;;
    --issue-types)
      cmd_issue_types
      ;;
    --create-version)
      cmd_create_version "${2:?Missing JSON input}"
      ;;
    *)
      log_error "Unknown command: $command"
      exit 1
      ;;
  esac
}

main "$@"
