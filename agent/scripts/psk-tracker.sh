#!/bin/bash
# =============================================================
# psk-tracker.sh — OS-Level Background Daemon
#
# Polls frontmost window every 10 seconds. Writes FOCUS/BLUR
# events to daily log files. Zero IDE dependency.
#
# Installed to: ~/.portable-spec-kit/psk-tracker.sh
# Logs to:      ~/.portable-spec-kit/time-tracking/YYYY-MM-DD.log
# Config:       ~/.portable-spec-kit/projects.txt
#
# CPU: ~0.1% | Memory: ~2MB | No network | No keystrokes
# =============================================================

set -u

# --- Configuration ---
PSK_DIR="$HOME/.portable-spec-kit"
LOG_DIR="$PSK_DIR/time-tracking"
PROJECTS_FILE="$PSK_DIR/projects.txt"
POLL_INTERVAL="${PSK_POLL_INTERVAL:-10}"
MAX_FOCUS_HOURS=8  # Cap continuous focus per day
LOG_RETENTION_DAYS=90

# --- State ---
LAST_PROJECT=""
LAST_DATE=""

# --- Ensure directories exist ---
mkdir -p "$LOG_DIR"

# --- OS Detection ---
detect_os() {
  case "$(uname -s)" in
    Darwin)  echo "macos" ;;
    Linux)
      # WSL detection
      if grep -qi "microsoft\|WSL" /proc/version 2>/dev/null; then
        echo "wsl"
      elif [ -n "${WAYLAND_DISPLAY:-}" ]; then
        echo "wayland"
      elif [ -n "${DISPLAY:-}" ]; then
        echo "x11"
      else
        echo "headless"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)  echo "windows" ;;
    *)  echo "unknown" ;;
  esac
}

# --- Get frontmost window title (OS-specific) ---
get_window_title() {
  local os="$1"

  case "$os" in
    macos)
      # AXTitle of frontmost window — NOT process name
      local title
      title=$(osascript -e '
        tell application "System Events"
          set frontApp to name of first application process whose frontmost is true
          if frontApp is in {"Finder", "SystemUIServer", "loginwindow", "ScreenSaverEngine"} then
            return ""
          end if
          try
            tell process frontApp
              return value of attribute "AXTitle" of window 1
            end tell
          on error
            return ""
          end try
        end tell
      ' 2>/dev/null)
      echo "$title"
      ;;

    x11)
      xdotool getactivewindow getwindowname 2>/dev/null || echo ""
      ;;

    wayland)
      # Sway only in this release
      if command -v swaymsg >/dev/null 2>&1; then
        swaymsg -t get_tree 2>/dev/null | \
          python3 -c "
import sys, json
tree = json.load(sys.stdin)
def find_focused(node):
    if node.get('focused'):
        return node.get('name', '')
    for child in node.get('nodes', []) + node.get('floating_nodes', []):
        result = find_focused(child)
        if result:
            return result
    return ''
print(find_focused(tree))
" 2>/dev/null || echo ""
      else
        echo ""
      fi
      ;;

    windows)
      powershell.exe -NoProfile -Command '
        Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        using System.Text;
        public class WinTitle {
          [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
          [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
        }
"@
        $sb = New-Object System.Text.StringBuilder 256
        $hw = [WinTitle]::GetForegroundWindow()
        [void][WinTitle]::GetWindowText($hw, $sb, 256)
        Write-Output $sb.ToString()
      ' 2>/dev/null | tr -d '\r' || echo ""
      ;;

    *)
      echo ""
      ;;
  esac
}

