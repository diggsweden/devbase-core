#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'

setup() {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
}

@test "DEVBASE_COLORS array is populated with expected color codes" {
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  
  [[ -n "${DEVBASE_COLORS[NC]}" ]]
  [[ -n "${DEVBASE_COLORS[RED]}" ]]
  [[ -n "${DEVBASE_COLORS[GREEN]}" ]]
  [[ -n "${DEVBASE_COLORS[YELLOW]}" ]]
  [[ -n "${DEVBASE_COLORS[BLUE]}" ]]
  [[ -n "${DEVBASE_COLORS[CYAN]}" ]]
  [[ -n "${DEVBASE_COLORS[BOLD]}" ]]
}

@test "DEVBASE_COLORS contains correct ANSI escape codes" {
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  
  [[ "${DEVBASE_COLORS[NC]}" == '\033[0m' ]]
  [[ "${DEVBASE_COLORS[RED]}" == '\033[0;31m' ]]
  [[ "${DEVBASE_COLORS[GREEN]}" == '\033[0;32m' ]]
  [[ "${DEVBASE_COLORS[BOLD]}" == '\033[1m' ]]
}

@test "DEVBASE_SYMBOLS array is populated with expected symbols" {
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  
  [[ -n "${DEVBASE_SYMBOLS[ARROW]}" ]]
  [[ -n "${DEVBASE_SYMBOLS[BULLET]}" ]]
  [[ -n "${DEVBASE_SYMBOLS[CHECK]}" ]]
  [[ -n "${DEVBASE_SYMBOLS[CROSS]}" ]]
  [[ -n "${DEVBASE_SYMBOLS[WARN]}" ]]
  [[ -n "${DEVBASE_SYMBOLS[INFO]}" ]]
  [[ -n "${DEVBASE_SYMBOLS[PROGRESS]}" ]]
}

@test "DEVBASE_SYMBOLS contains correct Unicode symbols" {
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  
  [[ "${DEVBASE_SYMBOLS[ARROW]}" == '→' ]]
  [[ "${DEVBASE_SYMBOLS[CHECK]}" == '✓' ]]
  [[ "${DEVBASE_SYMBOLS[CROSS]}" == '✗' ]]
  [[ "${DEVBASE_SYMBOLS[WARN]}" == '‼' ]]
  [[ "${DEVBASE_SYMBOLS[INFO]}" == 'ⓘ' ]]
  [[ "${DEVBASE_SYMBOLS[PROGRESS]}" == '↻' ]]
}

@test "both arrays are declared as global associative arrays" {
  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    declare -p DEVBASE_COLORS | grep -q 'declare -.*A'
  "
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}' stderr: '${stderr}'"
  assert_success
  
  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    declare -p DEVBASE_SYMBOLS | grep -q 'declare -.*A'
  "
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}' stderr: '${stderr}'"
  assert_success
}

@test "color codes work for terminal formatting" {
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  
  local test_output
  test_output=$(printf "%b%s%b" "${DEVBASE_COLORS[RED]}" "test" "${DEVBASE_COLORS[NC]}")
  
  [[ "$test_output" == $'\033[0;31mtest\033[0m' ]]
}

@test "all required UI colors are defined" {
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  
  [[ -n "${DEVBASE_COLORS[BOLD_CYAN]}" ]]
  [[ -n "${DEVBASE_COLORS[BOLD_BLUE]}" ]]
  [[ -n "${DEVBASE_COLORS[BOLD_GREEN]}" ]]
  [[ -n "${DEVBASE_COLORS[BOLD_WHITE]}" ]]
  [[ -n "${DEVBASE_COLORS[BOLD_YELLOW]}" ]]
  [[ -n "${DEVBASE_COLORS[DIM]}" ]]
  [[ -n "${DEVBASE_COLORS[BLINK_SLOW]}" ]]
}

@test "all required symbols are defined for UI consistency" {
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  
  [[ -n "${DEVBASE_SYMBOLS[SUBITEM]}" ]]
  [[ -n "${DEVBASE_SYMBOLS[VALIDATION_ERROR]}" ]]
  
  [[ "${DEVBASE_SYMBOLS[SUBITEM]}" == '•' ]]
  [[ "${DEVBASE_SYMBOLS[VALIDATION_ERROR]}" == '⊗' ]]
}
