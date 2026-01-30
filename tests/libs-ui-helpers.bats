#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
}

teardown() {
  common_teardown
}

@test "show_progress handles step level in gum mode" {
  # Skip if gum is not available
  if ! command -v gum &>/dev/null; then
    skip "gum not available"
  fi
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_TUI_MODE='gum'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    show_progress step 'Test step message'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "Test step message"
}

@test "show_progress handles success level in gum mode" {
  # Skip if gum is not available
  if ! command -v gum &>/dev/null; then
    skip "gum not available"
  fi
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_TUI_MODE='gum'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    show_progress success 'Test success message'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "Test success message"
}

@test "show_phase displays phase header in gum mode" {
  # Skip if gum is not available
  if ! command -v gum &>/dev/null; then
    skip "gum not available"
  fi
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_TUI_MODE='gum'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    show_phase 'Test Phase'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "Test Phase"
}

@test "error_msg prints error with cross symbol" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_TUI_MODE='none'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    error_msg 'Test error message'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "Test error message"
  assert_output --partial "✗"
}

@test "warn_msg prints warning with warn symbol" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_TUI_MODE='none'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    warn_msg 'Test warning message'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "Test warning message"
  assert_output --partial "‼"
}

@test "success_msg prints success with check symbol" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_TUI_MODE='none'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    success_msg 'Test success message'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "Test success message"
  assert_output --partial "✓"
}

@test "info_msg prints info with info symbol" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_TUI_MODE='none'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    info_msg 'Test info message'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "Test info message"
  assert_output --partial "ⓘ"
}

@test "_wt_log accumulates log entries" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    _wt_log ok 'First message'
    _wt_log fail 'Second message'
    _wt_log info 'Third message'
    printf '%s\n' \"\${_WT_LOG[@]}\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "✓ First message"
  assert_output --partial "✗ Second message"
  assert_output --partial "• Third message"
}

@test "run_with_spinner executes command in gum mode" {
  # Skip if gum is not available
  if ! command -v gum &>/dev/null; then
    skip "gum not available"
  fi
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_TUI_MODE='gum'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    run_with_spinner 'Test command' true
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
}

@test "run_with_spinner returns failure exit code on command failure" {
  # Skip if gum is not available
  if ! command -v gum &>/dev/null; then
    skip "gum not available"
  fi
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_TUI_MODE='gum'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    run_with_spinner 'Failing command' false
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_failure
}
