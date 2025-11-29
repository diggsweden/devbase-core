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
    switch $DEVBASE_THEME
        case "everforest-dark"
            # Everforest doesn't exist in vivid, use jellybeans as closest match
            set -gx LS_COLORS (vivid generate jellybeans)
        case "gruvbox-dark"
            set -gx LS_COLORS (vivid generate gruvbox-dark)
        case "gruvbox-light"
            set -gx LS_COLORS (vivid generate gruvbox-light)
        case "catppuccin-mocha"
            set -gx LS_COLORS (vivid generate catppuccin-mocha)
        case "nord"
            set -gx LS_COLORS (vivid generate nord)
        case "dracula"
            set -gx LS_COLORS (vivid generate dracula)
        case "one-dark"
            set -gx LS_COLORS (vivid generate one-dark)
        case '*'
            # Default to a generic dark theme
            set -gx LS_COLORS (vivid generate ayu)
    end
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