# --- Match window title to project path (longest match wins) ---
match_project() {
  local title="$1"
  local best_match=""
  local best_path=""
  local best_len=0

  [ -z "$title" ] && return
  [ ! -f "$PROJECTS_FILE" ] && return

  while IFS= read -r project_path; do
    [ -z "$project_path" ] && continue
    [[ "$project_path" == \#* ]] && continue  # skip comments

    local project_name
    project_name=$(basename "$project_path")

    # Case-insensitive substring match — check multiple separators
    # IDE title formats: "file — project — IDE", "project — IDE", "file (path)"
    if echo "$title" | grep -qi "$project_name"; then
      local name_len=${#project_name}
      if [ "$name_len" -gt "$best_len" ]; then
        best_match="$project_name"
        best_path="$project_path"
        best_len=$name_len
      fi
    fi
  done < "$PROJECTS_FILE"

  echo "$best_path"
}

# --- Recover orphaned FOCUS on startup ---
recover_orphaned_focus() {
  local latest_log
  latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
  [ -z "$latest_log" ] && return

  local last_line
  last_line=$(tail -1 "$latest_log" 2>/dev/null)
  [ -z "$last_line" ] && return

  if echo "$last_line" | grep -q "FOCUS"; then
    local project_path
    project_path=$(echo "$last_line" | sed 's/.*FOCUS *//')
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "$now BLUR  $project_path" >> "$latest_log"
  fi
}

# --- Clean old logs (retention policy) ---
clean_old_logs() {
  if command -v find >/dev/null 2>&1; then
    find "$LOG_DIR" -name "*.log" -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null
  fi
}

# --- Write log entry ---
write_log() {
  local event="$1"   # FOCUS or BLUR
  local project="$2"
  local today="$3"
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local log_file="$LOG_DIR/$today.log"

  printf "%s %-5s %s\n" "$now" "$event" "$project" >> "$log_file"
}

# --- Handle midnight rollover ---
handle_midnight() {
  local today="$1"

  if [ -n "$LAST_DATE" ] && [ "$today" != "$LAST_DATE" ] && [ -n "$LAST_PROJECT" ]; then
    # Close yesterday's FOCUS
    local yesterday_log="$LOG_DIR/$LAST_DATE.log"
    printf "%sT23:59:59Z %-5s %s\n" "$LAST_DATE" "BLUR" "$LAST_PROJECT" >> "$yesterday_log"
    # Open today's FOCUS
    local today_log="$LOG_DIR/$today.log"
    printf "%sT00:00:00Z %-5s %s\n" "$today" "FOCUS" "$LAST_PROJECT" >> "$today_log"
  fi
}

# --- Main loop ---
main() {
  local os
  os=$(detect_os)

  # Exit cleanly for unsupported environments
  case "$os" in
    wsl)
      echo "WSL detected — desktop window tracking unavailable."
      echo "Track B uses git/mtime fallback."
      echo "For full tracking, run psk-tracker on Windows host (PowerShell) instead."
      exit 0
      ;;
    headless)
      # No display — exit silently (Docker, SSH, CI)
      exit 0
      ;;
    unknown)
      echo "Unsupported OS. psk-tracker requires macOS, Linux (X11), or Windows."
      exit 1
      ;;
  esac

  # Check projects.txt exists
  if [ ! -f "$PROJECTS_FILE" ]; then
    echo "No projects.txt found at $PROJECTS_FILE"
    echo "Run: bash agent/install-tracker.sh --add-project /path/to/project"
    exit 1
  fi

  # Startup
  recover_orphaned_focus
  clean_old_logs

  local empty_title_count=0  # Track consecutive empty titles for SIP detection

  # Poll loop
  while true; do
    local title
    title=$(get_window_title "$os")

    # macOS SIP detection — 3 consecutive empty returns
    if [ "$os" = "macos" ] && [ -z "$title" ]; then
      empty_title_count=$((empty_title_count + 1))
      if [ "$empty_title_count" -ge 3 ] && [ "$empty_title_count" -eq 3 ]; then
        echo "Warning: AXTitle returned empty 3 times. Grant Accessibility permission:" >&2
        echo "  System Settings > Privacy & Security > Accessibility > enable Terminal" >&2
      fi
    else
      empty_title_count=0
    fi

    # Match title to project
    local current_project
    current_project=$(match_project "$title")

    local today
    today=$(date -u +%Y-%m-%d)

    # Handle midnight rollover
    handle_midnight "$today"

    # State machine: only write on CHANGE
    if [ "$current_project" != "$LAST_PROJECT" ]; then
      # BLUR old project
      if [ -n "$LAST_PROJECT" ]; then
        write_log "BLUR" "$LAST_PROJECT" "$today"
      fi
      # FOCUS new project
      if [ -n "$current_project" ]; then
        write_log "FOCUS" "$current_project" "$today"
      fi
      LAST_PROJECT="$current_project"
    fi

    LAST_DATE="$today"
    sleep "$POLL_INTERVAL"
  done
}

main "$@"
