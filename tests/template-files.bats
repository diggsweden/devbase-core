#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Tests to validate template files are not corrupted

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
}

@test "colorscheme.lua.template is valid Lua syntax" {
  local template="${DEVBASE_ROOT}/dot/.config/nvim/lua/plugins/colorscheme.lua.template"
  
  assert_file_exists "$template"
  
  # Check file has more than just one line (corruption check)
  local line_count
  line_count=$(wc -l < "$template")
  [ "$line_count" -gt 5 ]
  
  # Check it contains expected Lua structure
  assert_file_contains "$template" "return {"
  assert_file_contains "$template" "sainnhe/everforest"
  assert_file_contains "$template" "LazyVim/LazyVim"
  assert_file_contains "$template" "colorscheme"
  
  # If luacheck is available, validate syntax
  if command -v luacheck &>/dev/null; then
    # Replace template variable for syntax check
    local temp_file="${BATS_TEST_TMPDIR}/colorscheme.lua"
    sed 's/\${THEME_BACKGROUND}/dark/' "$template" > "$temp_file"
    run luacheck --no-config --codes "$temp_file"
    assert_success
  fi
}

@test "colorscheme.lua.template has SPDX license header" {
  local template="${DEVBASE_ROOT}/dot/.config/nvim/lua/plugins/colorscheme.lua.template"
  
  assert_file_contains "$template" "SPDX-FileCopyrightText"
  assert_file_contains "$template" "SPDX-License-Identifier"
}
