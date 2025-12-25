#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# UI Helpers - Dispatcher and TUI-agnostic functions
# Backend implementations are in ui-helpers-gum.sh and ui-helpers-whiptail.sh

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 1
  else
    exit 1
  fi
fi

# Source backend implementations
# shellcheck source=./ui-helpers-gum.sh
source "${DEVBASE_ROOT}/libs/ui-helpers-gum.sh"
# shellcheck source=./ui-helpers-whiptail.sh
source "${DEVBASE_ROOT}/libs/ui-helpers-whiptail.sh"

# =============================================================================
# DISPATCHER FUNCTIONS
# These route to the appropriate backend based on DEVBASE_TUI_MODE
# Default: gum (if available), fallback to whiptail, then plain text
# =============================================================================

# Brief: Check if gum should be used
# Returns: 0 if gum should be used, 1 otherwise
_use_gum() {
  [[ "${DEVBASE_TUI_MODE:-}" == "none" ]] && return 1
  [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && return 1
  command -v gum &>/dev/null
}

# Brief: Check if whiptail should be used
# Returns: 0 if whiptail should be used, 1 otherwise
_use_whiptail() {
  [[ "${DEVBASE_TUI_MODE:-}" == "none" ]] && return 1
  [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null && return 0
  # Fallback to whiptail if gum not available
  ! command -v gum &>/dev/null && command -v whiptail &>/dev/null
}

# Brief: Display formatted progress messages with color and symbols
# Params: $1 - level (step/info/success/warning/error/validation), $@ - message text
# Uses: DEVBASE_TUI_MODE (global)
# Returns: 0 always
show_progress() {
  if _use_gum; then
    _gum_show_progress "$@"
  elif _use_whiptail; then
    _wt_show_progress "$@"
  else
    _fallback_show_progress "$@"
  fi
}

# Brief: Display a major installation phase header
# Params: $1 - phase name
# Uses: DEVBASE_TUI_MODE (global)
# Returns: 0 always
show_phase() {
  if _use_gum; then
    _gum_show_phase "$@"
  elif _use_whiptail; then
    _wt_show_phase "$@"
  else
    _fallback_show_phase "$@"
  fi
}

# Brief: Run a command with spinner/progress indicator
# Params: $1 - description, $@ - command to run
# Uses: DEVBASE_TUI_MODE (global)
# Returns: Exit code of command
run_with_spinner() {
  if _use_gum; then
    _gum_run_with_spinner "$@"
  elif _use_whiptail; then
    _wt_run_with_spinner "$@"
  else
    _fallback_run_with_spinner "$@"
  fi
}

# Brief: Ask yes/no question and return user response
# Params: $1 - question text, $2 - default ("Y" or "N", default: "N")
# Uses: DEVBASE_TUI_MODE (global)
# Returns: 0 for yes, 1 for no
ask_yes_no() {
  if _use_gum; then
    _gum_ask_yes_no "$@"
  elif _use_whiptail; then
    _wt_ask_yes_no "$@"
  else
    _fallback_ask_yes_no "$@"
  fi
}

# =============================================================================
# FALLBACK IMPLEMENTATIONS (for testing or when no TUI available)
# =============================================================================

_fallback_show_progress() {
  local level="$1"
  shift
  local message="$*"

  case "$level" in
  step)
    echo "→ $message"
    ;;
  success)
    echo "✓ $message"
    ;;
  warning)
    echo "⚠ $message"
    ;;
  error | validation)
    echo "✗ $message" >&2
    ;;
  *)
    echo "$message"
    ;;
  esac
}

_fallback_show_phase() {
  local phase="$1"
  echo
  echo "━━━ $phase ━━━"
  echo
}

_fallback_run_with_spinner() {
  local description="$1"
  shift
  echo "→ $description..."
  "$@"
}

_fallback_ask_yes_no() {
  local default="${2:-N}"
  if [[ "$default" == "Y" || "$default" == "y" ]]; then
    return 0
  else
    return 1
  fi
}

# =============================================================================
# TUI-AGNOSTIC MESSAGE FUNCTIONS
# These work the same regardless of TUI mode
# =============================================================================

# Brief: Print error message with symbol (stderr)
# Params: $1 - message text
error_msg() {
  printf "  %b%s%b %s\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_SYMBOLS[CROSS]}" "${DEVBASE_COLORS[NC]}" "$1" >&2
}

# Brief: Print warning message with symbol (stderr)
# Params: $1 - message text
warn_msg() {
  printf "  %b%s%b %s\n" "${DEVBASE_COLORS[YELLOW]}" "${DEVBASE_SYMBOLS[WARN]}" "${DEVBASE_COLORS[NC]}" "$1" >&2
}

# Brief: Print success message with symbol
# Params: $1 - message text
success_msg() {
  printf "  %b%s%b %s\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_SYMBOLS[CHECK]}" "${DEVBASE_COLORS[NC]}" "$1"
}

# Brief: Print info message with symbol
# Params: $1 - message text
info_msg() {
  printf "  %b%s%b %s\n" "${DEVBASE_COLORS[CYAN]}" "${DEVBASE_SYMBOLS[INFO]}" "${DEVBASE_COLORS[NC]}" "$1"
}
