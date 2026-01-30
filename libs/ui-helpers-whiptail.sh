#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Whiptail TUI backend for ui-helpers
# These functions are called by the dispatchers in ui-helpers.sh

set -uo pipefail

# =============================================================================
# TERMINAL REQUIREMENTS
# =============================================================================
# Whiptail requires TERM to be set. Default to 'xterm' for CI/non-interactive environments.
# (dumb terminal type doesn't support whiptail's screen positioning)
if [[ -z "${TERM:-}" ]]; then
  export TERM=xterm
fi

# =============================================================================
# WHIPTAIL DIMENSIONS - Standardized for consistent UI
# =============================================================================
readonly WT_WIDTH=70
readonly WT_HEIGHT_SMALL=8   # Simple messages, infoboxes
readonly WT_HEIGHT_MEDIUM=12 # Yes/no dialogs, short forms
readonly WT_HEIGHT_LARGE=18  # Error displays, summaries
readonly WT_HEIGHT_XLARGE=22 # Long content, completion messages
readonly WT_GAUGE_HEIGHT=7   # Progress gauge

# Legacy alias for backward compatibility
readonly WT_HEIGHT=$WT_HEIGHT_SMALL

# Backtitle (shown at top of every dialog) with navigation hints
readonly WT_BACKTITLE="DevBase Core Setup  ·  ↑↓→Navigate  Tab→Switch  Space→Toggle  Enter→OK"

# Navigation hints footer (kept for backward compatibility, but backtitle is preferred)
readonly WT_NAV_HINTS=""

# Accumulator for whiptail installation log
declare -a _WT_LOG=()

# Store current gauge title for restart after error dialogs
_WT_GAUGE_TITLE=""

# =============================================================================
# PERSISTENT GAUGE SYSTEM
# Keeps a single whiptail gauge running to prevent terminal flicker
# =============================================================================

# Global state for persistent gauge
_WT_GAUGE_FIFO=""
_WT_GAUGE_PID=""

# Brief: Start persistent gauge that stays on screen during installation
# Params: $1 - initial title (optional, default "Installing")
# Side-effects: Creates FIFO, starts background whiptail gauge process
_wt_start_persistent_gauge() {
  local title="${1:-Installing}"

  # Store title for restart after error dialogs
  _WT_GAUGE_TITLE="$title"

  # Clean up any existing gauge
  _wt_stop_persistent_gauge

  # Create named pipe for gauge communication
  # Use mktemp -u + mkfifo with restricted permissions to minimize race window
  _WT_GAUGE_FIFO=$(mktemp -u /tmp/devbase-gauge.XXXXXX)
  mkfifo -m 600 "$_WT_GAUGE_FIFO"

  # Start gauge in background, reading from FIFO
  # The gauge expects lines of: "XXX\n<percent>\n<message>\nXXX\n"
  tail -f "$_WT_GAUGE_FIFO" 2>/dev/null | TERM=xterm whiptail --backtitle "$WT_BACKTITLE" \
    --title "$title" --gauge "Initializing..." $WT_GAUGE_HEIGHT $WT_WIDTH 0 &
  _WT_GAUGE_PID=$!

  # Give gauge time to initialize (0.2s for reliability on slower systems)
  sleep 0.2
}

# Brief: Update persistent gauge message and progress
# Params: $1 - message, $2 - percent (optional, default 50)
_wt_update_gauge() {
  local message="$1"
  local percent="${2:-50}"

  # Clamp percent to valid range 0-100
  [[ $percent -lt 0 ]] && percent=0
  [[ $percent -gt 100 ]] && percent=100

  if [[ -n "$_WT_GAUGE_FIFO" ]] && [[ -p "$_WT_GAUGE_FIFO" ]]; then
    # Whiptail gauge extended format: XXX\npercent\nmessage\nXXX
    printf "XXX\n%s\n%s\nXXX\n" "$percent" "$message" >"$_WT_GAUGE_FIFO" 2>/dev/null || true
  fi
}

# Brief: Stop persistent gauge and clean up
# Params: $1 - show transitional infobox (optional, default "true")
_wt_stop_persistent_gauge() {
  local show_transition="${1:-true}"

  if [[ -n "$_WT_GAUGE_PID" ]]; then
    kill "$_WT_GAUGE_PID" 2>/dev/null || true
    wait "$_WT_GAUGE_PID" 2>/dev/null || true
    _WT_GAUGE_PID=""
  fi
  if [[ -n "$_WT_GAUGE_FIFO" ]] && [[ -p "$_WT_GAUGE_FIFO" ]]; then
    rm -f "$_WT_GAUGE_FIFO"
    _WT_GAUGE_FIFO=""
  fi

  # Show transitional infobox to prevent flicker before next dialog
  if [[ "$show_transition" == "true" ]]; then
    _wt_infobox "Installation Complete" "Preparing summary..."
  fi
}

# Brief: Check if persistent gauge is running
# Returns: 0 if running, 1 if not
_wt_gauge_is_running() {
  [[ -n "$_WT_GAUGE_PID" ]] && kill -0 "$_WT_GAUGE_PID" 2>/dev/null
}

