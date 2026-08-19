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
  source "${DEVBASE_ROOT}/libs/bootstrap/bootstrap-config.sh"
}

teardown() {
  common_teardown
}

@test "load_environment_configuration rejects every protected path variable" {
  # org.env comes from a separate, organisation-controlled repository. These
  # variables locate devbase's own libraries and templates, so an override
  # would redirect what the installer sources and copies.
  local protected=(DEVBASE_ROOT DEVBASE_LIBS DEVBASE_DOT DEVBASE_FILES DEVBASE_ENVS DEVBASE_DOCS)

  for var in "${protected[@]}"; do
    mkdir -p "${TEST_DIR}/custom/config"
    printf '%s=/tmp/override\n' "$var" >"${TEST_DIR}/custom/config/org.env"

    DEVBASE_CUSTOM_DIR="${TEST_DIR}/custom"
    DEVBASE_ENVS="${TEST_DIR}"

    run load_environment_configuration
    assert_failure
    assert_output --partial "$var"
  done
}

@test "load_environment_configuration fails when default env missing" {
  DEVBASE_CUSTOM_DIR=""
  DEVBASE_ENVS="${TEST_DIR}/missing"

  run load_environment_configuration
  assert_failure
  assert_output --partial "Environment file not found"
}

@test "find_custom_directory fails when explicit custom dir incomplete" {
  mkdir -p "${TEST_DIR}/custom/config"

  DEVBASE_CUSTOM_DIR="${TEST_DIR}/custom"

  run find_custom_directory
  assert_failure
  assert_output --partial "Custom config is incomplete"
}
