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

_render_colorscheme() {
  # devbase-theme is the single generator for lua/plugins/colorscheme.lua;
  # setup renders it the same way for a fresh LazyVim install.
  fish --no-config -c 'source $argv[1]; and __devbase_theme_nvim_colorscheme_lua $argv[2]' \
    "${DEVBASE_ROOT}/dot/.config/fish/functions/devbase-theme.fish" "$1"
}

@test "devbase-theme renders a LazyVim colorscheme spec for every theme" {
  local theme expected_background
  for theme in everforest-dark everforest-light catppuccin-mocha catppuccin-latte \
    tokyonight-night tokyonight-day gruvbox-dark gruvbox-light nord dracula \
    solarized-dark solarized-light; do
    run _render_colorscheme "$theme"
    assert_success
    # One top-level table with the plugin spec and LazyVim's own colorscheme option
    assert_line --index 2 'return {'
    assert_equal "$(grep -cx 'return {' <<<"$output")" 1
    assert_output --partial '    priority = 1000,'
    assert_output --partial '    "LazyVim/LazyVim",'
    assert_output --regexp 'colorscheme = "[a-z]+",'
    expected_background=dark
    [[ "$theme" == *-light || "$theme" == *-latte || "$theme" == *-day ]] && expected_background=light
    assert_output --partial "vim.opt.background = '${expected_background}'"
  done
}

@test "devbase-theme selects the matching Neovim plugin per theme family" {
  run _render_colorscheme catppuccin-mocha
  assert_output --partial '"catppuccin/nvim",'
  assert_output --partial 'name = "catppuccin",'
  assert_output --partial 'flavour = "mocha"'
  run _render_colorscheme tokyonight-day
  assert_output --partial '"folke/tokyonight.nvim",'
  assert_output --partial 'style = "day"'
  run _render_colorscheme everforest-dark
  assert_output --partial '"sainnhe/everforest",'
  assert_output --partial 'colorscheme = "everforest",'
}

@test "devbase-theme rejects an unknown theme for the colorscheme spec" {
  run _render_colorscheme no-such-theme
  assert_failure
}

@test "rendered colorscheme spec parses as Lua" {
  # luacheck is not installed here or in CI. nvim ships LuaJIT and is present
  # on any devbase machine; loadfile parses without executing.
  local validator=""
  command -v luacheck &>/dev/null && validator=luacheck
  [[ -z "$validator" ]] && command -v nvim &>/dev/null && validator=nvim
  [[ -n "$validator" ]] || skip "no Lua validator available (install luacheck or nvim)"

  local theme rendered
  for theme in everforest-dark catppuccin-latte tokyonight-night gruvbox-light nord solarized-dark; do
    rendered="${BATS_TEST_TMPDIR}/${theme}.lua"
    _render_colorscheme "$theme" >"$rendered"
    if [[ "$validator" == luacheck ]]; then
      run luacheck --no-config --codes "$rendered"
    else
      run nvim --headless --clean -c "lua if not loadfile('${rendered}') then vim.cmd('cq') end" -c q
    fi
    assert_success
  done
}

@test "git and vifm templates take the editor from the setup choice" {
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/utils.sh"
  # The renderer validates every template variable; only the editor matters here.
  local var
  for var in "${DEVBASE_REQUIRED_TEMPLATE_VARS[@]}"; do
    export "$var=placeholder"
  done
  export EDITOR=nano VISUAL=nano
  local rendered="${BATS_TEST_TMPDIR}/rendered"
  mkdir -p "$rendered"

  envsubst_preserve_undefined "${DEVBASE_ROOT}/dot/.config/git/config.template" "${rendered}/gitconfig"
  run grep -E '^\s*editor = ' "${rendered}/gitconfig"
  assert_output --regexp 'editor = nano$'

  envsubst_preserve_undefined "${DEVBASE_ROOT}/dot/.config/vifm/vifmrc.template" "${rendered}/vifmrc"
  run grep -x 'set vicmd=nano' "${rendered}/vifmrc"
  assert_success
}

@test "IntelliJ vmoptions template keeps the launcher's USER_HOME token" {
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/utils.sh"
  local var
  for var in "${DEVBASE_REQUIRED_TEMPLATE_VARS[@]}"; do
    export "$var=placeholder"
  done
  local rendered="${BATS_TEST_TMPDIR}/idea64.vmoptions"

  run envsubst_preserve_undefined "${DEVBASE_ROOT}/dot/.config/devbase/intellij-vmoptions.template" "$rendered"
  assert_success
  refute_output --partial "Unknown variable"
  run grep -x -- '-XX:HeapDumpPath=$USER_HOME/java_error_in_idea.hprof' "$rendered"
  assert_success
}
