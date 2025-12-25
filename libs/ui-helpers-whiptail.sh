#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Whiptail TUI backend for ui-helpers
# These functions are called by the dispatchers in ui-helpers.sh

set -uo pipefail

# Whiptail dimensions
readonly WT_WIDTH=70
readonly WT_HEIGHT=8
readonly WT_GAUGE_HEIGHT=7
readonly WT_LIST_HEIGHT=20

# Accumulator for whiptail installation log
declare -a _WT_LOG=()

# =============================================================================
# LOW-LEVEL WHIPTAIL PRIMITIVES
# =============================================================================

# Brief: Show a whiptail infobox (non-blocking status message)
# Params: $1 - title, $2 - message
_wt_infobox() {
  local title="$1"
  local message="$2"
  whiptail --backtitle "DevBase Setup" --title "$title" --infobox "$message" $WT_HEIGHT $WT_WIDTH
}

# Brief: Show a whiptail message box (blocking, requires OK)
# Params: $1 - title, $2 - message
_wt_msgbox() {
  local title="$1"
  local message="$2"
  whiptail --backtitle "DevBase Setup" --title "$title" --msgbox "$message" $WT_HEIGHT $WT_WIDTH
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
  ) | whiptail --backtitle "DevBase Setup" --title "$title" --gauge "$message" $WT_GAUGE_HEIGHT $WT_WIDTH 0

  return ${PIPESTATUS[0]}
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
    whiptail --backtitle "DevBase Setup" --title "Error" --msgbox "Command failed:\n\n${output:0:500}" 15 $WT_WIDTH
  fi

  return $exit_code
}

# Brief: Show whiptail progress for multiple steps
# Params: $1 - title, stdin - lines of "percent message"
_wt_progress() {
  local title="$1"
  whiptail --backtitle "DevBase Setup" --title "$title" --gauge "Starting..." $WT_GAUGE_HEIGHT $WT_WIDTH 0
}

# Brief: Add entry to whiptail log
# Params: $1 - status (ok/fail/info), $2 - message
_wt_log() {
  local status="$1"
  local message="$2"
  local icon
  case "$status" in
    ok)   icon="✓" ;;
    fail) icon="✗" ;;
    info) icon="•" ;;
    *)    icon=" " ;;
  esac
  _WT_LOG+=("$icon $message")
}

# Brief: Show accumulated log in scrollable msgbox
_wt_show_log() {
  local title="${1:-Installation Log}"
  local log_text
  log_text=$(printf '%s\n' "${_WT_LOG[@]}")
  whiptail --backtitle "DevBase Setup" --title "$title" --scrolltext --msgbox "$log_text" 20 $WT_WIDTH
  _WT_LOG=()  # Clear log
}

# =============================================================================
# HIGH-LEVEL WHIPTAIL IMPLEMENTATIONS (called by dispatchers)
# =============================================================================

# Brief: Display formatted progress message using whiptail
# Params: $1 - level (step/info/success/warning/error/validation), $@ - message text
_wt_show_progress() {
  local level="$1"
  shift
  local message="$*"

  case "$level" in
  step)
    _wt_infobox "Installing" "$message"
    _wt_log "info" "$message"
    ;;
  info)
    _wt_log "info" "$message"
    ;;
  success)
    _wt_log "ok" "$message"
    ;;
  warning)
    _wt_log "info" "⚠ $message"
    ;;
  error)
    _wt_log "fail" "$message"
    ;;
  validation)
    _wt_log "fail" "$message"
    ;;
  *)
    _wt_log "info" "$message"
    ;;
  esac
}

# Brief: Display phase header using whiptail
# Params: $1 - phase name
_wt_show_phase() {
  local phase="$1"

  # Show previous phase log if any, then start new phase
  if [[ ${#_WT_LOG[@]} -gt 0 ]]; then
    _wt_show_log "Phase Complete"
  fi
  _wt_infobox "$phase" "Starting..."
  _wt_log "info" "━━━ $phase ━━━"
}

# Brief: Run command with whiptail infobox progress
# Params: $1 - description, $@ - command to run
# Returns: Exit code of command
_wt_run_with_spinner() {
  local description="$1"
  shift

  _wt_infobox "Installing" "$description..."
  local output
  local exit_code
  if output=$("$@" 2>&1); then
    exit_code=0
    _wt_log "ok" "$description"
  else
    exit_code=$?
    _wt_log "fail" "$description"
    if [[ -n "$output" ]]; then
      whiptail --backtitle "DevBase Setup" --title "Error" \
        --msgbox "Failed: $description\n\n${output:0:400}" 15 $WT_WIDTH
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

  if whiptail --backtitle "DevBase Setup" --title "Confirm" \
    $wt_default --yesno "$question" 8 60; then
    return 0
  else
    return 1
  fi
}
