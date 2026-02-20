#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155,SC2218
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
  # Alias for backward compatibility with tests using TEMP_DIR
  TEMP_DIR="$TEST_DIR"
  export TEMP_DIR
}

teardown() {
  common_teardown
}

@test "cleanup_temp_directory validates path pattern before removal" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/utils.sh"

  local safe_temp="${BATS_TEST_TMPDIR}/devbase.ABC123"
  mkdir -p "$safe_temp"
  export _DEVBASE_TEMP="$safe_temp"

  cleanup_temp_directory

  [[ ! -d "$safe_temp" ]]
}

@test "cleanup_temp_directory rejects unsafe paths" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/utils.sh"

  local unsafe_temp="${HOME}/important"
  mkdir -p "$unsafe_temp"
  export _DEVBASE_TEMP="$unsafe_temp"

  cleanup_temp_directory

  [[ -d "$unsafe_temp" ]]
}

@test "cleanup_temp_directory handles missing directory gracefully" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/utils.sh"

  export _DEVBASE_TEMP="${BATS_TEST_TMPDIR}/devbase.nonexistent"

  run --separate-stderr cleanup_temp_directory
  assert_success
}

@test "_get_theme_display_name returns correct display names" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  source <(sed -n '/^_get_theme_display_name()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  result=$(_get_theme_display_name "everforest-dark")
  [[ "$result" == "Everforest Dark" ]]

  result=$(_get_theme_display_name "catppuccin-mocha")
  [[ "$result" == "Catppuccin Mocha" ]]

  result=$(_get_theme_display_name "tokyonight-night")
  [[ "$result" == "Tokyo Night" ]]

  result=$(_get_theme_display_name "gruvbox-light")
  [[ "$result" == "Gruvbox Light" ]]
}

@test "_get_theme_display_name returns original for unknown themes" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  source <(sed -n '/^_get_theme_display_name()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  result=$(_get_theme_display_name "unknown-theme")
  [[ "$result" == "unknown-theme" ]]
}

@test "_get_font_display_name returns correct font names" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  source <(sed -n '/^_get_font_display_name()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  result=$(_get_font_display_name "jetbrains-mono")
  [[ "$result" == "JetBrains Mono Nerd Font" ]]

  result=$(_get_font_display_name "firacode")
  [[ "$result" == "Fira Code Nerd Font" ]]

  result=$(_get_font_display_name "monaspace")
  [[ "$result" == "Monaspace Nerd Font" ]]
}

@test "_get_font_display_name returns original for unknown fonts" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  source <(sed -n '/^_get_font_display_name()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  result=$(_get_font_display_name "unknown-font")
  [[ "$result" == "unknown-font" ]]
}

@test "install.sh avoids duplicate library sourcing" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  run bash -c "grep -q 'process-templates.sh' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_failure

  run bash -c "grep -q 'configure-shell.sh' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_failure
}

@test "install.sh defines phase helpers" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  run bash -c "grep -q 'run_preflight_phase' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_success

  run bash -c "grep -q 'run_configuration_phase' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_success

  run bash -c "grep -q 'run_installation_phase' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_success

  run bash -c "grep -q 'run_finalize_phase' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_success
}

@test "run_configuration_phase fails on step error" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  run bash -c "
    bootstrap_for_configuration() { return 1; }
    collect_user_configuration() { return 0; }
    display_configuration_summary() { return 0; }
    eval \"\$(sed -n '/^run_configuration_phase()/,/^}/p' '${DEVBASE_ROOT}/libs/install.sh')\"
    run_configuration_phase
  "

  assert_failure
}

@test "run_installation_phase stops progress on failure" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  run bash -c "
    start_installation_progress() { :; }
    stop_installation_progress() { echo stopped; }
    show_phase() { :; }
    prepare_system() { return 1; }
    perform_installation() { return 0; }
    write_installation_summary() { return 0; }
    eval \"\$(sed -n '/^run_installation_phase()/,/^}/p' '${DEVBASE_ROOT}/libs/install.sh')\"
    run_installation_phase
  "

  assert_failure
  assert_output --partial "stopped"
}

@test "validate_source_repository checks required directories" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  cd "${DEVBASE_ROOT}"

  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source <(sed -n '/^validate_source_repository()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  run validate_source_repository
  assert_success
}

@test "setup_installation_paths validates required variables" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export _DEVBASE_TEMP="${BATS_TEST_TMPDIR}/devbase.test123"

  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source <(sed -n '/^setup_installation_paths()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  run setup_installation_paths
  assert_success
}
