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
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
}

@test "_theme_key converts hyphens to underscores" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  result=$(_theme_key "everforest-dark")
  [[ "$result" == "everforest_dark" ]]
  
  result=$(_theme_key "catppuccin-mocha")
  [[ "$result" == "catppuccin_mocha" ]]
  
  result=$(_theme_key "tokyonight-night")
  [[ "$result" == "tokyonight_night" ]]
}

@test "_theme_key preserves underscores" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  result=$(_theme_key "already_underscore")
  [[ "$result" == "already_underscore" ]]
}

@test "THEME_CONFIGS contains all supported themes" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  [[ -n "${THEME_CONFIGS[everforest_dark]}" ]]
  [[ -n "${THEME_CONFIGS[everforest_light]}" ]]
  [[ -n "${THEME_CONFIGS[catppuccin_mocha]}" ]]
  [[ -n "${THEME_CONFIGS[catppuccin_latte]}" ]]
  [[ -n "${THEME_CONFIGS[tokyonight_night]}" ]]
  [[ -n "${THEME_CONFIGS[tokyonight_day]}" ]]
  [[ -n "${THEME_CONFIGS[gruvbox_dark]}" ]]
  [[ -n "${THEME_CONFIGS[gruvbox_light]}" ]]
  [[ -n "${THEME_CONFIGS[nord]}" ]]
  [[ -n "${THEME_CONFIGS[dracula]}" ]]
  [[ -n "${THEME_CONFIGS[solarized_dark]}" ]]
  [[ -n "${THEME_CONFIGS[solarized_light]}" ]]
}

@test "FZF_COLORS contains color schemes for all themes" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  [[ -n "${FZF_COLORS[everforest_dark]}" ]]
  [[ -n "${FZF_COLORS[catppuccin_mocha]}" ]]
  [[ -n "${FZF_COLORS[nord]}" ]]
  [[ -n "${FZF_COLORS[dracula]}" ]]
}

@test "_apply_theme_get_fzf_colors returns correct colors for theme" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  result=$(_apply_theme_get_fzf_colors "nord")
  [[ "$result" =~ "--color=dark" ]]
  [[ "$result" =~ "bg:#2e3440" ]]
}

@test "_apply_theme_get_fzf_colors falls back to everforest-dark for unknown theme" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  result=$(_apply_theme_get_fzf_colors "unknown-theme")
  [[ "$result" == "${FZF_COLORS[everforest_dark]}" ]]
}

@test "apply_theme sets DEVBASE_THEME variable" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  apply_theme "catppuccin-mocha"
  
  [[ "$DEVBASE_THEME" == "catppuccin-mocha" ]]
}

@test "apply_theme sets BAT_THEME from config" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  apply_theme "nord"
  
  [[ "$BAT_THEME" == "Nord" ]]
}

@test "apply_theme sets dark theme variables correctly" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  apply_theme "everforest-dark"
  
  [[ "$THEME_BACKGROUND" == "dark" ]]
  [[ "$DELTA_DARK" == "true" ]]
  [[ "$LAZYGIT_LIGHT_THEME" == "false" ]]
}

@test "apply_theme sets light theme variables correctly" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  apply_theme "everforest-light"
  
  [[ "$THEME_BACKGROUND" == "light" ]]
  [[ "$DELTA_DARK" == "false" ]]
  [[ "$LAZYGIT_LIGHT_THEME" == "true" ]]
}

@test "apply_theme defaults to everforest-dark when no theme specified" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  apply_theme ""
  
  [[ "$DEVBASE_THEME" == "everforest-dark" ]]
}

@test "apply_theme warns and defaults for unknown theme" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  run --separate-stderr apply_theme "unknown-theme"
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}' stderr: '${stderr}'"
  
  assert_output --partial "Unknown theme"
  assert_output --partial "Supported themes"
}

@test "apply_theme sets FZF_DEFAULT_OPTS" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  apply_theme "dracula"
  
  [[ -n "$FZF_DEFAULT_OPTS" ]]
  [[ "$FZF_DEFAULT_OPTS" =~ "--color=" ]]
}

@test "apply_theme sets DELTA_FEATURES" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  apply_theme "gruvbox-dark"
  
  [[ "$DELTA_FEATURES" == "decorations line-numbers" ]]
}

@test "apply_theme sets all tool-specific variables" {
  source "${DEVBASE_ROOT}/libs/configure-theme.sh"
  
  apply_theme "solarized-dark"
  
  [[ -n "$BAT_THEME" ]]
  [[ -n "$BTOP_THEME" ]]
  [[ -n "$DELTA_SYNTAX_THEME" ]]
  [[ -n "$ZELLIJ_THEME" ]]
  [[ -n "$VIFM_COLORSCHEME" ]]
  [[ -n "$K9S_SKIN" ]]
}
