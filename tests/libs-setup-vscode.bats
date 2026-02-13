#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155,SC2218,SC2329
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'libs/bats-mock/stub'
load 'test_helper'

setup() {
  common_setup_isolated
  export DEVBASE_DOT="${TEST_DIR}/dot"

  # Create mock filesystem root for path tests
  export MOCK_ROOT="${TEST_DIR}/mock_root"
  mkdir -p "${MOCK_ROOT}/usr/bin"
  mkdir -p "${MOCK_ROOT}/usr/local/bin"

  source_core_libs_with_requirements
}

teardown() {
  if declare -f unstub >/dev/null 2>&1; then
    unstub code || true
    unstub command || true
  fi
  
  common_teardown
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
  # Create mock /usr/bin/code in our mock root
  echo '#!/bin/bash' > "${MOCK_ROOT}/usr/bin/code"
  chmod +x "${MOCK_ROOT}/usr/bin/code"
  
  # Override the function to use mock root
  _find_native_vscode() {
    if [[ -x "${MOCK_ROOT}/usr/bin/code" ]]; then
      echo "${MOCK_ROOT}/usr/bin/code"
      return 0
    elif [[ -x "${MOCK_ROOT}/usr/local/bin/code" ]]; then
      echo "${MOCK_ROOT}/usr/local/bin/code"
      return 0
    fi
    return 1
  }
  
  run _find_native_vscode
  
  assert_success
  assert_output "${MOCK_ROOT}/usr/bin/code"
}

@test "_find_native_vscode detects /usr/local/bin/code" {
  # Create mock /usr/local/bin/code in our mock root
  echo '#!/bin/bash' > "${MOCK_ROOT}/usr/local/bin/code"
  chmod +x "${MOCK_ROOT}/usr/local/bin/code"
  
  # Override the function to use mock root
  _find_native_vscode() {
    if [[ -x "${MOCK_ROOT}/usr/bin/code" ]]; then
      echo "${MOCK_ROOT}/usr/bin/code"
      return 0
    elif [[ -x "${MOCK_ROOT}/usr/local/bin/code" ]]; then
      echo "${MOCK_ROOT}/usr/local/bin/code"
      return 0
    fi
    return 1
  }
  
  run _find_native_vscode
  
  assert_success
  assert_output "${MOCK_ROOT}/usr/local/bin/code"
}

@test "_find_native_vscode returns failure when code not found" {
  # Override the function to use mock root (no code installed)
  _find_native_vscode() {
    if [[ -x "${MOCK_ROOT}/usr/bin/code" ]]; then
      echo "${MOCK_ROOT}/usr/bin/code"
      return 0
    elif [[ -x "${MOCK_ROOT}/usr/local/bin/code" ]]; then
      echo "${MOCK_ROOT}/usr/local/bin/code"
      return 0
    fi
    return 1
  }
  
  run _find_native_vscode
  
  assert_failure
}

@test "_detect_wsl_distro returns WSL_DISTRO_NAME when set" {
  run run_as_wsl "
    source '${DEVBASE_ROOT}/libs/setup-vscode.sh'
    _detect_wsl_distro
  " "Ubuntu-22.04"
  
  [[ "$output" == "Ubuntu-22.04" ]]
}

@test "_detect_wsl_distro falls back to os-release" {
  # This test can only verify the fallback behavior in a WSL environment
  # or where /etc/os-release contains "Ubuntu". Skip on non-Ubuntu systems.
  if ! grep -q 'Ubuntu' /etc/os-release 2>/dev/null; then
    skip "Test requires Ubuntu os-release (testing WSL fallback behavior)"
  fi

  run run_isolated "
    source '${DEVBASE_ROOT}/libs/setup-vscode.sh'
    result=\$(_detect_wsl_distro)
    echo \"\$result\"
  "

  [[ "$output" =~ Ubuntu ]]
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
  
  settings_file="${TEST_DIR}/settings.json"
  echo '{"test": true}' > "$settings_file"
  
  _backup_vscode_settings "$settings_file"
  
  run ls "${settings_file}.bak."*
  assert_success
}

@test "_backup_vscode_settings returns failure when file doesn't exist" {
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"

  run _backup_vscode_settings "${TEST_DIR}/nonexistent.json"
  assert_failure
}

@test "configure_vscode_settings merges theme without clobbering existing keys" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq required to test merge behavior"
  fi

  local settings_dir="${HOME}/.vscode-server/data/Machine"
  mkdir -p "$settings_dir"
  printf '{"editor.fontSize": 14, "workbench.colorTheme": "Old Theme"}\n' > "${settings_dir}/settings.json"

  export DEVBASE_THEME="catppuccin-mocha"
  source "${DEVBASE_ROOT}/libs/setup-vscode.sh"

  run bash -c "
    export HOME='${HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_THEME='catppuccin-mocha'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/setup-vscode.sh' >/dev/null 2>&1

    configure_vscode_settings >/dev/null 2>&1
    cat '${settings_dir}/settings.json'
  "

  assert_success
  # Theme should be updated
  assert_output --partial '"workbench.colorTheme": "Catppuccin Mocha"'
  # Existing user key should be preserved
  assert_output --partial '"editor.fontSize": 14'
}

@test "configure_vscode_settings creates new settings file with theme" {
  local settings_dir="${HOME}/.vscode-server/data/Machine"
  mkdir -p "$settings_dir"

  run bash -c "
    export HOME='${HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_THEME='nord'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/setup-vscode.sh' >/dev/null 2>&1

    configure_vscode_settings >/dev/null 2>&1
    cat '${settings_dir}/settings.json'
  "

  assert_success
  assert_output --partial '"workbench.colorTheme": "Nord"'
}

@test "configure_vscode_settings does not inject neovim settings" {
  local settings_dir="${HOME}/.vscode-server/data/Machine"
  mkdir -p "$settings_dir"

  run bash -c "
    export HOME='${HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_THEME='everforest-dark'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/setup-vscode.sh' >/dev/null 2>&1

    configure_vscode_settings >/dev/null 2>&1
    cat '${settings_dir}/settings.json'
  "

  assert_success
  assert_output --partial '"workbench.colorTheme": "Everforest Dark"'
  refute_output --partial "vscode-neovim"
  refute_output --partial "neovimExecutablePaths"
}
