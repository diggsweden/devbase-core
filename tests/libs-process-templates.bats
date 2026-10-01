#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

@test "parse_url extracts protocol from HTTP URL" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/process-templates.sh' >/dev/null 2>&1
    parse_url 'http://example.com:8080/path' 'protocol'
  "
  
  assert_success
  assert_output "http"
}

@test "parse_url extracts protocol from HTTPS URL" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/process-templates.sh' >/dev/null 2>&1
    parse_url 'https://registry.example.com/path' 'protocol'
  "
  
  assert_success
  assert_output "https"
}

@test "parse_url extracts host from URL" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/process-templates.sh' >/dev/null 2>&1
    parse_url 'http://example.com:8080/path' 'host'
  "
  
  assert_success
  assert_output "example.com"
}

@test "parse_url extracts host from URL with auth" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/process-templates.sh' >/dev/null 2>&1
    parse_url 'http://user:pass@example.com:8080' 'host'
  "
  
  assert_success
  assert_output "example.com"
}

@test "parse_url extracts explicit port" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/process-templates.sh' >/dev/null 2>&1
    parse_url 'http://example.com:8080/path' 'port'
  "
  
  assert_success
  assert_output "8080"
}

@test "parse_url returns default port 80 for HTTP without port" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/process-templates.sh' >/dev/null 2>&1
    parse_url 'http://example.com/path' 'port'
  "
  
  assert_success
  assert_output "80"
}

@test "parse_url returns default port 443 for HTTPS without port" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/process-templates.sh' >/dev/null 2>&1
    parse_url 'https://example.com/path' 'port'
  "
  
  assert_success
  assert_output "443"
}

@test "detect_clipboard_utility returns __smart_copy when no clipboard tool available" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export PATH='/usr/bin:/bin'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/process-templates.sh' >/dev/null 2>&1
    detect_clipboard_utility
  "
  
  assert_success
}

# Organization overrides replace staging copies, not their source templates.

_source_templates() {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  source "${DEVBASE_ROOT}/libs/define-colors.sh" >/dev/null 2>&1
  source "${DEVBASE_ROOT}/libs/validation.sh" >/dev/null 2>&1
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh" >/dev/null 2>&1
  source "${DEVBASE_ROOT}/libs/process-templates.sh" >/dev/null 2>&1
}

@test "copy_custom_templates_to_temp ignores a template with no shipped counterpart" {
  _source_templates
  mkdir -p "${TEST_DIR}/vanilla/.config/git" "${TEST_DIR}/custom"
  touch "${TEST_DIR}/vanilla/.config/git/config.template"
  printf 'override\n' >"${TEST_DIR}/custom/config.template"
  printf 'unexpected\n' >"${TEST_DIR}/custom/attacker-supplied.template"
  export _DEVBASE_CUSTOM_TEMPLATES="${TEST_DIR}/custom"

  run copy_custom_templates_to_temp "${TEST_DIR}/vanilla"

  assert_success
  run cat "${TEST_DIR}/vanilla/.config/git/config.template"
  assert_output "override"
  run bash -c "find '${TEST_DIR}/vanilla' -name 'attacker-supplied.template' | wc -l"
  assert_output "0"
}
