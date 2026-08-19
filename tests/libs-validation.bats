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
  
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_not_empty fails for empty string" {
  run --separate-stderr validate_not_empty '' 'test description'
  
  assert_failure
  [[ "$stderr" == *"required but was empty"* ]] || [[ "$output" == *"required but was empty"* ]]
}

@test "validate_file_exists succeeds for existing file" {
  local test_file="${TEST_DIR}/testfile"
  touch "$test_file"
  
  run --separate-stderr validate_file_exists "$test_file" 'test file'
  
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_file_exists fails for non-existing file" {
  run --separate-stderr validate_file_exists "${TEST_DIR}/nonexistent" 'test file'
  
  assert_failure
  [[ "$stderr" == *"not found"* ]] || [[ "$output" == *"not found"* ]]
}

@test "validate_dir_exists succeeds for existing directory" {
  local test_dir="${TEST_DIR}/testdir"
  mkdir -p "$test_dir"
  
  run --separate-stderr validate_dir_exists "$test_dir" 'test directory'
  
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_dir_exists fails for non-existing directory" {
  run --separate-stderr validate_dir_exists "${TEST_DIR}/nonexistent" 'test directory'
  
  assert_failure
  [[ "$stderr" == *"not found"* ]] || [[ "$output" == *"not found"* ]]
}

@test "validate_url succeeds for valid HTTP URL" {
  run --separate-stderr validate_url 'http://example.com' 'test url'
  
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_url succeeds for valid HTTPS URL" {
  run --separate-stderr validate_url 'https://example.com:8080/path' 'test url'
  
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_url fails for invalid URL" {
  run --separate-stderr validate_url 'not-a-url' 'test url'
  
  assert_failure
  [[ "$stderr" == *"Invalid URL"* ]] || [[ "$output" == *"Invalid URL"* ]]
}

@test "validate_var_set succeeds for set variable" {
  export TEST_VAR='value'
  
  run --separate-stderr validate_var_set 'TEST_VAR'
  
  assert_success
  assert [ -z "$stderr" ]
}

@test "validate_var_set fails for unset variable" {
  unset NONEXISTENT_VAR 2>/dev/null || true
  
  run --separate-stderr validate_var_set 'NONEXISTENT_VAR'
  
  assert_failure
  [[ "$stderr" == *"not set"* ]] || [[ "$output" == *"not set"* ]]
}

@test "require_env succeeds when variables are set" {
  export REQUIRED_ONE="value"
  export REQUIRED_TWO="value"

  run --separate-stderr require_env REQUIRED_ONE REQUIRED_TWO

  assert_success
}

@test "require_env fails when variables are missing" {
  unset REQUIRED_MISSING 2>/dev/null || true

  run --separate-stderr require_env REQUIRED_MISSING

  assert_failure
  [[ "$stderr" == *"Required environment variable"* ]] || [[ "$output" == *"Required environment variable"* ]]
}

# The validators below sanitise values that arrive from org.env - a separate,
# organisation-controlled repository - before they are written into generated
# config files. They are the only sanitisation on that path.

@test "validate_hostname accepts an ordinary hostname" {
  run --separate-stderr validate_hostname 'proxy.example.com' 'DEVBASE_PROXY_HOST'
  assert_success
}

@test "validate_hostname rejects shell metacharacters" {
  run --separate-stderr validate_hostname 'proxy.example.com;id' 'DEVBASE_PROXY_HOST'
  assert_failure
  assert [ -n "$stderr" ]
}

@test "validate_hostname rejects command substitution" {
  run --separate-stderr validate_hostname 'host$(id)' 'DEVBASE_PROXY_HOST'
  assert_failure
}

@test "validate_hostname treats an unset value as optional" {
  run --separate-stderr validate_hostname '' 'DEVBASE_PROXY_HOST'
  assert_success
}

@test "validate_port accepts a port inside the valid range" {
  run --separate-stderr validate_port '8080' 'DEVBASE_PROXY_PORT'
  assert_success
}

@test "validate_port rejects a port above the valid range" {
  run --separate-stderr validate_port '65536' 'DEVBASE_PROXY_PORT'
  assert_failure
}

@test "validate_port rejects zero" {
  run --separate-stderr validate_port '0' 'DEVBASE_PROXY_PORT'
  assert_failure
}

@test "validate_port rejects a non-numeric port" {
  run --separate-stderr validate_port '80a' 'DEVBASE_PROXY_PORT'
  assert_failure
}

@test "validate_port reads a leading zero as decimal, not octal" {
  # Bash arithmetic treats 08 as octal and errors out unless 10# forces base 10.
  run --separate-stderr validate_port '08' 'DEVBASE_PROXY_PORT'
  assert_success
  refute_output --partial 'value too great for base'
  assert [ -z "$stderr" ]
}

@test "validate_safe_value rejects shell metacharacters" {
  run --separate-stderr validate_safe_value 'name$(id)' 'GIT_NAME'
  assert_failure
}

@test "validate_safe_value rejects an embedded newline" {
  # A newline here injects an extra line into every generated config file the
  # value is rendered into.
  run --separate-stderr validate_safe_value "$(printf 'good\nInjected=1')" 'GIT_NAME'
  assert_failure
}

@test "validate_safe_value accepts an apostrophe in a personal name" {
  run --separate-stderr validate_safe_value "O'Brien" 'GIT_NAME'
  assert_success
}

@test "validate_email rejects shell metacharacters" {
  run --separate-stderr validate_email 'user@example.com;id' 'GIT_EMAIL'
  assert_failure
}

@test "validate_email accepts an ordinary address" {
  run --separate-stderr validate_email 'user@example.com' 'GIT_EMAIL'
  assert_success
}
