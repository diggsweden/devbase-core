#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Brief: Define global color codes and UI symbols for DevBase output formatting
# Usage: Source this file to access DEVBASE_COLORS and DEVBASE_SYMBOLS associative arrays
# NOTE: These arrays are available to all sourced scripts but cannot be
# exported to subshells (bash limitation with associative arrays)
declare -gA DEVBASE_COLORS
declare -gA DEVBASE_SYMBOLS

# Color codes - only the ones actually used
# shellcheck disable=SC2034 # DEVBASE_COLORS is used throughout the codebase
DEVBASE_COLORS=(
  [NC]='\033[0m' # No Color / Reset
  [RED]='\033[0;31m'
  [GREEN]='\033[0;32m'
  [YELLOW]='\033[0;33m'
  [BLUE]='\033[0;34m'
  [CYAN]='\033[0;36m'
  [BOLD]='\033[1m'
  [BOLD_CYAN]='\033[1;36m'
  [BOLD_BLUE]='\033[1;34m'
  [BOLD_GREEN]='\033[1;32m'
  [BOLD_WHITE]='\033[1;37m'
  [BOLD_YELLOW]='\033[1;33m'
  [DIM]='\033[2m'
  [BLINK_SLOW]='\033[5m'
  [LIGHTYELLOW]='\e[0;93m'
  [WHITE]='\033[0;37m'
  [GRAY]='\033[0;90m'
)

# UI symbols - Consistent prefix system:
# → for actions/phases
# • for sub-items (replacing ├─)
# ↻ for progress/ongoing
# ✓ for success/completion
# ✗ for errors/failures
# ⓘ for information
# ‼ for warnings
# shellcheck disable=SC2034 # DEVBASE_SYMBOLS is used throughout the codebase
DEVBASE_SYMBOLS=(
  [ARROW]='→'
  [BULLET]='•'
  [CHECK]='✓'
  [CROSS]='✗'
  [WARN]='‼'
  [INFO]='ⓘ'
  [PROGRESS]='↻'
  [SUBITEM]='•'
  [VALIDATION_ERROR]='⊗'
)
