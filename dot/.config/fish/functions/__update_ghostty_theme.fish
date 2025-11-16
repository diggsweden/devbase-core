function __update_ghostty_theme --description "Update Ghostty theme on native Ubuntu"
    # Only run on native Linux (not WSL)
    if uname -r | grep -qi microsoft
        return 0
    end

    # Only run if TERM_PROGRAM is ghostty
    if test "$TERM_PROGRAM" != "ghostty"
        return 0
    end

    # Get current devbase theme
    set -l devbase_theme "$DEVBASE_THEME"
    if test -z "$devbase_theme"
        return 0
    end

    # Map devbase theme to Ghostty built-in theme name
    # Run `ghostty +list-themes` to see all available themes
    set -l ghostty_theme
    switch $devbase_theme
        case everforest-dark
            set ghostty_theme "Everforest Dark Hard (resources)"
        case everforest-light
            set ghostty_theme "Everforest Light Med (resources)"
        case catppuccin-mocha
            set ghostty_theme "Catppuccin Mocha (resources)"
        case catppuccin-latte
            set ghostty_theme "Catppuccin Latte (resources)"
        case tokyonight-night
            set ghostty_theme "TokyoNight Night (resources)"
        case tokyonight-day
            set ghostty_theme "TokyoNight Day (resources)"
        case gruvbox-dark
            set ghostty_theme "Gruvbox Dark (resources)"
        case gruvbox-light
            set ghostty_theme "Gruvbox Light (resources)"
        case nord
            set ghostty_theme "Nord (resources)"
        case dracula
            set ghostty_theme "Dracula (resources)"
        case solarized-dark
            set ghostty_theme "Solarized Dark Higher Contrast (resources)"
        case solarized-light
            set ghostty_theme "Builtin Solarized Light (resources)"
        case '*'
            set ghostty_theme "Everforest Dark Hard (resources)"
    end

    # Update Ghostty config file
    set -l ghostty_config "$XDG_CONFIG_HOME/ghostty/config"
    if not test -f "$ghostty_config"
        return 0
    end
    
    if grep -q "^theme = " "$ghostty_config"
        sed -i "s|^theme = .*|theme = $ghostty_theme|" "$ghostty_config"
    else
        echo "theme = $ghostty_theme" >> "$ghostty_config"
    end
end
