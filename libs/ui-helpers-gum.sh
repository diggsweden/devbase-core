#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Gum TUI backend for ui-helpers
# These functions are called by the dispatchers in ui-helpers.sh

set -uo pipefail

# Brief: Display formatted progress message using gum
# Params: $1 - level (step/info/success/warning/error/validation), $@ - message text
_gum_show_progress() {
  local level="$1"
  shift
  local message="$*"

  case "$level" in
  step)
    gum style --foreground 212 "→ $message"
    ;;
  info)
    gum style --foreground 240 "  $message"
    ;;
  success)
    gum style --foreground 82 "  ✓ $message"
    ;;
  warning)
    gum style --foreground 214 "  ⚠ $message"
    ;;
  error)
    gum style --foreground 196 "  ✗ $message" >&2
    ;;
  validation)
    gum style --foreground 196 "  ✗ $message"
    ;;
  *)
    echo "  $message"
    ;;
  esac
}

# Brief: Display phase header using gum
# Params: $1 - phase name
_gum_show_phase() {
  local phase="$1"
  echo
  gum style \
    --foreground 212 \
    --bold \
    "━━━ $phase ━━━"
  echo
}

# Brief: Run command with gum spinner
# Params: $1 - description, $@ - command to run
# Returns: Exit code of command
_gum_run_with_spinner() {
  local description="$1"
  shift

  # --show-error displays command output only on failure
  gum spin --spinner dot --show-error --title "$description" -- "$@"
  return $?
}

# Brief: Ask yes/no question using gum confirm
# Params: $1 - question text, $2 - default ("Y" or "N")
# Returns: 0 for yes, 1 for no
_gum_ask_yes_no() {
  local question="$1"
  local default="${2:-N}"

  local gum_args=("$question")
  if [[ "$default" == "N" || "$default" == "n" ]]; then
    gum_args+=(--default=false)
  fi
  gum_args+=(--affirmative "Yes" --negative "No")

  if gum confirm "${gum_args[@]}"; then
    return 0
  else
    return 1
  fi
}
