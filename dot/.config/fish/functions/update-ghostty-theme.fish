function update-ghostty-theme --description "Update Ghostty theme on native Ubuntu"
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
            set ghostty_theme "Everforest Dark Hard"
        case everforest-light
            set ghostty_theme "Everforest Light Med"
        case catppuccin-mocha
            set ghostty_theme "Catppuccin Mocha"
        case catppuccin-latte
            set ghostty_theme "Catppuccin Latte"
        case tokyonight-night
            set ghostty_theme "TokyoNight Night"
        case tokyonight-day
            set ghostty_theme "TokyoNight Day"
        case gruvbox-dark
            set ghostty_theme "Gruvbox Dark"
        case gruvbox-light
            set ghostty_theme "Gruvbox Light"
        case '*'
            set ghostty_theme "Everforest Dark Hard"
    end

    # Update Ghostty config file
    set -l ghostty_config "$XDG_CONFIG_HOME/ghostty/config"
    if test -f "$ghostty_config"
        # Update or add theme line
        if grep -q "^theme = " "$ghostty_config"
            sed -i "s|^theme = .*|theme = $ghostty_theme|" "$ghostty_config"
        else
            echo "theme = $ghostty_theme" >> "$ghostty_config"
        end
    end
end
