#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

source "${DEVBASE_LIBS}/utils.sh"
source "${DEVBASE_LIBS}/defaults.sh"
source "${DEVBASE_LIBS}/theme-registry.sh"

# Brief: Convert theme name to internal key (hyphens to underscores)
_theme_key() {
  printf "%s" "${1//-/_}"
}

# Brief: Get FZF color scheme for theme
# Params: $1 - theme name (user-facing, with hyphens)
# Returns: FZF color string
_apply_theme_get_fzf_colors() {
  local key
  key=$(_theme_key "$1")
  printf "%s" "${FZF_COLORS[$key]:-${FZF_COLORS[everforest_dark]}}"
}

# Brief: Apply color theme to all tools (bat, btop, delta, fzf, etc.)
# Params: $1 - theme name (default: everforest-dark)
# Uses: THEME_CONFIGS, FZF_COLORS (globals)
# Modifies: DEVBASE_THEME, BAT_THEME, BTOP_THEME, DELTA_SYNTAX_THEME, ZELLIJ_THEME,
#           VIFM_COLORSCHEME, K9S_SKIN, DELTA_DARK, LAZYGIT_LIGHT_THEME,
#           DELTA_FEATURES, FZF_DEFAULT_OPTS (all exported)
# Returns: 0 always
# Side-effects: Exports theme variables for all tools
apply_theme() {
  local theme="${1:-$(get_default_theme)}"
  local key

  [[ -z "$theme" ]] && theme="$(get_default_theme)"
  key=$(_theme_key "$theme")

  # Check if theme exists in config, use default if not
  if [[ -z "${THEME_CONFIGS[$key]:-}" ]]; then
    show_progress warning "Unknown theme '$theme', using default (everforest-dark)"
    show_progress info "Supported themes: everforest-dark, everforest-light, catppuccin-mocha, catppuccin-latte"
    show_progress info "  tokyonight-night, tokyonight-day, gruvbox-dark, gruvbox-light, nord, dracula"
    show_progress info "  solarized-dark, solarized-light"
    theme="everforest-dark"
    key="everforest_dark"
  fi

  IFS='|' read -r is_light bat btop delta _zellij _nvim vifm k9s <<<"${THEME_CONFIGS[$key]}"

  export DEVBASE_THEME="$theme"
  export BAT_THEME="$bat"
  export BTOP_THEME="$btop"
  export DELTA_SYNTAX_THEME="$delta"
  export ZELLIJ_THEME="$_zellij"
  export VIFM_COLORSCHEME="$vifm"
  export K9S_SKIN="$k9s"

  if [[ "$is_light" == "light" ]]; then
    export THEME_BACKGROUND="light"
    export DELTA_DARK="false"
    export LAZYGIT_LIGHT_THEME="true"
  else
    export THEME_BACKGROUND="dark"
    export DELTA_DARK="true"
    export LAZYGIT_LIGHT_THEME="false"
  fi

  export DELTA_FEATURES="decorations line-numbers"
  export FZF_DEFAULT_OPTS="$(_apply_theme_get_fzf_colors "$theme")"
}
