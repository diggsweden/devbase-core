#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup_isolated
  export THEME_FISH="${DEVBASE_ROOT}/dot/.config/fish/functions/devbase-theme.fish"
}

teardown() {
  common_teardown
}

_update_nvim() {
  XDG_CONFIG_HOME="$XDG_CONFIG_HOME" fish --no-config -c \
    'source $argv[1]; and __devbase_theme_update_nvim $argv[2]' "$THEME_FISH" "$1"
}

@test "devbase-theme rewrites the LazyVim colorscheme spec in place" {
  mkdir -p "${XDG_CONFIG_HOME}/nvim/lua/plugins"
  printf '%s\n' 'return {}' >"${XDG_CONFIG_HOME}/nvim/lua/plugins/colorscheme.lua"

  run _update_nvim tokyonight-night
  assert_success
  assert_file_contains "${XDG_CONFIG_HOME}/nvim/lua/plugins/colorscheme.lua" '"folke/tokyonight.nvim",'
  assert_file_contains "${XDG_CONFIG_HOME}/nvim/lua/plugins/colorscheme.lua" 'colorscheme = "tokyonight",'
  assert_file_contains "${XDG_CONFIG_HOME}/nvim/lua/plugins/colorscheme.lua" "vim.opt.background = 'dark'"
}

@test "devbase-theme leaves a Neovim configuration without a LazyVim plugin directory alone" {
  mkdir -p "${XDG_CONFIG_HOME}/nvim"
  printf '%s\n' 'vim.o.background = "light"' >"${XDG_CONFIG_HOME}/nvim/init.lua"

  run _update_nvim everforest-dark
  assert_success
  assert_not_exists "${XDG_CONFIG_HOME}/nvim/lua"
  run cat "${XDG_CONFIG_HOME}/nvim/init.lua"
  assert_output 'vim.o.background = "light"'
}

@test "devbase-theme does not create a Neovim configuration" {
  run _update_nvim everforest-dark
  assert_success
  assert_not_exists "${XDG_CONFIG_HOME}/nvim"
}
