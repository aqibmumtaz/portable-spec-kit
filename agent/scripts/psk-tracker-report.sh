#!/bin/bash
# =============================================================
# psk-tracker-report.sh — Track B Time Report Generator
#
# Reads psk-tracker daily log files, computes focused minutes
# for a specific project in a date range. Outputs JSON.
#
# Usage:
#   bash psk-tracker-report.sh --project "/abs/path" --since "ISO8601"
#   bash psk-tracker-report.sh --project "/abs/path" --since "ISO8601" --until "ISO8601"
#
# Output: JSON to stdout (see format below)
# =============================================================

set -u

# --- Configuration ---
LOG_DIR="${PSK_LOG_DIR:-$HOME/.portable-spec-kit/time-tracking}"
IDLE_THRESHOLD_MIN="${PSK_IDLE_THRESHOLD:-15}"  # minutes

# --- Parse arguments ---
PROJECT=""
SINCE=""
UNTIL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project)  PROJECT="$2"; shift 2 ;;
    --since)    SINCE="$2"; shift 2 ;;
    --until)    UNTIL="$2"; shift 2 ;;
    --log-dir)  LOG_DIR="$2"; shift 2 ;;  # override for testing
    --idle)     IDLE_THRESHOLD_MIN="$2"; shift 2 ;;
    *)          shift ;;
  esac
done

if [ -z "$PROJECT" ] || [ -z "$SINCE" ]; then
  echo '{"error": "Usage: --project /path --since ISO8601 [--until ISO8601]"}' >&2
  exit 1
fi

# Default --until to now
if [ -z "$UNTIL" ]; then
  UNTIL=$(date -u +%Y-%m-%dT%H:%M:%SZ)
fi

# --- Date helpers ---
# Convert ISO8601 to epoch seconds (portable)
iso_to_epoch() {
  local ts="$1"
  if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%s" 2>/dev/null; then
    return
  fi
  # GNU date fallback
  date -d "$ts" "+%s" 2>/dev/null || echo "0"
}

# Extract YYYY-MM-DD from ISO8601
iso_to_date() {
  echo "$1" | cut -c1-10
}

epoch_to_iso() {
  if date -r "$1" -u "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null; then
    return
  fi
  date -u -d "@$1" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo ""
}

# --- Compute date range (list of YYYY-MM-DD between since and until) ---
date_range() {
  local start_date end_date
  start_date=$(iso_to_date "$SINCE")
  end_date=$(iso_to_date "$UNTIL")

  local current="$start_date"
  while [[ "$current" < "$end_date" ]] || [[ "$current" == "$end_date" ]]; do
    echo "$current"
    # Increment by 1 day (portable)
    if date -v+1d -j -f "%Y-%m-%d" "$current" "+%Y-%m-%d" 2>/dev/null; then
      current=$(date -v+1d -j -f "%Y-%m-%d" "$current" "+%Y-%m-%d" 2>/dev/null)
    else
      current=$(date -d "$current + 1 day" "+%Y-%m-%d" 2>/dev/null)
    fi
    [ -z "$current" ] && break
  done
}

