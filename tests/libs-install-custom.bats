#!/usr/bin/env bats

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
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  
  TEMP_DIR=$(temp_make)
  export TEMP_DIR
  export HOME="${TEMP_DIR}/home"
  mkdir -p "$HOME"
  
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/utils.sh"
}

teardown() {
  temp_del "$TEMP_DIR"
  
  if declare -f unstub >/dev/null 2>&1; then
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/curl" ]] && unstub curl || true
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/jq" ]] && unstub jq || true
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/git" ]] && unstub git || true
  fi
}

@test "get_vscode_checksum fetches checksum from API" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  stub jq 'echo "abc123"'
  stub curl 'echo "[]"'
  
  run --separate-stderr get_vscode_checksum "1.85.1"
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}' stderr: '${stderr}'"
  assert_success
  
  unstub jq
  unstub curl
}

@test "get_vscode_checksum fails when jq not available" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  PATH=""
  
  run get_vscode_checksum "1.85.1"
  assert_failure
}

@test "get_vscode_checksum validates version parameter" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  run get_vscode_checksum ""
  assert_failure
}

@test "get_oc_checksum fetches checksum from mirror" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  stub curl 'echo "abc123def456  openshift-client-linux-4.15.33.tar.gz"'
  
  result=$(get_oc_checksum "4.15.33")
  [[ "$result" == "abc123def456" ]]
  
  unstub curl
}

@test "get_oc_checksum validates version parameter" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  run get_oc_checksum ""
  assert_failure
}

@test "install_lazyvim skips when user preference is false" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  export DEVBASE_INSTALL_LAZYVIM="false"
  export XDG_CONFIG_HOME="${TEMP_DIR}/config"
  export DEVBASE_THEME="everforest-dark"
  export DEVBASE_DOT="${BATS_TEST_DIRNAME}/../dot"
  
  run install_lazyvim
  assert_success
  assert_output --partial "skipped by user preference"
}

@test "install_lazyvim backs up existing nvim config" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  export DEVBASE_INSTALL_LAZYVIM="true"
  export XDG_CONFIG_HOME="${TEMP_DIR}/config"
  export DEVBASE_THEME="everforest-dark"
  export DEVBASE_DOT="${BATS_TEST_DIRNAME}/../dot"
  declare -gA TOOL_VERSIONS=([lazyvim_starter]="main")
  
  mkdir -p "${XDG_CONFIG_HOME}/nvim"
  echo "existing config" > "${XDG_CONFIG_HOME}/nvim/init.lua"
  
  stub git \
    'clone * : mkdir -p "${XDG_CONFIG_HOME}/nvim/lua/plugins"'
  
  install_lazyvim
  
  run ls "${XDG_CONFIG_HOME}"/nvim.bak.*
  assert_success
  
  unstub git
}

@test "install_lazyvim configures light theme background" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  export DEVBASE_INSTALL_LAZYVIM="true"
  export XDG_CONFIG_HOME="${TEMP_DIR}/config"
  export DEVBASE_THEME="everforest-light"
  export DEVBASE_DOT="${BATS_TEST_DIRNAME}/../dot"
  declare -gA TOOL_VERSIONS=([lazyvim_starter]="main")
  
  stub git \
    'clone --quiet * : mkdir -p "$4/lua/plugins"'
  
  mkdir -p "${DEVBASE_DOT}/.config/nvim/lua/plugins"
  echo 'background=${THEME_BACKGROUND}' > "${DEVBASE_DOT}/.config/nvim/lua/plugins/colorscheme.lua.template"
  
  install_lazyvim
  
  [[ -f "${XDG_CONFIG_HOME}/nvim/lua/plugins/colorscheme.lua" ]]
  grep -q "background=light" "${XDG_CONFIG_HOME}/nvim/lua/plugins/colorscheme.lua"
  
  unstub git
}

@test "_determine_font_details returns correct font info" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  result=$(_determine_font_details "monaspace")
  [[ "$result" =~ MonaspaceNerdFont ]]
  
  result=$(_determine_font_details "firacode")
  [[ "$result" =~ FiraCode ]]
}

@test "_is_wayland_session detects Wayland" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  export WAYLAND_DISPLAY="wayland-0"
  
  run _is_wayland_session
  assert_success
  
  unset WAYLAND_DISPLAY
  export XDG_SESSION_TYPE="wayland"
  
  run _is_wayland_session
  assert_success
}

@test "_is_wayland_session detects X11" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  unset WAYLAND_DISPLAY
  export XDG_SESSION_TYPE="x11"
  
  run _is_wayland_session
  assert_failure
}
