#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# =============================================================================
# ERROR HANDLING POLICY
# =============================================================================
# Fatal (die):  Missing prerequisites, corrupted config, security violations.
# Soft (return 1):  Optional features, network glitches, missing extras.
# The ERR trap below logs failures but does not abort - callers decide severity.
# =============================================================================

# Error trap - log command failures to whiptail or terminal.
# Note: Without `set -e`, the ERR trap only fires for commands whose failure
# propagates (i.e., not inside `if`/`while`/`&&`/`||` guards). The `-E` flag
# ensures the trap inherits into functions and subshells.
trap '_handle_error_trap "$LINENO" "$BASH_COMMAND"' ERR

_handle_error_trap() {
  local line="$1"
  local cmd="$2"
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]]; then
    _wt_log "fail" "Error on line $line: $cmd"
  else
    printf "Error on line %d, command: %s\n" "$line" "$cmd"
  fi
}

_get_trap_command() {
  local trap_line="$1"
  local signal="$2"
  local cmd=""

  if [[ "$trap_line" =~ ^trap\ --\ \'(.*)\'\ "$signal"$ ]]; then
    cmd="${BASH_REMATCH[1]}"
  fi

  printf "%s" "$cmd"
}

_DEVBASE_PREV_TRAP_INT="$(_get_trap_command "$(trap -p INT)" "INT")"
_DEVBASE_PREV_TRAP_TERM="$(_get_trap_command "$(trap -p TERM)" "TERM")"

_run_prev_trap() {
  local signal="$1"
  local prev_cmd=""

  case "$signal" in
  INT)
    prev_cmd="${_DEVBASE_PREV_TRAP_INT:-}"
    ;;
  TERM)
    prev_cmd="${_DEVBASE_PREV_TRAP_TERM:-}"
    ;;
  esac

  if [[ -n "$prev_cmd" && "$prev_cmd" != "handle_interrupt" ]]; then
    if [[ "$prev_cmd" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && declare -f "$prev_cmd" &>/dev/null; then
      "$prev_cmd"
    else
      printf "Skipping unsafe prior trap for %s\n" "$signal" >&2
    fi
  fi
}

# Brief: Handle SIGINT/SIGTERM by cleaning up and exiting with code 130
# Params: $1 - signal name (INT or TERM)
# Uses: cleanup_temp_directory, stop_installation_progress (functions)
# Returns: exits with 130
# Side-effects: Cleans temp directory, stops progress display, prints cancellation message, exits
handle_interrupt() {
  local signal="${1:-INT}"
  cleanup_temp_directory
  # Stop persistent gauge first (if running)
  stop_installation_progress 2>/dev/null || true
  # In whiptail mode, show progress log then cancellation dialog
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
    # Show what was completed before cancellation (if any progress was made)
    if [[ ${#_WT_LOG[@]} -gt 0 ]]; then
      _wt_show_log "Progress Before Cancellation"
    fi
    whiptail --backtitle "$WT_BACKTITLE" --title "Cancelled" \
      --msgbox "Installation cancelled by user (Ctrl+C)$WT_NAV_HINTS" "$WT_HEIGHT_SMALL" "$WT_WIDTH" 2>/dev/null || true
  else
    printf "\n\nInstallation cancelled by user (Ctrl+C)\n" >&2
  fi
  _run_prev_trap "$signal"
  exit 130
}

trap cleanup_temp_directory EXIT
trap 'handle_interrupt INT' INT
trap 'handle_interrupt TERM' TERM
