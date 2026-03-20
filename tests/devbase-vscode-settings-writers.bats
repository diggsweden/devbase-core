#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.5.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup_isolated
  export DEVBASE_THEME_FISH="${DEVBASE_ROOT}/dot/.config/fish/functions/devbase-theme.fish"
  export DEVBASE_FONT_FISH="${DEVBASE_ROOT}/dot/.config/fish/functions/devbase-font.fish"
  mkdir -p "${HOME}/.vscode-server/data/Machine"
}

teardown() {
  common_teardown
}

@test "__devbase_theme_update_vscode preserves unrelated keys" {
  if ! command -v jq &>/dev/null; then
    skip "jq is required for this test"
  fi

  local settings_file="${HOME}/.vscode-server/data/Machine/settings.json"
  printf '{"editor.fontSize":16,"workbench.colorTheme":"Old Theme"}\n' > "$settings_file"

  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" fish -c "source '$DEVBASE_THEME_FISH'; __devbase_theme_update_vscode nord; cat '$settings_file'"

  assert_success
  assert_output --partial '"workbench.colorTheme": "Nord"'
  assert_output --partial '"editor.fontSize": 16'
}

@test "__devbase_theme_update_vscode creates new settings file" {
  if ! command -v jq &>/dev/null; then
    skip "jq is required for this test"
  fi

  local settings_file="${HOME}/.vscode-server/data/Machine/settings.json"
  rm -f "$settings_file"

  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" fish -c "source '$DEVBASE_THEME_FISH'; __devbase_theme_update_vscode nord; cat '$settings_file'"

  assert_success
  assert_output --partial '"workbench.colorTheme": "Nord"'
}

@test "__devbase_theme_update_vscode leaves non-object settings unchanged" {
  if ! command -v jq &>/dev/null; then
    skip "jq is required for this test"
  fi

  local settings_file="${HOME}/.vscode-server/data/Machine/settings.json"
  printf '[]\n' > "$settings_file"

  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" fish -c "source '$DEVBASE_THEME_FISH'; __devbase_theme_update_vscode nord; echo status:\$status; cat '$settings_file'"

  assert_success
  assert_output --partial 'status:2'
  assert_output --partial '[]'
}

@test "__devbase_font_update_vscode preserves unrelated keys" {
  if ! command -v jq &>/dev/null; then
    skip "jq is required for this test"
  fi

  local settings_file="${HOME}/.vscode-server/data/Machine/settings.json"
  printf '{"editor.fontSize":16,"editor.fontFamily":"Old Font"}\n' > "$settings_file"

  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" fish -c "source '$DEVBASE_FONT_FISH'; __devbase_font_update_vscode 'Fira Code Nerd Font'; cat '$settings_file'"

  assert_success
  assert_output --partial '"editor.fontFamily": "Fira Code Nerd Font"'
  assert_output --partial '"editor.fontSize": 16'
}

@test "__devbase_font_update_vscode leaves non-object settings unchanged" {
  if ! command -v jq &>/dev/null; then
    skip "jq is required for this test"
  fi

  local settings_file="${HOME}/.vscode-server/data/Machine/settings.json"
  printf '[]\n' > "$settings_file"

  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" fish -c "source '$DEVBASE_FONT_FISH'; __devbase_font_update_vscode 'Fira Code Nerd Font'; echo status:\$status; cat '$settings_file'"

  assert_success
  assert_output --partial 'status:2'
  assert_output --partial '[]'
}

@test "__devbase_font_update_vscode creates new settings file" {
  if ! command -v jq &>/dev/null; then
    skip "jq is required for this test"
  fi

  local settings_file="${HOME}/.vscode-server/data/Machine/settings.json"
  rm -f "$settings_file"

  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" fish -c "source '$DEVBASE_FONT_FISH'; __devbase_font_update_vscode 'Fira Code Nerd Font'; cat '$settings_file'"

  assert_success
  assert_output --partial '"editor.fontFamily": "Fira Code Nerd Font"'
}

@test "__devbase_theme_update_vscode warns when settings path is missing" {
  if ! command -v jq &>/dev/null; then
    skip "jq is required for this test"
  fi

  rm -rf "${HOME}/.vscode-server"
  rm -rf "${XDG_CONFIG_HOME}/Code"

  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" fish -c "source '$DEVBASE_THEME_FISH'; __devbase_theme_update_vscode nord"

  assert_failure
  assert_output --partial 'settings path not found'
}

@test "__devbase_font_update_vscode warns when settings path is missing" {
  if ! command -v jq &>/dev/null; then
    skip "jq is required for this test"
  fi

  rm -rf "${HOME}/.vscode-server"
  rm -rf "${XDG_CONFIG_HOME}/Code"

  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" fish -c "source '$DEVBASE_FONT_FISH'; __devbase_font_update_vscode 'Fira Code Nerd Font'"

  assert_failure
  assert_output --partial 'settings path not found'
}

@test "__devbase_font_update_vscode leaves invalid settings unchanged" {
  if ! command -v jq &>/dev/null; then
    skip "jq is required for this test"
  fi

  local settings_file="${HOME}/.vscode-server/data/Machine/settings.json"
  printf '{invalid json\n' > "$settings_file"

  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" fish -c "source '$DEVBASE_FONT_FISH'; __devbase_font_update_vscode 'Fira Code Nerd Font'; echo status:\$status; cat '$settings_file'"

  assert_success
  assert_output --partial 'status:2'
  assert_output --partial '{invalid json'
}