# --- Main computation ---
main() {
  local total_minutes=0
  local idle_excluded=0
  local intervals_json=""
  local log_files_json=""
  local since_epoch until_epoch
  since_epoch=$(iso_to_epoch "$SINCE")
  until_epoch=$(iso_to_epoch "$UNTIL")
  local idle_threshold_sec=$((IDLE_THRESHOLD_MIN * 60))

  # Iterate over date range
  while IFS= read -r day; do
    local log_file="$LOG_DIR/$day.log"
    [ ! -f "$log_file" ] && continue

    # Track this log file
    if [ -n "$log_files_json" ]; then
      log_files_json="${log_files_json},\"${day}.log\""
    else
      log_files_json="\"${day}.log\""
    fi

    local focus_time=""
    local focus_project=""

    while IFS= read -r line; do
      [ -z "$line" ] && continue

      local ts event path
      ts=$(echo "$line" | awk '{print $1}')
      event=$(echo "$line" | awk '{print $2}')
      path=$(echo "$line" | awk '{$1=""; $2=""; print}' | sed 's/^ *//')

      # Skip entries outside our date range
      local entry_epoch
      entry_epoch=$(iso_to_epoch "$ts")
      [ "$entry_epoch" -lt "$since_epoch" ] 2>/dev/null && continue
      [ "$entry_epoch" -gt "$until_epoch" ] 2>/dev/null && continue

      # Only process entries for our project
      [ "$path" != "$PROJECT" ] && {
        # If we had a FOCUS for our project and now see another project's event
        # that doesn't concern us — skip
        if [ "$event" = "FOCUS" ]; then
          continue
        elif [ "$event" = "BLUR" ] && [ "$path" != "$PROJECT" ]; then
          continue
        fi
      }

      case "$event" in
        FOCUS)
          if [ "$path" = "$PROJECT" ]; then
            focus_time="$ts"
            focus_project="$path"
          fi
          ;;
        BLUR)
          if [ "$path" = "$PROJECT" ] && [ -n "$focus_time" ]; then
            local focus_epoch blur_epoch duration_sec duration_min
            focus_epoch=$(iso_to_epoch "$focus_time")
            blur_epoch=$(iso_to_epoch "$ts")
            duration_sec=$((blur_epoch - focus_epoch))

            # Apply idle threshold
            if [ "$duration_sec" -gt "$idle_threshold_sec" ]; then
              # Cap at idle threshold — treat excess as idle
              local excess=$((duration_sec - idle_threshold_sec * 60))
              # Actually, idle threshold means: if gap > threshold, exclude the excess
              # But FOCUS→BLUR is an active interval, not a gap
              # Only apply 8h daily cap
              if [ "$duration_sec" -gt 28800 ]; then  # 8 hours
                idle_excluded=$((idle_excluded + (duration_sec - 28800) / 60))
                duration_sec=28800
              fi
            fi

            if [ "$duration_sec" -gt 0 ]; then
              duration_min=$((duration_sec / 60))
              total_minutes=$((total_minutes + duration_min))

              # Add to intervals JSON
              local interval="{\"start\":\"$focus_time\",\"end\":\"$ts\",\"minutes\":$duration_min}"
              if [ -n "$intervals_json" ]; then
                intervals_json="${intervals_json},$interval"
              else
                intervals_json="$interval"
              fi
            fi

            focus_time=""
            focus_project=""
          fi
          ;;
      esac

    done < "$log_file"

    # Handle orphaned FOCUS (no BLUR at end of file)
    if [ -n "$focus_time" ] && [ -n "$focus_project" ]; then
      # Estimate: use end of day or current time, whichever is earlier
      local end_ts="$UNTIL"
      local focus_epoch end_epoch duration_sec duration_min
      focus_epoch=$(iso_to_epoch "$focus_time")
      end_epoch=$(iso_to_epoch "$end_ts")
      duration_sec=$((end_epoch - focus_epoch))

      # Cap at 8 hours
      if [ "$duration_sec" -gt 28800 ]; then
        idle_excluded=$((idle_excluded + (duration_sec - 28800) / 60))
        duration_sec=28800
      fi

      if [ "$duration_sec" -gt 0 ]; then
        duration_min=$((duration_sec / 60))
        total_minutes=$((total_minutes + duration_min))

        local interval="{\"start\":\"$focus_time\",\"end\":\"$end_ts\",\"minutes\":$duration_min}"
        if [ -n "$intervals_json" ]; then
          intervals_json="${intervals_json},$interval"
        else
          intervals_json="$interval"
        fi
      fi

      focus_time=""
    fi

  done < <(date_range)

  # Output JSON
  cat <<EOJSON
{
  "project": "$PROJECT",
  "since": "$SINCE",
  "until": "$UNTIL",
  "total_minutes": $total_minutes,
  "intervals": [${intervals_json}],
  "idle_excluded_minutes": $idle_excluded,
  "log_files_read": [${log_files_json}],
  "error": null
}
EOJSON
}

# Error handling wrapper
{
  main
} || {
  cat <<EOJSON
{
  "project": "$PROJECT",
  "since": "$SINCE",
  "until": "${UNTIL:-}",
  "total_minutes": 0,
  "intervals": [],
  "idle_excluded_minutes": 0,
  "log_files_read": [],
  "error": "Failed to parse log files"
}
EOJSON
  exit 1
}
