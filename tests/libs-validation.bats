#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155,SC2218
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
  source_core_libs
}

teardown() {
  common_teardown
}

@test "validate_not_empty succeeds for non-empty string" {
  run --separate-stderr validate_not_empty 'test_value' 'test description'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_not_empty fails for empty string" {
  run --separate-stderr validate_not_empty '' 'test description'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$stderr" == *"required but was empty"* ]] || [[ "$output" == *"required but was empty"* ]]
}

@test "validate_file_exists succeeds for existing file" {
  local test_file="${TEST_DIR}/testfile"
  touch "$test_file"
  
  run --separate-stderr validate_file_exists "$test_file" 'test file'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_file_exists fails for non-existing file" {
  run --separate-stderr validate_file_exists "${TEST_DIR}/nonexistent" 'test file'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$stderr" == *"not found"* ]] || [[ "$output" == *"not found"* ]]
}

@test "validate_dir_exists succeeds for existing directory" {
  local test_dir="${TEST_DIR}/testdir"
  mkdir -p "$test_dir"
  
  run --separate-stderr validate_dir_exists "$test_dir" 'test directory'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_dir_exists fails for non-existing directory" {
  run --separate-stderr validate_dir_exists "${TEST_DIR}/nonexistent" 'test directory'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$stderr" == *"not found"* ]] || [[ "$output" == *"not found"* ]]
}

@test "validate_url succeeds for valid HTTP URL" {
  run --separate-stderr validate_url 'http://example.com' 'test url'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_url succeeds for valid HTTPS URL" {
  run --separate-stderr validate_url 'https://example.com:8080/path' 'test url'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_url fails for invalid URL" {
  run --separate-stderr validate_url 'not-a-url' 'test url'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$stderr" == *"Invalid URL"* ]] || [[ "$output" == *"Invalid URL"* ]]
}

@test "validate_var_set succeeds for set variable" {
  export TEST_VAR='value'
  
  run --separate-stderr validate_var_set 'TEST_VAR'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_var_set fails for unset variable" {
  unset NONEXISTENT_VAR 2>/dev/null || true
  
  run --separate-stderr validate_var_set 'NONEXISTENT_VAR'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$stderr" == *"not set"* ]] || [[ "$output" == *"not set"* ]]
}
