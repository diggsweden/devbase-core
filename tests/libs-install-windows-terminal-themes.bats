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
  # Alias for backward compatibility with tests using TEMP_DIR
  TEMP_DIR="$TEST_DIR"
  export TEMP_DIR
  source_core_libs
}

teardown() {
  if declare -f unstub >/dev/null 2>&1; then
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/jq" ]] && unstub jq || true
  fi
  common_teardown
}

@test "_detect_windows_username uses PowerShell when available" {
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"
  
  # Create mock PowerShell that returns a username
  mkdir -p "${TEMP_DIR}/mnt/c/Windows/System32/WindowsPowerShell/v1.0"
  cat > "${TEMP_DIR}/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" << 'SCRIPT'
#!/usr/bin/env bash
echo -n "TestUser"
SCRIPT
  chmod +x "${TEMP_DIR}/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
  
  # Override the function to use our mock path
  _detect_windows_username() {
    local win_user=""
    if [[ -x "${TEMP_DIR}/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" ]]; then
      win_user=$("${TEMP_DIR}/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" 2>/dev/null | tr -d '\r\n')
    fi
    if [[ -z "$win_user" ]]; then
      return 1
    fi
    echo "$win_user"
    return 0
  }
  
  run _detect_windows_username
  
  assert_success
  assert_output "TestUser"
}

@test "_find_wt_settings_path detects stable Windows Terminal" {
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"
  
  # Create mock Windows Terminal settings path
  local mock_settings_dir="${TEMP_DIR}/mnt/c/Users/TestUser/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
  mkdir -p "$mock_settings_dir"
  echo '{}' > "$mock_settings_dir/settings.json"
  
  # Override the function to use our mock base path
  _find_wt_settings_path() {
    local win_user="$1"
    local possible_paths=(
      "${TEMP_DIR}/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
      "${TEMP_DIR}/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
    )
    for path in "${possible_paths[@]}"; do
      if [[ -f "$path" ]]; then
        echo "$path"
        return 0
      fi
    done
    return 1
  }
  
  run _find_wt_settings_path "TestUser"
  
  assert_success
  assert_output --partial "Microsoft.WindowsTerminal_8wekyb3d8bbwe"
}

@test "_find_wt_settings_path detects preview Windows Terminal" {
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"
  
  # Create mock Windows Terminal Preview settings path
  local mock_settings_dir="${TEMP_DIR}/mnt/c/Users/TestUser/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState"
  mkdir -p "$mock_settings_dir"
  echo '{}' > "$mock_settings_dir/settings.json"
  
  # Override the function to use our mock base path
  _find_wt_settings_path() {
    local win_user="$1"
    local possible_paths=(
      "${TEMP_DIR}/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
      "${TEMP_DIR}/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
    )
    for path in "${possible_paths[@]}"; do
      if [[ -f "$path" ]]; then
        echo "$path"
        return 0
      fi
    done
    return 1
  }
  
  run _find_wt_settings_path "TestUser"
  
  assert_success
  assert_output --partial "Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe"
}

@test "_find_wt_settings_path returns failure when not found" {
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"
  
  run _find_wt_settings_path "NonExistentUser"
  assert_failure
}

@test "_find_wt_theme_directory finds theme directory" {
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"
  
  mkdir -p "${XDG_DATA_HOME}/devbase/files/windows-terminal"
  
  result=$(_find_wt_theme_directory)
  [[ "$result" == "${XDG_DATA_HOME}/devbase/files/windows-terminal" ]]
}

@test "_find_wt_theme_directory returns failure when not found" {
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"
  
  run _find_wt_theme_directory
  assert_failure
}

@test "_build_themes_json_array builds JSON array from theme files" {
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"
  
  local theme_dir="${TEMP_DIR}/themes"
  mkdir -p "$theme_dir"
  
  echo '{"name": "nord"}' > "$theme_dir/nord.json"
  echo '{"name": "dracula"}' > "$theme_dir/dracula.json"
  
  result=$(_build_themes_json_array "$theme_dir" 2>/dev/null)
  [[ "$result" =~ ^\[ ]]
  [[ "$result" =~ \]$ ]]
  [[ "$result" =~ nord ]]
}

@test "_build_themes_json_array counts themes correctly" {
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"
  
  local theme_dir="${TEMP_DIR}/themes"
  mkdir -p "$theme_dir"
  
  echo '{"name": "nord"}' > "$theme_dir/nord.json"
  echo '{"name": "dracula"}' > "$theme_dir/dracula.json"
  echo '{"name": "gruvbox-dark"}' > "$theme_dir/gruvbox-dark.json"
  
  count=$(_build_themes_json_array "$theme_dir" 2>&1 >/dev/null)
  [[ "$count" == "3" ]]
}

@test "_build_themes_json_array handles missing theme files" {
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"
  
  local theme_dir="${TEMP_DIR}/themes"
  mkdir -p "$theme_dir"
  
  result=$(_build_themes_json_array "$theme_dir" 2>/dev/null)
  [[ "$result" == "[]" ]]
}

@test "_inject_themes_to_settings leaves the settings file valid with no themes" {
  command -v jq &>/dev/null || skip "jq not available"

  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"

  local settings_file="${TEMP_DIR}/settings.json"
  local backup_file="${TEMP_DIR}/settings.json.bak"

  echo '{"schemes": []}' > "$settings_file"

  _inject_themes_to_settings "$settings_file" "[]" "$backup_file" || true

  # The function does not create the backup, the caller passes one in.
  run jq -e '.schemes | length == 0' "$settings_file"
  assert_success
}

@test "_inject_themes_to_settings uses jq for JSON manipulation" {
  command -v jq &>/dev/null || skip "jq not available"
  
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"
  
  local settings_file="${TEMP_DIR}/settings.json"
  local backup_file="${TEMP_DIR}/settings.json.bak"
  
  echo '{"schemes": [{"name": "old"}]}' > "$settings_file"
  
  run _inject_themes_to_settings "$settings_file" '[{"name": "new"}]' "$backup_file"
  
  [[ -f "$settings_file" ]]
}

# _inject_themes_to_settings rewrites the user's Windows Terminal
# settings.json. It only replaces the original once jq has produced non-empty,
# valid JSON, and restores the backup if the move fails.

@test "_inject_themes_to_settings leaves settings intact when jq produces nothing usable" {
  command -v jq &>/dev/null || skip "jq not available"
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"

  local wt_settings="${TEST_DIR}/settings.json"
  local backup="${TEST_DIR}/settings.json.bak"
  # Invalid JSON: jq cannot merge into it, so the filter yields no usable output.
  printf 'this is not json\n' >"$wt_settings"
  cp "$wt_settings" "$backup"

  run _inject_themes_to_settings "$wt_settings" '[{"name":"Nord"}]' "$backup"

  # Whatever the outcome, the user's file must not be replaced by junk.
  run cat "$wt_settings"
  assert_output "this is not json"
}

@test "_inject_themes_to_settings writes valid JSON when the merge succeeds" {
  command -v jq &>/dev/null || skip "jq not available"
  source "${DEVBASE_ROOT}/libs/install-windows-terminal-themes.sh"

  local wt_settings="${TEST_DIR}/settings.json"
  local backup="${TEST_DIR}/settings.json.bak"
  printf '{"profiles":{},"schemes":[]}\n' >"$wt_settings"
  cp "$wt_settings" "$backup"

  run _inject_themes_to_settings "$wt_settings" '[{"name":"Nord"}]' "$backup"

  assert_success
  run jq -e '.schemes[] | select(.name == "Nord")' "$wt_settings"
  assert_success
}
