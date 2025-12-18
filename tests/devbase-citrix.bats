#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Tests for devbase-citrix fish function

bats_require_minimum_version 1.5.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  TEST_DIR="$(temp_make)"
  export TEST_DIR
  setup_isolated_home
  
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_CITRIX_FISH="${DEVBASE_ROOT}/dot/.config/fish/functions/devbase-citrix.fish"
}

teardown() {
  safe_temp_del "$TEST_DIR"
}

# Helper to run fish commands with the devbase-citrix function loaded
run_fish_citrix() {
  fish -c "source '$DEVBASE_CITRIX_FISH'; $*"
}

@test "devbase-citrix.fish function file exists" {
  assert_file_exists "$DEVBASE_CITRIX_FISH"
}

@test "devbase-citrix --help shows usage" {
  run run_fish_citrix "devbase-citrix --help"
  
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "--check"
  assert_output --partial "Citrix Workspace App"
}

@test "devbase-citrix --check shows pinned version" {
  run run_fish_citrix "devbase-citrix --check"
  
  assert_success
  assert_output --partial "Pinned version:"
  assert_output --partial "Packages:"
  assert_output --partial "icaclient_"
  assert_output --partial "_amd64.deb"
}

@test "__citrix_get_version returns version string" {
  run run_fish_citrix "__citrix_get_version"
  
  assert_success
  # Version format: XX.XX.XX.XXX (e.g., 25.08.10.111)
  assert_output --regexp '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
}

@test "__citrix_get_static_urls returns two URLs" {
  run run_fish_citrix "__citrix_get_static_urls"
  
  assert_success
  # Should have icaclient and ctxusb URLs
  assert_output --partial "icaclient_"
  assert_output --partial "ctxusb_"
  assert_output --partial "downloads.citrix.com"
  assert_output --partial "_amd64.deb"
}

@test "__citrix_get_static_urls includes version in URLs" {
  local citrix_ver
  citrix_ver=$(run_fish_citrix "__citrix_get_version")
  
  run run_fish_citrix "__citrix_get_static_urls"
  
  assert_success
  assert_output --partial "icaclient_${citrix_ver}_amd64.deb"
  assert_output --partial "ctxusb_${citrix_ver}_amd64.deb"
}

@test "devbase-citrix unknown option shows error" {
  run run_fish_citrix "devbase-citrix --invalid"
  
  assert_failure
  assert_output --partial "Unknown option"
}

@test "citrix version file contains renovate comment" {
  run grep -E "^# renovate:" "$DEVBASE_CITRIX_FISH"
  
  assert_success
  assert_output --partial "datasource=custom.citrix"
}

@test "citrix version is valid format" {
  run run_fish_citrix "__citrix_get_version"
  
  assert_success
  # Citrix versions are: YY.MM.PATCH.BUILD (e.g., 25.08.10.111)
  [[ "$output" =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]+\.[0-9]+$ ]]
}