# Brief: Clear the whiptail log accumulator
# Use before starting a new logical section to prevent carryover
_wt_clear_log() {
  _WT_LOG=()
}

# =============================================================================
# LOW-LEVEL WHIPTAIL PRIMITIVES
# =============================================================================

# Brief: Wrapper to ensure TERM is set before calling whiptail
# Whiptail requires a terminal type that supports screen positioning.
# Force TERM=xterm because CI environments often set TERM=dumb which doesn't work.
# Params: $@ - all arguments passed to whiptail
_wt() {
  TERM=xterm whiptail "$@"
}

# Brief: Show a whiptail infobox (non-blocking status message)
# Params: $1 - title, $2 - message
_wt_infobox() {
  local title="$1"
  local message="$2"
  _wt --backtitle "$WT_BACKTITLE" --title "$title" --infobox "$message" $WT_HEIGHT $WT_WIDTH
}

# Brief: Show a whiptail message box (blocking, requires OK)
# Params: $1 - title, $2 - message
_wt_msgbox() {
  local title="$1"
  local message="$2"
  _wt --backtitle "$WT_BACKTITLE" --title "$title" --msgbox "$message$WT_NAV_HINTS" $WT_HEIGHT $WT_WIDTH
}

# Brief: Run command with whiptail gauge progress
# Params: $1 - title, $2 - message, $3... - command to run
# Returns: Exit code of command
_wt_gauge_cmd() {
  local title="$1"
  local message="$2"
  shift 2

  # Run command in background, pipe progress to gauge
  (
    echo "0"
    "$@" >/dev/null 2>&1
    echo "100"
  ) | _wt --backtitle "$WT_BACKTITLE" --title "$title" --gauge "$message" $WT_GAUGE_HEIGHT $WT_WIDTH 0

  return "${PIPESTATUS[0]}"
}

# Brief: Run command with whiptail showing progress via infobox
# Params: $1 - description, $2... - command to run
# Returns: Exit code of command
_wt_run() {
  local description="$1"
  shift

  _wt_infobox "Installing..." "$description"

  local output
  local exit_code
  if output=$("$@" 2>&1); then
    exit_code=0
  else
    exit_code=$?
  fi

  if [[ $exit_code -ne 0 ]] && [[ -n "$output" ]]; then
    _wt --backtitle "$WT_BACKTITLE" --title "Error" --msgbox "Command failed:\n\n${output:0:500}$WT_NAV_HINTS" 15 $WT_WIDTH
  fi

  return $exit_code
}

# Brief: Show whiptail progress for multiple steps
# Params: $1 - title, stdin - lines of "percent message"
_wt_progress() {
  local title="$1"
  _wt --backtitle "$WT_BACKTITLE" --title "$title" --gauge "Starting..." $WT_GAUGE_HEIGHT $WT_WIDTH 0
}

# Brief: Add entry to whiptail log
# Params: $1 - status (ok/fail/info), $2 - message
_wt_log() {
  local status="$1"
  local message="$2"
  local icon
  case "$status" in
  ok) icon="✓" ;;
  fail) icon="✗" ;;
  info) icon="•" ;;
  *) icon=" " ;;
  esac
  _WT_LOG+=("$icon $message")
}

# Brief: Show accumulated log in scrollable msgbox
_wt_show_log() {
  local title="${1:-Installation Log}"
  local log_text
  log_text=$(printf '%s\n' "${_WT_LOG[@]}")
  _wt --backtitle "$WT_BACKTITLE" --title "$title" --scrolltext --msgbox "$log_text$WT_NAV_HINTS" 20 $WT_WIDTH
  _WT_LOG=() # Clear log
}

# Brief: Show final installation summary log
# Called at end of installation to display accumulated log
_wt_show_final_log() {
  if [[ ${#_WT_LOG[@]} -gt 0 ]]; then
    _wt_show_log "Installation Summary"
  fi
}

# =============================================================================
# HIGH-LEVEL WHIPTAIL IMPLEMENTATIONS (called by dispatchers)
# =============================================================================

# Brief: Display formatted progress message using whiptail
# Params: $1 - level (step/info/success/warning/error/validation), $@ - message text
# Uses persistent gauge if running, otherwise shows infobox
_wt_show_progress() {
  local level="$1"
  shift
  local message="$*"

  local display_msg
  case "$level" in
  step)
    display_msg="→ $message"
    _wt_log "info" "$message"
    ;;
  info)
    display_msg="• $message"
    _wt_log "info" "$message"
    ;;
  success)
    display_msg="✓ $message"
    _wt_log "ok" "$message"
    ;;
  warning)
    display_msg="⚠ $message"
    _wt_log "info" "⚠ $message"
    ;;
  error)
    display_msg="✗ $message"
    _wt_log "fail" "$message"
    ;;
  validation)
    display_msg="✗ $message"
    _wt_log "fail" "$message"
    ;;
  *)
    display_msg="$message"
    _wt_log "info" "$message"
    ;;
  esac

  # Use persistent gauge if running, otherwise infobox
  if _wt_gauge_is_running; then
    # Use current phase progress as baseline
    _wt_update_gauge "$display_msg" "${_WT_PHASE_PROGRESS:-50}"
  else
    local title="Installing"
    [[ "$level" == "error" || "$level" == "validation" ]] && title="Error"
    _wt_infobox "$title" "$display_msg"
  fi
}

