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

@test "colorscheme.lua.template keeps its expected structure" {
  local template="${DEVBASE_ROOT}/dot/.config/nvim/lua/plugins/colorscheme.lua.template"
  
  assert_file_exists "$template"
  
  # Check file has more than just one line (corruption check)
  local line_count
  line_count=$(wc -l < "$template")
  [ "$line_count" -gt 5 ]
  
  # Anchored: assert_file_contains is a substring match, so "return {" also
  # matches a corrupted "return {{".
  run grep -cx 'return {' "$template"
  assert_output "1"
  assert_file_contains "$template" "colorscheme"
  assert_file_contains "$template" "sainnhe/everforest"
  assert_file_contains "$template" "LazyVim/LazyVim"
  assert_file_contains "$template" "colorscheme"
  
}

@test "colorscheme.lua.template parses as Lua" {
  # luacheck is not installed here or in CI. nvim ships LuaJIT and is present
  # on any devbase machine; loadfile parses without executing.
  local validator=""
  command -v luacheck &>/dev/null && validator=luacheck
  [[ -z "$validator" ]] && command -v nvim &>/dev/null && validator=nvim
  [[ -n "$validator" ]] || skip "no Lua validator available (install luacheck or nvim)"

  local template="${DEVBASE_ROOT}/dot/.config/nvim/lua/plugins/colorscheme.lua.template"
  local rendered="${BATS_TEST_TMPDIR}/colorscheme.lua"
  sed 's/\${THEME_BACKGROUND}/dark/' "$template" >"$rendered"

  if [[ "$validator" == luacheck ]]; then
    run luacheck --no-config --codes "$rendered"
  else
    run nvim --headless --clean -c "lua if not loadfile('${rendered}') then vim.cmd('cq') end" -c q
  fi
  assert_success
}
