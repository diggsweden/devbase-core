#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

source "${DEVBASE_LIBS}/utils.sh"

# Theme presets: is_light|bat|btop|delta|zellij|nvim|vifm|k9s
# Keys use underscores internally; user-facing names use hyphens (converted at lookup)
declare -gA THEME_CONFIGS

# Everforest themes
THEME_CONFIGS[everforest_dark]="dark|Monokai Extended|everforest-dark-hard|Monokai Extended|everforest-dark|everforest|everforest-dark|everforest-dark"
THEME_CONFIGS[everforest_light]="light|GitHub|everforest-light-medium|GitHub|everforest-light|everforest|everforest-light|everforest-light"

# Catppuccin themes
THEME_CONFIGS[catppuccin_mocha]="dark|Dracula|catppuccin_mocha|Dracula|catppuccin-mocha|catppuccin-mocha|solarized-dark|catppuccin-mocha"
THEME_CONFIGS[catppuccin_latte]="light|OneHalfLight|catppuccin_latte|OneHalfLight|catppuccin-latte|catppuccin-latte|solarized-light|catppuccin-latte"

# Tokyo Night themes
THEME_CONFIGS[tokyonight_night]="dark|Visual Studio Dark+|tokyo-night|Visual Studio Dark+|tokyo-night|tokyonight-night|gruvbox|gruvbox-dark"
THEME_CONFIGS[tokyonight_day]="light|GitHub|everforest-light-medium|GitHub|tokyo-day|tokyonight-day|solarized-light|everforest-light"

# Gruvbox themes
THEME_CONFIGS[gruvbox_dark]="dark|gruvbox-dark|gruvbox_dark|gruvbox-dark|gruvbox-dark|gruvbox|gruvbox|gruvbox-dark"
THEME_CONFIGS[gruvbox_light]="light|gruvbox-light|gruvbox_light|gruvbox-light|gruvbox-light|gruvbox|solarized-light|gruvbox-light"

# Nord theme
THEME_CONFIGS[nord]="dark|Nord|nord|Nord|nord|nord|solarized-dark|nord"

# Dracula theme
THEME_CONFIGS[dracula]="dark|Dracula|dracula|Dracula|dracula|dracula|solarized-dark|dracula"

# Solarized themes
THEME_CONFIGS[solarized_dark]="dark|Solarized (dark)|solarized_dark|Solarized (dark)|solarized-dark|solarized|solarized-dark|solarized-dark"
THEME_CONFIGS[solarized_light]="light|Solarized (light)|solarized_light|Solarized (light)|solarized-light|solarized|solarized-light|solarized-light"

# FZF color schemes by theme
declare -gA FZF_COLORS
FZF_COLORS[catppuccin_mocha]="--color=dark --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
FZF_COLORS[catppuccin_latte]="--color=light --color=bg+:#ccd0da,bg:#eff1f5,spinner:#dc8a78,hl:#d20f39 --color=fg:#4c4f69,header:#d20f39,info:#8839ef,pointer:#dc8a78 --color=marker:#dc8a78,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39"
FZF_COLORS[tokyonight_night]="--color=dark --color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7 --color=fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff --color=info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff --color=marker:#7dcfff,spinner:#7dcfff,header:#7dcfff"
FZF_COLORS[tokyonight_day]="--color=light --color=fg:#3760bf,bg:#e1e2e7,hl:#2e7de9 --color=fg+:#3760bf,bg+:#c4c8da,hl+:#2e7de9 --color=info:#188092,prompt:#188092,pointer:#188092 --color=marker:#188092,spinner:#188092,header:#188092"
FZF_COLORS[gruvbox_dark]="--color=dark --color=fg:#ebdbb2,bg:#282828,hl:#fabd2f --color=fg+:#ebdbb2,bg+:#3c3836,hl+:#fabd2f --color=info:#83a598,prompt:#bdae93,spinner:#fabd2f,pointer:#83a598,marker:#fe8019,header:#665c54"
FZF_COLORS[gruvbox_light]="--color=light --color=fg:#3c3836,bg:#fbf1c7,hl:#af3a03 --color=fg+:#3c3836,bg+:#ebdbb2,hl+:#af3a03 --color=info:#076678,prompt:#79740e,spinner:#8f3f71,pointer:#076678,marker:#8f5902,header:#9d0006"
FZF_COLORS[nord]="--color=dark --color=fg:#d8dee9,bg:#2e3440,hl:#88c0d0 --color=fg+:#eceff4,bg+:#3b4252,hl+:#8fbcbb --color=info:#81a1c1,prompt:#88c0d0,pointer:#88c0d0 --color=marker:#a3be8c,spinner:#ebcb8b,header:#5e81ac"
FZF_COLORS[dracula]="--color=dark --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9 --color=fg+:#f8f8f2,bg+:#44475a,hl+:#ff79c6 --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4"
FZF_COLORS[solarized_dark]="--color=dark --color=fg:#839496,bg:#002b36,hl:#b58900 --color=fg+:#839496,bg+:#073642,hl+:#859900 --color=info:#268bd2,prompt:#859900,pointer:#dc322f --color=marker:#dc322f,spinner:#b58900,header:#586e75"
FZF_COLORS[solarized_light]="--color=light --color=fg:#657b83,bg:#fdf6e3,hl:#b58900 --color=fg+:#657b83,bg+:#eee8d5,hl+:#859900 --color=info:#268bd2,prompt:#859900,pointer:#dc322f --color=marker:#dc322f,spinner:#b58900,header:#93a1a1"
FZF_COLORS[everforest_dark]="--color=dark --color=fg:#d3c6aa,bg:#2d353b,hl:#a7c080 --color=fg+:#d3c6aa,bg+:#3d484d,hl+:#a7c080 --color=info:#e67e80,prompt:#a7c080,pointer:#e67e80 --color=marker:#a7c080,spinner:#e67e80,header:#a7c080"
FZF_COLORS[everforest_light]="--color=light --color=fg:#5c6a72,bg:#fdf6e3,hl:#35a77c --color=fg+:#5c6a72,bg+:#f4f0d0,hl+:#35a77c --color=info:#5c6a72,prompt:#5c6a72,pointer:#d73a49 --color=marker:#5c6a72,spinner:#5c6a72,header:#5c6a72"

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
  local theme="${1:-everforest-dark}"
  local key

  [[ -z "$theme" ]] && theme="everforest-dark"
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
