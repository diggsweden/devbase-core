function __update_gnome_get_theme_colors --description "Get theme colors for GNOME Terminal"
    set -l theme_name $argv[1]
    
    switch $theme_name
        case everforest-dark
            echo '#272E33'
            echo '#D3C6AA'
            echo '#D3C6AA'
            echo '#2E383C' '#E67E80' '#A7C080' '#DBBC7F' '#7FBBB3' '#D699B6' '#83C092' '#D3C6AA' '#5C6A72' '#F85552' '#8DA101' '#DFA000' '#3A94C5' '#DF69BA' '#35A77C' '#DFDDC8'

        case everforest-light
            echo '#FDF6E3'
            echo '#5C6A72'
            echo '#5C6A72'
            echo '#5C6A72' '#F85552' '#8DA101' '#DFA000' '#3A94C5' '#DF69BA' '#35A77C' '#DFDDC8' '#343F44' '#E67E80' '#A7C080' '#DBBC7F' '#7FBBB3' '#D699B6' '#83C092' '#D3C6AA'

        case catppuccin-mocha
            echo '#1E1E2E'
            echo '#CDD6F4'
            echo '#CDD6F4'
            echo '#45475A' '#F38BA8' '#A6E3A1' '#F9E2AF' '#89B4FA' '#F5C2E7' '#94E2D5' '#BAC2DE' '#585B70' '#F38BA8' '#A6E3A1' '#F9E2AF' '#89B4FA' '#F5C2E7' '#94E2D5' '#A6ADC8'

        case catppuccin-latte
            echo '#EFF1F5'
            echo '#4C4F69'
            echo '#4C4F69'
            echo '#5C5F77' '#D20F39' '#40A02B' '#DF8E1D' '#1E66F5' '#EA76CB' '#179299' '#ACB0BE' '#6C6F85' '#D20F39' '#40A02B' '#DF8E1D' '#1E66F5' '#EA76CB' '#179299' '#BCC0CC'

        case tokyonight-night
            echo '#1A1B26'
            echo '#C0CAF5'
            echo '#C0CAF5'
            echo '#414868' '#F7768E' '#9ECE6A' '#E0AF68' '#7AA2F7' '#BB9AF7' '#7DCFFF' '#A9B1D6' '#414868' '#F7768E' '#9ECE6A' '#E0AF68' '#7AA2F7' '#BB9AF7' '#7DCFFF' '#C0CAF5'

        case tokyonight-day
            echo '#D5D6DB'
            echo '#565A6E'
            echo '#565A6E'
            echo '#0F0F14' '#8C4351' '#485E30' '#8F5E15' '#34548A' '#5A4A78' '#0F4B6E' '#343B58' '#9699A3' '#8C4351' '#485E30' '#8F5E15' '#34548A' '#5A4A78' '#0F4B6E' '#343B58'

        case gruvbox-dark
            echo '#282828'
            echo '#EBDBB2'
            echo '#EBDBB2'
            echo '#282828' '#CC241D' '#98971A' '#D79921' '#458588' '#B16286' '#689D6A' '#A89984' '#928374' '#FB4934' '#B8BB26' '#FABD2F' '#83A598' '#D3869B' '#8EC07C' '#EBDBB2'

        case gruvbox-light
            echo '#FBF1C7'
            echo '#3C3836'
            echo '#3C3836'
            echo '#FBF1C7' '#CC241D' '#98971A' '#D79921' '#458588' '#B16286' '#689D6A' '#7C6F64' '#928374' '#9D0006' '#79740E' '#B57614' '#076678' '#8F3F71' '#427B58' '#3C3836'

        case nord
            echo '#2E3440'
            echo '#D8DEE9'
            echo '#D8DEE9'
            echo '#3B4252' '#BF616A' '#A3BE8C' '#EBCB8B' '#81A1C1' '#B48EAD' '#88C0D0' '#E5E9F0' '#4C566A' '#BF616A' '#A3BE8C' '#EBCB8B' '#81A1C1' '#B48EAD' '#8FBCBB' '#ECEFF4'

        case dracula
            echo '#282A36'
            echo '#F8F8F2'
            echo '#F8F8F2'
            echo '#21222C' '#FF5555' '#50FA7B' '#F1FA8C' '#BD93F9' '#FF79C6' '#8BE9FD' '#F8F8F2' '#6272A4' '#FF6E6E' '#69FF94' '#FFFFA5' '#D6ACFF' '#FF92DF' '#A4FFFF' '#FFFFFF'

        case solarized-dark
            echo '#002B36'
            echo '#839496'
            echo '#839496'
            echo '#073642' '#DC322F' '#859900' '#B58900' '#268BD2' '#D33682' '#2AA198' '#EEE8D5' '#002B36' '#CB4B16' '#586E75' '#657B83' '#839496' '#6C71C4' '#93A1A1' '#FDF6E3'

        case solarized-light
            echo '#FDF6E3'
            echo '#657B83'
            echo '#657B83'
            echo '#073642' '#DC322F' '#859900' '#B58900' '#268BD2' '#D33682' '#2AA198' '#EEE8D5' '#002B36' '#CB4B16' '#586E75' '#657B83' '#839496' '#6C71C4' '#93A1A1' '#FDF6E3'

        case '*'
            echo '#2D353B'
            echo '#D3C6AA'
            echo '#D3C6AA'
            echo '#2E383C' '#E67E80' '#A7C080' '#DBBC7F' '#7FBBB3' '#D699B6' '#83C092' '#D3C6AA' '#5C6A72' '#F85552' '#8DA101' '#DFA000' '#3A94C5' '#DF69BA' '#35A77C' '#DFDDC8'
    end
end

function __update_gnome_build_palette_string --description "Build palette string for gsettings"
    set -l palette $argv
    set -l palette_str "["
    
    for i in (seq 1 (count $palette))
        set palette_str "$palette_str'$palette[$i]'"
        if test $i -lt (count $palette)
            set palette_str "$palette_str, "
        end
    end
    set palette_str "$palette_str]"
    
    echo $palette_str
end

function __update_gnome_apply_colors --description "Apply colors to GNOME Terminal profile"
    set -l profile_path $argv[1]
    set -l bg $argv[2]
    set -l fg $argv[3]
    set -l cursor $argv[4]
    set -l palette_str $argv[5]
    
    gsettings set $profile_path use-theme-colors false
    and gsettings set $profile_path background-color "$bg"
    and gsettings set $profile_path foreground-color "$fg"
    and gsettings set $profile_path cursor-background-color "$cursor"
    and gsettings set $profile_path cursor-foreground-color "$bg"
    and gsettings set $profile_path palette "$palette_str"
    and gsettings set $profile_path bold-color-same-as-fg true
end

function __update_gnome_terminal_theme --description "Update GNOME Terminal theme on native Ubuntu"
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

    # Get theme colors (bg, fg, cursor, palette...)
    set -l colors (__update_gnome_get_theme_colors $devbase_theme)
    set -l bg $colors[1]
    set -l fg $colors[2]
    set -l cursor $colors[3]
    set -l palette $colors[4..-1]

    # Build palette string for gsettings
    set -l palette_str (__update_gnome_build_palette_string $palette)

    # Apply theme to GNOME Terminal
    __update_gnome_apply_colors $profile_path $bg $fg $cursor $palette_str
end
