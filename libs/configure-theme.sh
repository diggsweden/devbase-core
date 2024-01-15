#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1 2>/dev/null || exit 1
fi

source "${DEVBASE_LIBS}/utils.sh"

# Theme presets: is_light|bat|btop|delta|zellij|nvim|vifm
declare -gA THEME_CONFIGS
# WARNING: shfmt incorrectly adds spaces in associative array keys below
# Keep these compact: [everforest-dark] NOT [everforest - dark]
# Manual fix required after running shfmt

# Everforest themes
THEME_CONFIGS[everforest-dark]="dark|Monokai Extended|everforest-dark-hard|Monokai Extended|everforest-dark|everforest|gruvbox"
THEME_CONFIGS[everforest-light]="light|GitHub|everforest-light-medium|GitHub|everforest-light|everforest|solarized-light"

# Catppuccin themes
THEME_CONFIGS[catppuccin-mocha]="dark|Dracula|catppuccin_mocha|Dracula|catppuccin-mocha|catppuccin-mocha|solarized-dark"
THEME_CONFIGS[catppuccin-latte]="light|OneHalfLight|catppuccin_latte|OneHalfLight|catppuccin-latte|catppuccin-latte|solarized-light"

# Tokyo Night themes
THEME_CONFIGS[tokyonight-night]="dark|Visual Studio Dark+|tokyo-night|Visual Studio Dark+|tokyo-night|tokyonight-night|solarized-dark"
THEME_CONFIGS[tokyonight-day]="light|GitHub|tokyo-storm|GitHub|tokyo-day|tokyonight-day|solarized-light"

# Gruvbox themes
THEME_CONFIGS[gruvbox-dark]="dark|gruvbox-dark|gruvbox_dark|gruvbox-dark|gruvbox-dark|gruvbox|gruvbox"
THEME_CONFIGS[gruvbox-light]="light|gruvbox-light|gruvbox_light|gruvbox-light|gruvbox-light|gruvbox|solarized-light"

