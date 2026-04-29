#!/bin/bash
# =============================================================
# uninstall-tracker.sh — Remove psk-tracker daemon
#
# Stops daemon, unregisters OS service, removes scripts.
# Does NOT delete log files (user may want history).
# Does NOT remove projects.txt.
#
# Usage:
#   bash agent/uninstall-tracker.sh
#   bash agent/uninstall-tracker.sh --purge  # also delete logs
# =============================================================

set -euo pipefail

PSK_DIR="$HOME/.portable-spec-kit"
LOG_DIR="$PSK_DIR/time-tracking"
TRACKER_SCRIPT="$PSK_DIR/psk-tracker.sh"
REPORT_SCRIPT="$PSK_DIR/psk-tracker-report.sh"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[psk-uninstall]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[psk-uninstall]${NC} $*"; }

detect_os() {
  case "$(uname -s)" in
    Darwin)  echo "macos" ;;
    Linux)   echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*)  echo "windows" ;;
    *)  echo "unknown" ;;
  esac
}

main() {
  local purge=false
  [ "${1:-}" = "--purge" ] && purge=true

  local os
  os=$(detect_os)

  log_info "Uninstalling psk-tracker..."

  # Stop and unregister OS service
  case "$os" in
    macos)
      local plist="$HOME/Library/LaunchAgents/com.psk.tracker.plist"
      if [ -f "$plist" ]; then
        launchctl unload "$plist" 2>/dev/null || true
        rm -f "$plist"
        log_info "LaunchAgent removed: com.psk.tracker"
      fi
      ;;
    linux)
      if systemctl --user is-active psk-tracker >/dev/null 2>&1; then
        systemctl --user stop psk-tracker 2>/dev/null || true
      fi
      systemctl --user disable psk-tracker 2>/dev/null || true
      rm -f "$HOME/.config/systemd/user/psk-tracker.service"
      systemctl --user daemon-reload 2>/dev/null || true
      log_info "systemd service removed: psk-tracker"
      ;;
    windows)
      powershell.exe -NoProfile -Command '
        try {
          Unregister-ScheduledTask -TaskName "PSK-Tracker" -Confirm:$false -ErrorAction Stop
          Write-Host "Task Scheduler entry removed: PSK-Tracker"
        } catch {
          Write-Host "No Task Scheduler entry found"
        }
      ' 2>/dev/null || true
      log_info "Task Scheduler entry removed (if existed)"
      ;;
  esac

  # Remove scripts
  if [ -f "$TRACKER_SCRIPT" ]; then
    rm -f "$TRACKER_SCRIPT"
    log_info "Removed: $TRACKER_SCRIPT"
  fi
  if [ -f "$REPORT_SCRIPT" ]; then
    rm -f "$REPORT_SCRIPT"
    log_info "Removed: $REPORT_SCRIPT"
  fi

  # Remove stdout/stderr logs
  rm -f "$PSK_DIR/tracker.log" "$PSK_DIR/tracker-error.log"

  # Purge tracking logs if requested
  if [ "$purge" = true ]; then
    if [ -d "$LOG_DIR" ]; then
      rm -rf "$LOG_DIR"
      log_info "Purged: $LOG_DIR (all tracking logs deleted)"
    fi
  else
    log_warn "Log files preserved at: $LOG_DIR"
    log_warn "Run with --purge to delete logs too"
  fi

  echo ""
  log_info "psk-tracker uninstalled."
  log_info "projects.txt preserved at: $PSK_DIR/projects.txt"
}

main "$@"
