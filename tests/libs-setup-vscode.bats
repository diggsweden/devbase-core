#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'libs/bats-mock/stub'

setup() {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_DOT="${BATS_TEST_DIRNAME}/../dot"
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  
  TEMP_DIR=$(temp_make)
  export TEMP_DIR
  export HOME="${TEMP_DIR}/home"
  mkdir -p "$HOME"
  
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/check-requirements.sh"
}

teardown() {
  temp_del "$TEMP_DIR"
  
  if declare -f unstub >/dev/null 2>&1; then
    unstub code || true
    unstub command || true
  fi
}

@test "_get_vscode_theme_name maps theme keys to display names" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  result=$(_get_vscode_theme_name "everforest-dark")
  [[ "$result" == "Everforest Dark" ]]
  
  result=$(_get_vscode_theme_name "catppuccin-mocha")
  [[ "$result" == "Catppuccin Mocha" ]]
  
  result=$(_get_vscode_theme_name "tokyonight-night")
  [[ "$result" == "Tokyo Night" ]]
}

@test "_get_vscode_theme_name returns default for unknown theme" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  result=$(_get_vscode_theme_name "unknown-theme")
  [[ "$result" == "Everforest Dark" ]]
}

@test "get_extension_description returns correct descriptions" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  result=$(get_extension_description "esbenp.prettier-vscode")
  [[ "$result" == "Prettier code formatter" ]]
  
  result=$(get_extension_description "dbaeumer.vscode-eslint")
  [[ "$result" == "ESLint JavaScript/TypeScript linter" ]]
  
  result=$(get_extension_description "redhat.java")
  [[ "$result" == "Java language support" ]]
}

@test "get_extension_description returns empty for unknown extension" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  result=$(get_extension_description "unknown.extension")
  [[ -z "$result" ]]
}

@test "_install_vscode_ext_parse_id skips comments and empty lines" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  run _install_vscode_ext_parse_id "# this is a comment"
  assert_failure
  
  run _install_vscode_ext_parse_id ""
  assert_failure
  
  run _install_vscode_ext_parse_id "  "
  assert_failure
}

@test "_install_vscode_ext_parse_id trims whitespace" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  result=$(_install_vscode_ext_parse_id "  esbenp.prettier-vscode  ")
  [[ "$result" == "esbenp.prettier-vscode" ]]
}

@test "_install_vscode_ext_display_name builds name with description" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  result=$(_install_vscode_ext_display_name "esbenp.prettier-vscode")
  [[ "$result" == "Prettier code formatter (esbenp.prettier-vscode)" ]]
}

@test "_install_vscode_ext_display_name returns ID when no description" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  result=$(_install_vscode_ext_display_name "unknown.extension")
  [[ "$result" == "unknown.extension" ]]
}

@test "_find_native_vscode detects /usr/bin/code" {
  skip "Cannot mock hardcoded /usr/bin/code path check"
}

@test "_detect_wsl_distro returns WSL_DISTRO_NAME when set" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  export WSL_DISTRO_NAME="Ubuntu-22.04"
  
  result=$(_detect_wsl_distro)
  [[ "$result" == "Ubuntu-22.04" ]]
}

@test "_detect_wsl_distro falls back to os-release" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  unset WSL_DISTRO_NAME
  
  echo 'NAME="Ubuntu"' > "${TEMP_DIR}/os-release"
  
  result=$(_detect_wsl_distro)
  [[ "$result" =~ Ubuntu ]]
}

@test "_get_vscode_settings_dir detects vscode-server" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  mkdir -p "$HOME/.vscode-server/data/Machine"
  
  result=$(_get_vscode_settings_dir)
  [[ "$result" == "$HOME/.vscode-server/data/Machine" ]]
}

@test "_get_vscode_settings_dir detects native Code directory" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  mkdir -p "$HOME/.config/Code/User"
  
  result=$(_get_vscode_settings_dir)
  [[ "$result" == "$HOME/.config/Code/User" ]]
}

@test "_get_vscode_settings_dir creates directory if vscode-server exists" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  mkdir -p "$HOME/.vscode-server"
  
  result=$(_get_vscode_settings_dir)
  [[ "$result" == "$HOME/.vscode-server/data/Machine" ]]
  [[ -d "$HOME/.vscode-server/data/Machine" ]]
}

@test "_backup_vscode_settings creates timestamped backup" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  settings_file="${TEMP_DIR}/settings.json"
  echo '{"test": true}' > "$settings_file"
  
  _backup_vscode_settings "$settings_file"
  
  run ls "${settings_file}.bak."*
  assert_success
}

@test "_backup_vscode_settings returns failure when file doesn't exist" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"
  
  run _backup_vscode_settings "${TEMP_DIR}/nonexistent.json"
  assert_failure
}
