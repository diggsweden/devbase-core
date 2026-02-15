#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup_isolated
  source_core_libs
  source "${DEVBASE_ROOT}/libs/utils.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/bootstrap-config.sh"
}

teardown() {
  common_teardown
}

@test "load_environment_configuration fails when protected vars exist" {
  mkdir -p "${TEST_DIR}/custom/config"
  cat > "${TEST_DIR}/custom/config/org.env" << 'EOF'
DEVBASE_ROOT=/tmp/override
EOF

  DEVBASE_CUSTOM_DIR="${TEST_DIR}/custom"
  DEVBASE_ENVS="${TEST_DIR}"

  run load_environment_configuration
  assert_failure
  assert_output --partial "override protected variable"
}

@test "load_environment_configuration fails when default env missing" {
  DEVBASE_CUSTOM_DIR=""
  DEVBASE_ENVS="${TEST_DIR}/missing"

  run load_environment_configuration
  assert_failure
  assert_output --partial "Environment file not found"
}

@test "find_custom_directory skips incomplete config" {
  mkdir -p "${TEST_DIR}/custom/config"

  DEVBASE_CUSTOM_DIR="${TEST_DIR}/custom"

  run find_custom_directory
  assert_success
  [[ -z "${DEVBASE_CUSTOM_DIR}" ]]
}
