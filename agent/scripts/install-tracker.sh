#!/bin/bash
# =============================================================
# install-tracker.sh — psk-tracker Installer
#
# One-line install: copies daemon, registers OS service, adds
# project to tracked list.
#
# Usage:
#   bash agent/install-tracker.sh                      # install daemon
#   bash agent/install-tracker.sh --add-project /path  # add project
#   bash agent/install-tracker.sh --status             # check status
#
# Installs to: ~/.portable-spec-kit/
# =============================================================

set -euo pipefail

PSK_DIR="$HOME/.portable-spec-kit"
LOG_DIR="$PSK_DIR/time-tracking"
PROJECTS_FILE="$PSK_DIR/projects.txt"
TRACKER_SCRIPT="$PSK_DIR/psk-tracker.sh"
REPORT_SCRIPT="$PSK_DIR/psk-tracker-report.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[psk-install]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[psk-install]${NC} $*"; }
log_error() { echo -e "${RED}[psk-install]${NC} $*" >&2; }

# --- Prevent root install ---
if [ "$(id -u)" -eq 0 ]; then
  log_error "Don't install psk-tracker as root — it won't have access to your desktop session."
  log_error "Run without sudo."
  exit 1
fi

# --- OS detection ---
detect_os() {
  case "$(uname -s)" in
    Darwin)  echo "macos" ;;
    Linux)
      if grep -qi "microsoft\|WSL" /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)  echo "windows" ;;
    *)  echo "unknown" ;;
  esac
}