# Phase progress tracking for realistic progress bar
# Maps phase names to percentage ranges
_WT_PHASE_PROGRESS=0

# Brief: Get progress percentage for a phase
# Params: $1 - phase name
# Returns: percentage (0-100)
_wt_get_phase_progress() {
  local phase="$1"
  case "$phase" in
  *"Preparing system"*) echo 5 ;;
  *"Installing certificates"*) echo 10 ;;
  *"Installing development tools"*) echo 15 ;;
  *"Applying configurations"*) echo 60 ;;
  *"Configuring system"*) echo 75 ;;
  *"Finalizing"*) echo 90 ;;
  *"Terminal Configuration"*) echo 95 ;;
  *) echo "$_WT_PHASE_PROGRESS" ;;
  esac
}

# Brief: Display phase header using whiptail
# Params: $1 - phase name
# Updates persistent gauge or shows infobox, logs phase header
_wt_show_phase() {
  local phase="$1"
  _wt_log "info" "━━━ $phase ━━━"

  # Get phase-appropriate progress percentage
  _WT_PHASE_PROGRESS=$(_wt_get_phase_progress "$phase")

  if _wt_gauge_is_running; then
    _wt_update_gauge "━━━ $phase ━━━" "$_WT_PHASE_PROGRESS"
  else
    _wt_infobox "$phase" "Starting..."
  fi
}

# Brief: Run command with whiptail gauge progress (pulsing)
# Params: $1 - description, $@ - command to run
# Returns: Exit code of command
# Uses persistent gauge if running, otherwise creates temporary gauge
_wt_run_with_spinner() {
  local description="$1"
  shift

  local output_file
  output_file=$(mktemp)
  local exit_code=0

  # Run command in background, capture output
  "$@" >"$output_file" 2>&1 &
  local cmd_pid=$!

  if _wt_gauge_is_running; then
    # Use persistent gauge - slow crawl animation (never goes backwards)
    local progress=5
    while kill -0 "$cmd_pid" 2>/dev/null; do
      _wt_update_gauge "$description..." "$progress"
      # Slow crawl - cap at 95% until command completes
      if [[ $progress -lt 95 ]]; then
        progress=$((progress + 2))
      fi
      sleep 0.5
    done
    # Silently update to 100% on completion
    _wt_update_gauge "$description..." 100
  else
    # No persistent gauge - create temporary one with slow crawl
    (
      local progress=5
      while kill -0 $cmd_pid 2>/dev/null; do
        echo "$progress"
        # Slow crawl - cap at 95% until command completes
        if [[ $progress -lt 95 ]]; then
          progress=$((progress + 2))
        fi
        sleep 0.5
      done
      echo "100"
    ) | TERM=xterm whiptail --backtitle "$WT_BACKTITLE" --title "Installing" \
      --gauge "$description..." $WT_GAUGE_HEIGHT $WT_WIDTH 0
  fi

  # Wait for command and get exit code
  wait $cmd_pid
  exit_code=$?

  local output
  output=$(<"$output_file")
  rm -f "$output_file"

  if [[ $exit_code -eq 0 ]]; then
    _wt_log "ok" "$description"
  else
    _wt_log "fail" "$description"
    if [[ -n "$output" ]]; then
      # Temporarily stop gauge to show error
      local gauge_was_running=false
      if _wt_gauge_is_running; then
        gauge_was_running=true
        _wt_stop_persistent_gauge
      fi
      # Strip ANSI escape codes for clean display
      local clean_output
      clean_output=$(printf '%s' "${output:0:1000}" | sed 's/\x1b\[[0-9;]*m//g')
      _wt --backtitle "$WT_BACKTITLE" --title "Error" \
        --scrolltext --msgbox "Failed: $description\n\n$clean_output$WT_NAV_HINTS" $WT_HEIGHT_LARGE $WT_WIDTH
      # Restart gauge with preserved title
      if [[ "$gauge_was_running" == true ]]; then
        _wt_start_persistent_gauge "${_WT_GAUGE_TITLE:-Installing}"
      fi
    fi
  fi
  return $exit_code
}

# Brief: Ask yes/no question using whiptail
# Params: $1 - question text, $2 - default ("Y" or "N")
# Returns: 0 for yes, 1 for no
_wt_ask_yes_no() {
  local question="$1"
  local default="${2:-N}"

  local wt_default="--defaultno"
  [[ "$default" == "Y" || "$default" == "y" ]] && wt_default=""

  if _wt --backtitle "$WT_BACKTITLE" --title "Confirm" \
    $wt_default --yesno "$question$WT_NAV_HINTS" $WT_HEIGHT_MEDIUM $WT_WIDTH; then
    return 0
  else
    return 1
  fi
}
