function update-gnome-terminal-theme --description "Update GNOME Terminal theme on native Ubuntu"
    # Only run on native Linux (not WSL)
    if uname -r | grep -qi microsoft
        return 0
    end

    # Only run if gsettings is available (GNOME Terminal)
    if not command -v gsettings &>/dev/null
        return 0
    end

    # Check if we have a display (X11 or Wayland)
    if test -z "$DISPLAY"; and test -z "$WAYLAND_DISPLAY"
        return 0
    end

    # Get current devbase theme
    set -l devbase_theme "$DEVBASE_THEME"
    if test -z "$devbase_theme"
        return 0
    end

    # Get default profile ID
    set -l profile_id (gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    if test -z "$profile_id"
        return 0
    end

    # Profile path for gsettings
    set -l profile_path "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile_id/"

    # Map devbase theme to colors (from Gogh theme collection)
    # Color palette format: 16 colors (color_01 to color_16)
    set -l bg fg cursor
    set -l palette

    switch $devbase_theme
        case everforest-dark
            # Everforest Dark Hard
            set bg '#272E33'
            set fg '#D3C6AA'
            set cursor '#D3C6AA'
            set palette '#2E383C' '#E67E80' '#A7C080' '#DBBC7F' '#7FBBB3' '#D699B6' '#83C092' '#D3C6AA' '#5C6A72' '#F85552' '#8DA101' '#DFA000' '#3A94C5' '#DF69BA' '#35A77C' '#DFDDC8'

        case everforest-light
            # Everforest Light Medium
            set bg '#FDF6E3'
            set fg '#5C6A72'
            set cursor '#5C6A72'
            set palette '#5C6A72' '#F85552' '#8DA101' '#DFA000' '#3A94C5' '#DF69BA' '#35A77C' '#DFDDC8' '#343F44' '#E67E80' '#A7C080' '#DBBC7F' '#7FBBB3' '#D699B6' '#83C092' '#D3C6AA'

        case catppuccin-mocha
            # Catppuccin Mocha
            set bg '#1E1E2E'
            set fg '#CDD6F4'
            set cursor '#CDD6F4'
            set palette '#45475A' '#F38BA8' '#A6E3A1' '#F9E2AF' '#89B4FA' '#F5C2E7' '#94E2D5' '#BAC2DE' '#585B70' '#F38BA8' '#A6E3A1' '#F9E2AF' '#89B4FA' '#F5C2E7' '#94E2D5' '#A6ADC8'

        case catppuccin-latte
            # Catppuccin Latte
            set bg '#EFF1F5'
            set fg '#4C4F69'
            set cursor '#4C4F69'
            set palette '#5C5F77' '#D20F39' '#40A02B' '#DF8E1D' '#1E66F5' '#EA76CB' '#179299' '#ACB0BE' '#6C6F85' '#D20F39' '#40A02B' '#DF8E1D' '#1E66F5' '#EA76CB' '#179299' '#BCC0CC'

        case tokyonight-night
            # Tokyo Night
            set bg '#1A1B26'
            set fg '#C0CAF5'
            set cursor '#C0CAF5'
            set palette '#414868' '#F7768E' '#9ECE6A' '#E0AF68' '#7AA2F7' '#BB9AF7' '#7DCFFF' '#A9B1D6' '#414868' '#F7768E' '#9ECE6A' '#E0AF68' '#7AA2F7' '#BB9AF7' '#7DCFFF' '#C0CAF5'

        case tokyonight-day
            # Tokyo Night Light
            set bg '#D5D6DB'
            set fg '#565A6E'
            set cursor '#565A6E'
            set palette '#0F0F14' '#8C4351' '#485E30' '#8F5E15' '#34548A' '#5A4A78' '#0F4B6E' '#343B58' '#9699A3' '#8C4351' '#485E30' '#8F5E15' '#34548A' '#5A4A78' '#0F4B6E' '#343B58'

        case gruvbox-dark
            # Gruvbox Dark
            set bg '#282828'
            set fg '#EBDBB2'
            set cursor '#EBDBB2'
            set palette '#282828' '#CC241D' '#98971A' '#D79921' '#458588' '#B16286' '#689D6A' '#A89984' '#928374' '#FB4934' '#B8BB26' '#FABD2F' '#83A598' '#D3869B' '#8EC07C' '#EBDBB2'

        case gruvbox-light
            # Gruvbox Material Light
            set bg '#FBF1C7'
            set fg '#654735'
            set cursor '#654735'
            set palette '#F2E5BC' '#C14A4A' '#6C782E' '#B47109' '#45707A' '#945E80' '#4C7A5D' '#654735' '#F2E5BC' '#C14A4A' '#6C782E' '#B47109' '#45707A' '#945E80' '#4C7A5D' '#654735'

        case '*'
            # Default to everforest-dark
            set bg '#272E33'
            set fg '#D3C6AA'
            set cursor '#D3C6AA'
            set palette '#2E383C' '#E67E80' '#A7C080' '#DBBC7F' '#7FBBB3' '#D699B6' '#83C092' '#D3C6AA' '#5C6A72' '#F85552' '#8DA101' '#DFA000' '#3A94C5' '#DF69BA' '#35A77C' '#DFDDC8'
    end

    # Build palette string for gsettings (format: ['#color1', '#color2', ...])
    set -l palette_str "["
    for i in (seq 1 (count $palette))
        set palette_str "$palette_str'$palette[$i]'"
        if test $i -lt (count $palette)
            set palette_str "$palette_str, "
        end
    end
    set palette_str "$palette_str]"

    # Apply theme to GNOME Terminal
    gsettings set $profile_path use-theme-colors false 2>/dev/null
    gsettings set $profile_path background-color "$bg" 2>/dev/null
    gsettings set $profile_path foreground-color "$fg" 2>/dev/null
    gsettings set $profile_path cursor-background-color "$cursor" 2>/dev/null
    gsettings set $profile_path cursor-foreground-color "$bg" 2>/dev/null
    gsettings set $profile_path palette "$palette_str" 2>/dev/null
    gsettings set $profile_path bold-color-same-as-fg true 2>/dev/null
end