# --- Add project to projects.txt ---
add_project() {
  local project_path="$1"

  # Resolve to absolute path
  if [[ "$project_path" != /* ]]; then
    project_path="$(cd "$project_path" 2>/dev/null && pwd)" || {
      log_error "Directory not found: $project_path"
      exit 1
    }
  fi

  mkdir -p "$PSK_DIR"
  touch "$PROJECTS_FILE"

  # Check for duplicate (idempotent)
  if grep -qF "$project_path" "$PROJECTS_FILE" 2>/dev/null; then
    log_info "Already tracked: $project_path"
    return 0
  fi

  echo "$project_path" >> "$PROJECTS_FILE"
  log_info "Added to tracking: $project_path"
}

# --- Copy scripts ---
copy_scripts() {
  mkdir -p "$PSK_DIR" "$LOG_DIR"

  # Find source scripts relative to this installer
  local tracker_src="$SCRIPT_DIR/psk-tracker.sh"
  local report_src="$SCRIPT_DIR/psk-tracker-report.sh"

  if [ ! -f "$tracker_src" ]; then
    log_error "psk-tracker.sh not found at $tracker_src"
    exit 1
  fi

  cp "$tracker_src" "$TRACKER_SCRIPT"
  chmod +x "$TRACKER_SCRIPT"
  log_info "Copied psk-tracker.sh → $TRACKER_SCRIPT"

  if [ -f "$report_src" ]; then
    cp "$report_src" "$REPORT_SCRIPT"
    chmod +x "$REPORT_SCRIPT"
    log_info "Copied psk-tracker-report.sh → $REPORT_SCRIPT"
  fi
}

# --- macOS: LaunchAgent ---
install_macos() {
  local plist_dir="$HOME/Library/LaunchAgents"
  local plist_file="$plist_dir/com.psk.tracker.plist"

  mkdir -p "$plist_dir"

  # Unload existing if present
  if launchctl list 2>/dev/null | grep -q "com.psk.tracker"; then
    launchctl unload "$plist_file" 2>/dev/null || true
  fi

  cat > "$plist_file" <<EOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.psk.tracker</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${TRACKER_SCRIPT}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${PSK_DIR}/tracker.log</string>
  <key>StandardErrorPath</key>
  <string>${PSK_DIR}/tracker-error.log</string>
</dict>
</plist>
EOPLIST

  launchctl load "$plist_file"
  log_info "LaunchAgent registered: com.psk.tracker (auto-starts on login)"

  # Check Accessibility permission
  if ! osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' >/dev/null 2>&1; then
    log_warn ""
    log_warn "Accessibility permission required for window title detection."
    log_warn "Open: System Settings > Privacy & Security > Accessibility"
    log_warn "Enable: Terminal (or iTerm, or your terminal app)"
    log_warn ""
  fi
}

# --- Linux: systemd user service ---
install_linux() {
  local os_variant="$1"  # x11 or wayland

  # Check display availability
  if [ "$os_variant" = "wayland" ]; then
    if ! command -v swaymsg >/dev/null 2>&1; then
      log_warn "Wayland detected with $(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]') compositor."
      log_warn "Only sway is supported for direct tracking in this release."
      log_warn "GNOME, KDE, Hyprland: psk-tracker falls back to git/mtime detection (less accurate)."
      log_warn "Continuing install for git/mtime fallback mode..."
    fi
  elif [ "$os_variant" = "x11" ]; then
    if ! command -v xdotool >/dev/null 2>&1; then
      log_warn "xdotool not installed. Attempting install..."
      if command -v apt >/dev/null 2>&1; then
        sudo apt install -y xdotool 2>/dev/null || {
          log_warn "Could not install xdotool automatically."
          log_warn "Install manually: sudo apt install xdotool"
          log_warn "Then re-run this installer."
        }
      elif command -v brew >/dev/null 2>&1; then
        brew install xdotool 2>/dev/null || {
          log_warn "Could not install xdotool via brew."
          log_warn "Install manually and re-run."
        }
      else
        log_warn "Install xdotool manually then re-run."
      fi
    fi
  fi

  local service_dir="$HOME/.config/systemd/user"
  local service_file="$service_dir/psk-tracker.service"

  mkdir -p "$service_dir"

  # Stop existing service
  systemctl --user stop psk-tracker 2>/dev/null || true
  systemctl --user disable psk-tracker 2>/dev/null || true

  cat > "$service_file" <<EOSERVICE
[Unit]
Description=Portable Spec Kit — Window Focus Tracker
After=graphical-session.target

[Service]
Type=simple
ExecStart=/bin/bash "${TRACKER_SCRIPT}"
Restart=on-failure
RestartSec=10
Environment=DISPLAY=${DISPLAY:-:0}
Environment=WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}
Environment=XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-}

[Install]
WantedBy=default.target
EOSERVICE

  systemctl --user daemon-reload
  systemctl --user enable psk-tracker
  systemctl --user start psk-tracker
  log_info "systemd user service registered: psk-tracker (auto-starts on login)"
}

# --- Windows: Task Scheduler ---
install_windows() {
  local ps_script
  ps_script=$(cat <<'EOPS'
$action = New-ScheduledTaskAction -Execute "bash.exe" -Argument "$env:USERPROFILE\.portable-spec-kit\psk-tracker.sh"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
try {
  Unregister-ScheduledTask -TaskName "PSK-Tracker" -Confirm:$false -ErrorAction SilentlyContinue
} catch {}
Register-ScheduledTask -TaskName "PSK-Tracker" -Action $action -Trigger $trigger -Settings $settings -Description "Portable Spec Kit Window Tracker"
Write-Host "Task Scheduler entry created: PSK-Tracker"
EOPS
)

  # Check execution policy
  powershell.exe -NoProfile -Command "
    \$policy = Get-ExecutionPolicy -Scope CurrentUser
    if (\$policy -eq 'Restricted') {
      Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    }
    $ps_script
  " 2>/dev/null || {
    log_error "Could not register Task Scheduler entry."
    log_error "Try running from PowerShell directly."
    return 1
  }

  log_info "Task Scheduler entry registered: PSK-Tracker (auto-starts on login)"
}

# --- Show status ---
show_status() {
  local os
  os=$(detect_os)

  echo ""
  echo "psk-tracker status:"
  echo "──────────────────────"

  # Check script exists
  if [ -f "$TRACKER_SCRIPT" ]; then
    echo "  Script:    ✅ installed ($TRACKER_SCRIPT)"
  else
    echo "  Script:    ❌ not found"
  fi

  # Check service running
  case "$os" in
    macos)
      if launchctl list 2>/dev/null | grep -q "com.psk.tracker"; then
        echo "  Service:   ✅ running (LaunchAgent)"
      else
        echo "  Service:   ❌ not running"
      fi
      ;;
    linux)
      if systemctl --user is-active psk-tracker >/dev/null 2>&1; then
        echo "  Service:   ✅ running (systemd)"
      else
        echo "  Service:   ❌ not running"
      fi
      ;;
    *)
      echo "  Service:   ? (check manually)"
      ;;
  esac

  # Check projects
  if [ -f "$PROJECTS_FILE" ]; then
    local count
    count=$(grep -cv '^$\|^#' "$PROJECTS_FILE" 2>/dev/null || echo 0)
    echo "  Projects:  $count tracked"
    while IFS= read -r line; do
      [ -z "$line" ] || [[ "$line" == \#* ]] && continue
      echo "             - $line"
    done < "$PROJECTS_FILE"
  else
    echo "  Projects:  none (run --add-project)"
  fi

  # Latest log entry
  local latest_log
  latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
  if [ -n "$latest_log" ]; then
    local last_entry
    last_entry=$(tail -1 "$latest_log" 2>/dev/null)
    echo "  Last event: $last_entry"
  else
    echo "  Last event: (no logs yet)"
  fi

  echo ""
}

# --- Main ---
main() {
  local command="${1:-install}"

  case "$command" in
    --add-project)
      add_project "${2:?Missing project path}"
      ;;
    --status)
      show_status
      ;;
    install|--install)
      local os
      os=$(detect_os)

      log_info "Installing psk-tracker for $os..."

      case "$os" in
        wsl)
          log_warn "WSL detected — desktop window tracking unavailable."
          log_warn "Track B uses git/mtime fallback."
          log_warn "For full tracking, run psk-tracker on Windows host (PowerShell) instead."
          # Still copy scripts for manual use
          copy_scripts
          ;;
        macos)
          copy_scripts
          install_macos
          ;;
        linux)
          copy_scripts
          # Determine X11 or Wayland
          if [ -n "${WAYLAND_DISPLAY:-}" ]; then
            install_linux "wayland"
          else
            install_linux "x11"
          fi
          ;;
        windows)
          copy_scripts
          install_windows
          ;;
        *)
          log_error "Unsupported OS: $os"
          exit 1
          ;;
      esac

      # Create projects.txt if not exists
      touch "$PROJECTS_FILE"

      # Auto-detect current project and add
      local project_dir
      project_dir="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
      if [ -d "$project_dir" ]; then
        add_project "$project_dir"
      fi

      echo ""
      log_info "════════════════════════════════════════════"
      log_info "  psk-tracker installed"
      log_info "  Daemon:   $TRACKER_SCRIPT"
      log_info "  Logs:     $LOG_DIR/"
      log_info "  Projects: $PROJECTS_FILE"
      log_info "════════════════════════════════════════════"
      echo ""
      ;;
    *)
      echo "Usage:"
      echo "  bash agent/install-tracker.sh              # install daemon"
      echo "  bash agent/install-tracker.sh --add-project /path"
      echo "  bash agent/install-tracker.sh --status"
      ;;
  esac
}

main "$@"
