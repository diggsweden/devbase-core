#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Central registry for theme metadata and tool mappings

[[ -n "${_DEVBASE_THEME_REGISTRY_LOADED:-}" ]] && return 0
readonly _DEVBASE_THEME_REGISTRY_LOADED=1

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

# User-facing theme ordering
# shellcheck disable=SC2034 # Used by TUI selection flows
declare -ga THEME_ORDER=(
  everforest-dark catppuccin-mocha tokyonight-night gruvbox-dark
  nord dracula solarized-dark
  everforest-light catppuccin-latte tokyonight-day gruvbox-light solarized-light
)

# Theme descriptions for TUI prompts
# shellcheck disable=SC2034 # Used by TUI selection flows
declare -gA THEME_DESCRIPTIONS
THEME_DESCRIPTIONS[everforest_dark]="◐ Warm, soft"
THEME_DESCRIPTIONS[catppuccin_mocha]="◐ Soothing pastel"
THEME_DESCRIPTIONS[tokyonight_night]="◐ Clean, dark"
THEME_DESCRIPTIONS[gruvbox_dark]="◐ Retro groove"
THEME_DESCRIPTIONS[nord]="◐ Arctic, bluish"
THEME_DESCRIPTIONS[dracula]="◐ Dark, vivid"
THEME_DESCRIPTIONS[solarized_dark]="◐ Precision colors"
THEME_DESCRIPTIONS[everforest_light]="◑ Warm, soft"
THEME_DESCRIPTIONS[catppuccin_latte]="◑ Soothing pastel"
THEME_DESCRIPTIONS[tokyonight_day]="◑ Clean, bright"
THEME_DESCRIPTIONS[gruvbox_light]="◑ Retro groove"
THEME_DESCRIPTIONS[solarized_light]="◑ Precision colors"

# Theme preview colors (bg,fg,keyword,function,string,comment)
# shellcheck disable=SC2034 # Used by gum TUI
declare -gA THEME_PREVIEW_COLORS
THEME_PREVIEW_COLORS[everforest_dark]="236,223,167,108,142,245"
THEME_PREVIEW_COLORS[catppuccin_mocha]="236,223,203,139,166,245"
THEME_PREVIEW_COLORS[tokyonight_night]="234,223,203,116,158,243"
THEME_PREVIEW_COLORS[gruvbox_dark]="235,223,167,108,142,245"
THEME_PREVIEW_COLORS[nord]="236,223,168,136,150,243"
THEME_PREVIEW_COLORS[dracula]="236,223,212,117,84,243"
THEME_PREVIEW_COLORS[solarized_dark]="235,223,168,37,106,241"
THEME_PREVIEW_COLORS[everforest_light]="230,235,124,66,107,245"
THEME_PREVIEW_COLORS[catppuccin_latte]="231,235,127,37,71,245"
THEME_PREVIEW_COLORS[tokyonight_day]="231,235,128,37,71,245"
THEME_PREVIEW_COLORS[gruvbox_light]="230,235,124,66,106,245"
THEME_PREVIEW_COLORS[solarized_light]="230,235,168,37,106,245"

# Display names used in summaries and UI
# shellcheck disable=SC2034 # Used by installer summaries
declare -gA THEME_DISPLAY_NAMES
THEME_DISPLAY_NAMES[everforest_dark]="Everforest Dark"
THEME_DISPLAY_NAMES[everforest_light]="Everforest Light"
THEME_DISPLAY_NAMES[catppuccin_mocha]="Catppuccin Mocha"
THEME_DISPLAY_NAMES[catppuccin_latte]="Catppuccin Latte"
THEME_DISPLAY_NAMES[tokyonight_night]="Tokyo Night"
THEME_DISPLAY_NAMES[tokyonight_day]="Tokyo Night Day"
THEME_DISPLAY_NAMES[gruvbox_dark]="Gruvbox Dark"
THEME_DISPLAY_NAMES[gruvbox_light]="Gruvbox Light"
THEME_DISPLAY_NAMES[nord]="Nord"
THEME_DISPLAY_NAMES[dracula]="Dracula"
THEME_DISPLAY_NAMES[solarized_dark]="Solarized Dark"
THEME_DISPLAY_NAMES[solarized_light]="Solarized Light"

# VS Code theme names
# shellcheck disable=SC2034 # Used by VS Code setup
declare -gA THEME_VSCODE_NAMES
THEME_VSCODE_NAMES[everforest_dark]="Everforest Dark"
THEME_VSCODE_NAMES[everforest_light]="Everforest Light"
THEME_VSCODE_NAMES[catppuccin_mocha]="Catppuccin Mocha"
THEME_VSCODE_NAMES[catppuccin_latte]="Catppuccin Latte"
THEME_VSCODE_NAMES[tokyonight_night]="Tokyo Night"
THEME_VSCODE_NAMES[tokyonight_day]="Tokyo Night Light"
THEME_VSCODE_NAMES[gruvbox_dark]="Gruvbox Dark Medium"
THEME_VSCODE_NAMES[gruvbox_light]="Gruvbox Light Medium"
THEME_VSCODE_NAMES[nord]="Nord"
THEME_VSCODE_NAMES[dracula]="Dracula Theme"
THEME_VSCODE_NAMES[solarized_dark]="Solarized Dark+"
THEME_VSCODE_NAMES[solarized_light]="Solarized Light+"

theme_registry_key() {
  printf "%s" "${1//-/_}"
}

get_theme_display_name() {
  local theme="${1:-$(get_default_theme)}"
  local key
  key=$(theme_registry_key "$theme")
  if [[ -n "${THEME_DISPLAY_NAMES[$key]:-}" ]]; then
    printf "%s" "${THEME_DISPLAY_NAMES[$key]}"
  else
    printf "%s" "$theme"
  fi
}

get_vscode_theme_name() {
  local theme="${1:-$(get_default_theme)}"
  local key
  key=$(theme_registry_key "$theme")
  printf "%s" "${THEME_VSCODE_NAMES[$key]:-${THEME_VSCODE_NAMES[everforest_dark]}}"
}

get_theme_ids() {
  printf "%s\n" "${THEME_ORDER[@]}"
}

get_light_theme_ids() {
  local theme key is_light
  for theme in "${THEME_ORDER[@]}"; do
    key="${theme//-/_}"
    IFS='|' read -r is_light _ <<<"${THEME_CONFIGS[$key]}"
    [[ "$is_light" == "light" ]] && printf "%s\n" "$theme"
  done
}
