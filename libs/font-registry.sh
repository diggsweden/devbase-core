#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Central registry for font metadata

[[ -n "${_DEVBASE_FONT_REGISTRY_LOADED:-}" ]] && return 0
readonly _DEVBASE_FONT_REGISTRY_LOADED=1

# User-facing font ordering
# shellcheck disable=SC2034 # Used by TUI selection flows
declare -ga FONT_ORDER=(
  monaspace
  jetbrains-mono
  firacode
  cascadia-code
)

# Font descriptions for TUI prompts
# shellcheck disable=SC2034 # Used by TUI selection flows
declare -gA FONT_DESCRIPTIONS
FONT_DESCRIPTIONS[monaspace]="Superfamily, multiple styles"
FONT_DESCRIPTIONS[jetbrains_mono]="Clear, excellent readability"
FONT_DESCRIPTIONS[firacode]="Popular, extensive ligatures"
FONT_DESCRIPTIONS[cascadia_code]="Microsoft, Powerline glyphs"

# Display names used in summaries and UI
# shellcheck disable=SC2034 # Used by installer summaries
declare -gA FONT_DISPLAY_NAMES
FONT_DISPLAY_NAMES[monaspace]="Monaspace Nerd Font"
FONT_DISPLAY_NAMES[jetbrains_mono]="JetBrains Mono Nerd Font"
FONT_DISPLAY_NAMES[firacode]="Fira Code Nerd Font"
FONT_DISPLAY_NAMES[cascadia_code]="Cascadia Code Nerd Font"

# Installation details: name|zip|dir|family
# shellcheck disable=SC2034 # Used by install-custom
declare -gA FONT_INSTALL_DETAILS
FONT_INSTALL_DETAILS[jetbrains_mono]="JetBrainsMono|JetBrainsMono.zip|JetBrainsMonoNerdFont|JetBrainsMono Nerd Font Mono"
FONT_INSTALL_DETAILS[firacode]="FiraCode|FiraCode.zip|FiraCodeNerdFont|FiraCode Nerd Font Mono"
FONT_INSTALL_DETAILS[cascadia_code]="CascadiaCode|CascadiaCode.zip|CascadiaCodeNerdFont|CaskaydiaCove Nerd Font Mono"
FONT_INSTALL_DETAILS[monaspace]="Monaspace|Monaspace.zip|MonaspaceNerdFont|MonaspiceNe Nerd Font Mono"

font_registry_key() {
  printf "%s" "${1//-/_}"
}

get_font_ids() {
  printf "%s\n" "${FONT_ORDER[@]}"
}

get_font_description() {
  local font="${1:-$(get_default_font)}"
  local key
  key=$(font_registry_key "$font")
  printf "%s" "${FONT_DESCRIPTIONS[$key]:-}"
}

get_font_display_name() {
  local font="${1:-$(get_default_font)}"
  local key
  key=$(font_registry_key "$font")
  printf "%s" "${FONT_DISPLAY_NAMES[$key]:-$font}"
}

get_font_install_details() {
  local font="${1:-$(get_default_font)}"
  local key
  key=$(font_registry_key "$font")
  printf "%s" "${FONT_INSTALL_DETAILS[$key]:-}"
}
