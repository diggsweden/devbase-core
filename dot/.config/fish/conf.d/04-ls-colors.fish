# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# LS_COLORS theme configuration for Digg
# This file will be placed in ~/.config/fish/conf.d/
# Generates themed LS_COLORS using vivid based on DEVBASE_THEME

# Function to map DEVBASE_THEME to vivid theme
function update_ls_colors
    # Check if vivid is available
    if not command -q vivid
        return
    end
    
    # Map DEVBASE_THEME to appropriate vivid theme
    # vivid ships every DevBase theme except Everforest (`vivid themes`)
    set -l vivid_theme
    switch $DEVBASE_THEME
        case everforest-dark
            set vivid_theme jellybeans
        case everforest-light
            set vivid_theme one-light
        case catppuccin-mocha catppuccin-latte tokyonight-night tokyonight-day gruvbox-dark gruvbox-light solarized-dark solarized-light nord dracula
            set vivid_theme $DEVBASE_THEME
        case '*'
            set vivid_theme ayu
    end
    set -gx LS_COLORS (vivid generate $vivid_theme)
end

# Set default theme if not already set (first run)
if not set -q DEVBASE_THEME
    set -U DEVBASE_THEME "everforest-dark"
end

# Update LS_COLORS on shell startup
if test -n "$DEVBASE_THEME"
    update_ls_colors
end

# Also update when theme changes (if interactive shell)
if status is-interactive
    function on_theme_change --on-variable DEVBASE_THEME
        update_ls_colors
    end
end