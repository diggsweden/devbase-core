#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
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
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
  
  local safe_temp="/tmp/devbase.ABC123"
  mkdir -p "$safe_temp"
  export _DEVBASE_TEMP="$safe_temp"
  
  source <(grep -A20 "^cleanup_temp_directory()" "${DEVBASE_ROOT}/libs/install.sh")
  
  cleanup_temp_directory
  
  [[ ! -d "$safe_temp" ]]
}

@test "cleanup_temp_directory rejects unsafe paths" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
  
  local unsafe_temp="${HOME}/important"
  mkdir -p "$unsafe_temp"
  export _DEVBASE_TEMP="$unsafe_temp"
  
  source <(grep -A20 "^cleanup_temp_directory()" "${DEVBASE_ROOT}/libs/install.sh")
  
  cleanup_temp_directory
  
  [[ -d "$unsafe_temp" ]]
}

@test "cleanup_temp_directory handles missing directory gracefully" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
  
  export _DEVBASE_TEMP="/tmp/devbase.nonexistent"
  
  source <(grep -A20 "^cleanup_temp_directory()" "${DEVBASE_ROOT}/libs/install.sh")
  
  run --separate-stderr cleanup_temp_directory
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}' stderr: '${stderr}'"
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
  source <(grep -A10 "^_get_font_display_name()" "${DEVBASE_ROOT}/libs/install.sh")
  
  result=$(_get_font_display_name "jetbrains-mono")
  [[ "$result" == "JetBrains Mono Nerd Font" ]]
  
  result=$(_get_font_display_name "firacode")
  [[ "$result" == "Fira Code Nerd Font" ]]
  
  result=$(_get_font_display_name "monaspace")
  [[ "$result" == "Monaspace Nerd Font" ]]
}

@test "_get_font_display_name returns original for unknown fonts" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  source <(grep -A10 "^_get_font_display_name()" "${DEVBASE_ROOT}/libs/install.sh")
  
  result=$(_get_font_display_name "unknown-font")
  [[ "$result" == "unknown-font" ]]
}

@test "validate_source_repository checks required directories" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  
  cd "${DEVBASE_ROOT}"
  
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
  source <(grep -A10 "^validate_source_repository()" "${DEVBASE_ROOT}/libs/install.sh")
  
  run validate_source_repository
  assert_success
}

@test "setup_installation_paths sets version file path" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export _DEVBASE_TEMP="/tmp/devbase.test123"
  
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
  source <(sed -n '/^setup_installation_paths()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")
  
  setup_installation_paths
  
  [[ -n "$_VERSIONS_FILE" ]]
  [[ "$_VERSIONS_FILE" =~ custom-tools.yaml$ ]]
}