# Brief: Apply color theme to all tools (bat, btop, delta, fzf, etc.)
# Params: $1 - theme name (default: everforest-dark)
# Uses: THEME_CONFIGS (global)
# Modifies: DEVBASE_THEME, BAT_THEME, BTOP_THEME, DELTA_SYNTAX_THEME, ZELLIJ_THEME,
#           VIFM_COLORSCHEME, K9S_SKIN, DELTA_DARK, LAZYGIT_LIGHT_THEME,
#           DELTA_FEATURES, FZF_DEFAULT_OPTS (all exported)
# Returns: 0 always
# Side-effects: Exports theme variables for all tools
apply_theme() {
  local theme="${1:-everforest-dark}"

  [[ -z "$theme" ]] && theme="everforest-dark"

  # Check if theme exists in config, use default if not
  if [[ -z "${THEME_CONFIGS[$theme]:-}" ]]; then
    printf "Warning: Unknown theme '%s', using default (everforest-dark)\n" "$theme"
    printf "  Supported themes:\n"
    printf "    Everforest: everforest-dark, everforest-light\n"
    printf "    Catppuccin: catppuccin-mocha, catppuccin-latte\n"
    printf "    Tokyo Night: tokyonight-night, tokyonight-day\n"
    printf "    Gruvbox: gruvbox-dark, gruvbox-light\n"
    theme="everforest-dark"
  fi

  IFS='|' read -r is_light bat btop delta _zellij _nvim vifm <<<"${THEME_CONFIGS[$theme]}"

  export DEVBASE_THEME="$theme"
  export BAT_THEME="$bat"
  export BTOP_THEME="$btop"
  export DELTA_SYNTAX_THEME="$delta"
  export ZELLIJ_THEME="$_zellij"
  export VIFM_COLORSCHEME="$vifm"
  
  # K9s skin mapping
  case "$theme" in
    everforest-dark)
      export K9S_SKIN="everforest-dark"
      ;;
    everforest-light)
      export K9S_SKIN="everforest-light"
      ;;
    catppuccin-mocha)
      export K9S_SKIN="catppuccin-mocha"
      ;;
    catppuccin-latte)
      export K9S_SKIN="catppuccin-latte"
      ;;
    tokyonight-night)
      export K9S_SKIN="gruvbox-dark"  # fallback (no official tokyonight skin)
      ;;
    tokyonight-day)
      export K9S_SKIN="everforest-light"  # fallback (no official tokyonight skin)
      ;;
    gruvbox-dark)
      export K9S_SKIN="gruvbox-dark"
      ;;
    gruvbox-light)
      export K9S_SKIN="gruvbox-light"
      ;;
    *)
      export K9S_SKIN="everforest-dark"
      ;;
  esac

  if [[ "$is_light" == "light" ]]; then
    export DELTA_DARK="false"
    export LAZYGIT_LIGHT_THEME="true"
  else
    export DELTA_DARK="true"
    export LAZYGIT_LIGHT_THEME="false"
  fi

  export DELTA_FEATURES="decorations line-numbers"

  # FZF colors by theme family
  case "$theme" in
    catppuccin-mocha)
      export FZF_DEFAULT_OPTS="--color=dark --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
      ;;
    catppuccin-latte)
      export FZF_DEFAULT_OPTS="--color=light --color=bg+:#ccd0da,bg:#eff1f5,spinner:#dc8a78,hl:#d20f39 --color=fg:#4c4f69,header:#d20f39,info:#8839ef,pointer:#dc8a78 --color=marker:#dc8a78,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39"
      ;;
    tokyonight-night)
      export FZF_DEFAULT_OPTS="--color=dark --color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7 --color=fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff --color=info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff --color=marker:#7dcfff,spinner:#7dcfff,header:#7dcfff"
      ;;
    tokyonight-day)
      export FZF_DEFAULT_OPTS="--color=light --color=fg:#3760bf,bg:#e1e2e7,hl:#2e7de9 --color=fg+:#3760bf,bg+:#c4c8da,hl+:#2e7de9 --color=info:#188092,prompt:#188092,pointer:#188092 --color=marker:#188092,spinner:#188092,header:#188092"
      ;;
    gruvbox-dark)
      export FZF_DEFAULT_OPTS="--color=dark --color=fg:#ebdbb2,bg:#282828,hl:#fe8019 --color=fg+:#ebdbb2,bg+:#3c3836,hl+:#fe8019 --color=info:#83a598,prompt:#b8bb26,pointer:#fb4934 --color=marker:#fb4934,spinner:#fb4934,header:#fb4934"
      ;;
    gruvbox-light)
      export FZF_DEFAULT_OPTS="--color=light --color=fg:#3c3836,bg:#fbf1c7,hl:#af3a03 --color=fg+:#3c3836,bg+:#ebdbb2,hl+:#af3a03 --color=info:#076678,prompt:#79740e,pointer:#9d0006 --color=marker:#9d0006,spinner:#9d0006,header:#9d0006"
      ;;
    everforest-light)
      export FZF_DEFAULT_OPTS="--color=light --color=fg:#5c6a72,bg:#fdf6e3,hl:#35a77c --color=fg+:#5c6a72,bg+:#f4f0d0,hl+:#35a77c --color=info:#5c6a72,prompt:#5c6a72,pointer:#d73a49 --color=marker:#5c6a72,spinner:#5c6a72,header:#5c6a72"
      ;;
    *)
      # Default everforest-dark
      export FZF_DEFAULT_OPTS="--color=dark --color=fg:#d3c6aa,bg:#2d353b,hl:#a7c080 --color=fg+:#d3c6aa,bg+:#3d484d,hl+:#a7c080 --color=info:#e67e80,prompt:#a7c080,pointer:#e67e80 --color=marker:#a7c080,spinner:#e67e80,header:#a7c080"
      ;;
  esac
}
