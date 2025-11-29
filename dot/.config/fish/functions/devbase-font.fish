# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

function __devbase_font_show_usage
    printf "Usage: devbase-font <name>\n"
    printf "\nAvailable fonts:\n"
    printf "  jetbrains-mono  - Designed for developers, excellent readability\n"
    printf "  firacode        - Popular, extensive ligatures, clean design\n"
    printf "  cascadia-code   - Microsoft's font, supports Powerline glyphs\n"
    printf "  monaspace       - Superfamily with multiple styles (default)\n"
end

function __devbase_font_validate
    set -l font_name $argv[1]
    set -l valid_fonts jetbrains-mono firacode cascadia-code monaspace
    
    if not contains $font_name $valid_fonts
        printf "Unknown font: %s\n" $font_name
        __devbase_font_show_usage
        return 1
    end
    return 0
end

function __devbase_font_get_properties
    set -l font_name $argv[1]
    
    switch $font_name
        case jetbrains-mono
            echo "JetBrainsMono Nerd Font Mono"
            echo "JetBrainsMonoNerdFont"
            echo "JetBrains Mono Nerd Font"
        case firacode
            echo "FiraCode Nerd Font Mono"
            echo "FiraCodeNerdFont"
            echo "Fira Code Nerd Font"
        case cascadia-code
            echo "CaskaydiaCove Nerd Font Mono"
            echo "CascadiaCodeNerdFont"
            echo "Cascadia Code Nerd Font"
        case monaspace
            echo "MonaspiceNe Nerd Font Mono"
            echo "MonaspaceNerdFont"
            echo "Monaspace Nerd Font"
    end
end

function __devbase_font_get_zip_name
    set -l font_name $argv[1]
    
    switch $font_name
        case jetbrains-mono
            echo "JetBrainsMono.zip"
        case firacode
            echo "FiraCode.zip"
        case cascadia-code
            echo "CascadiaCode.zip"
        case monaspace
            echo "Monaspace.zip"
    end
end

function __devbase_font_get_version --description "Get Nerd Fonts version from config"
    # Try to read version from custom-tools.yaml
    set -l config_file "$HOME/.config/devbase/custom-tools.yaml"
    if test -f "$config_file"
        set -l nf_version (grep "^nerd_fonts:" "$config_file" | awk '{print $2}' | tr -d '#' | xargs)
        if test -n "$nf_version"
            echo $nf_version
            return 0
        end
    end
    # Fallback to default version
    echo "v3.4.0"
end

function __devbase_font_download_to_cache
    set -l zip_name $argv[1]
    set -l nf_version $argv[2]
    set -l cache_dir "$HOME/.cache/devbase/fonts"
    
    set -l font_url "https://github.com/ryanoasis/nerd-fonts/releases/download/$nf_version/$zip_name"
    set -l versioned_cache_dir "$cache_dir/$nf_version"
    set -l font_zip "$versioned_cache_dir/$zip_name"
    
    printf "Downloading font to cache...\n"
    
    # Create cache directory
    mkdir -p "$versioned_cache_dir"
    
    # Try to download
    if curl -fsSL -o "$font_zip" "$font_url" 2>/dev/null
        # Create version file
        echo "$nf_version" > "$versioned_cache_dir/.version"
        echo "$font_zip"
        return 0
    end
    
    # Download failed - clean up
    rm -f "$font_zip"
    return 1
end

function __devbase_font_find_or_download_font --description "Find font in cache or download it"
    set -l zip_name $argv[1]
    set -l cache_dir "$HOME/.cache/devbase/fonts"
    
    # Get configured version
    set -l nf_version (__devbase_font_get_version)
    set -l font_zip "$cache_dir/$nf_version/$zip_name"
    
    # Check if configured version is cached
    if test -f "$font_zip"
        echo "$font_zip"
        return 0
    end
    
    # Try to download configured version
    if __devbase_font_download_to_cache "$zip_name" "$nf_version"
        echo "$font_zip"
        return 0
    end
    
    # Download failed
    return 1
end

function __devbase_font_install_from_cache --description "Install font from cache or download it"
    set -l font_name $argv[1]
    set -l font_dir_name $argv[2]
    set -l font_display_name $argv[3]
    
    set -l zip_name (__devbase_font_get_zip_name $font_name)
    set -l nf_version (__devbase_font_get_version)
    set -l font_zip (__devbase_font_find_or_download_font $zip_name)
    set -l font_dir "$HOME/.local/share/fonts/$font_dir_name"
    
    # Check if font is available (cached or downloaded)
    if test -z "$font_zip"
        printf "✗ Failed to download font: %s\n" $font_display_name
        printf "\n"
        printf "  You can manually download the font:\n"
        printf "  1. Create cache directory:\n"
        printf "     mkdir -p ~/.cache/devbase/fonts/%s\n" $nf_version
        printf "\n"
        printf "  2. Download font:\n"
        printf "     curl -fsSL -o ~/.cache/devbase/fonts/%s/%s \\\n" $nf_version $zip_name
        printf "       https://github.com/ryanoasis/nerd-fonts/releases/download/%s/%s\n" $nf_version $zip_name
        printf "\n"
        printf "  3. Try again:\n"
        printf "     devbase-font %s\n" $font_name
        printf "\n"
        printf "  Alternatively, run 'devbase setup' to download all fonts.\n"
        return 1
    end
    
    # Extract font from cache
    printf "Installing %s from cache...\n" $font_display_name
    mkdir -p "$font_dir"
    
    # Extract fonts - unzip may return non-zero if one pattern doesn't match, so check file count instead
    unzip -q -o "$font_zip" "*.ttf" "*.otf" -d "$font_dir" 2>/dev/null; or true
    
    # Verify extraction by counting font files
    set -l font_count (find "$font_dir" \( -name "*.ttf" -o -name "*.otf" \) 2>/dev/null | wc -l)
    if test $font_count -eq 0
        printf "✗ Failed to extract font from cache\n"
        return 1
    end
    
    # Update font cache
    if command -v fc-cache >/dev/null 2>&1
        fc-cache -f "$HOME/.local/share/fonts"
    end
    
    printf "✓ %s installed successfully\n" $font_display_name
    return 0
end

function __devbase_font_check_installed --description "Check if font is installed, install from cache if needed"
    set -l font_name $argv[1]
    set -l font_dir_name $argv[2]
    set -l font_display_name $argv[3]
    set -l font_dir "$HOME/.local/share/fonts/$font_dir_name"
    
    # Check if already installed
    if test -d "$font_dir"
        set -l font_count (find "$font_dir" \( -name "*.ttf" -o -name "*.otf" \) 2>/dev/null | wc -l)
        if test $font_count -gt 0
            return 0
        end
    end
    
    # Try to install from cache
    if __devbase_font_install_from_cache $font_name $font_dir_name $font_display_name
        return 0
    end
    
    return 1
end

function __devbase_font_update_gnome_terminal
    set -l font_family_name $argv[1]
    
    if command -v gsettings &>/dev/null; and test -n "$DISPLAY$WAYLAND_DISPLAY"
        set -l profile_id (gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
        if test -n "$profile_id"
            gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile_id/" font "$font_family_name 11" 2>/dev/null
            gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile_id/" use-system-font false 2>/dev/null
            return 0
        end
    end
    return 1
end

function __devbase_font_update_ghostty
    set -l font_family_name $argv[1]
    set -l ghostty_config "$HOME/.config/ghostty/config"
    
    if not test -f "$ghostty_config"
        return 1
    end
    
    if grep -q "^font-family" "$ghostty_config"
        sed -i "s|^font-family.*|font-family = \"$font_family_name\"|" "$ghostty_config"
    else
        echo "" >> "$ghostty_config"
        echo "# Nerd Font for icons and symbols" >> "$ghostty_config"
        echo "font-family = \"$font_family_name\"" >> "$ghostty_config"
    end
    return 0
end

function __devbase_font_get_vscode_settings_path
    if test -d ~/.vscode-server/data/Machine
        echo ~/.vscode-server/data/Machine/settings.json
        return 0
    else if test -d ~/.config/Code/User
        echo ~/.config/Code/User/settings.json
        return 0
    end
    return 1
end

function __devbase_font_update_vscode
    set -l font_family_name $argv[1]
    set -l settings_file (__devbase_font_get_vscode_settings_path)
    
    if test -z "$settings_file"
        return 1
    end
    
    if test -f $settings_file
        if command -v jq &>/dev/null
            jq --arg font "$font_family_name" '. + {"editor.fontFamily": $font}' $settings_file > $settings_file.tmp
            mv $settings_file.tmp $settings_file
            return 0
        end
    else
        mkdir -p (dirname $settings_file)
        echo '{
  "editor.fontFamily": "'$font_family_name'"
}' > $settings_file
        return 0
    end
    return 1
end

function __devbase_font_print_results
    set -l font_display_name $argv[1]
    set -l gnome_terminal_updated $argv[2]
    set -l ghostty_updated $argv[3]
    set -l vscode_updated $argv[4]
    
    printf "✓ Font set to: %s\n" $font_display_name
    printf "\n"
    
    if test $gnome_terminal_updated = true
        printf "  GNOME Terminal: Font updated\n"
    end
    if test $ghostty_updated = true
        printf "  Ghostty: Config updated\n"
    end
    if test $vscode_updated = true
        printf "  VSCode: Font updated\n"
    end
    
    printf "\n"
    printf "  ⚠  IMPORTANT: Restart required for changes to take effect:\n"
    printf "     • Close and reopen your terminal\n"
    if test $ghostty_updated = true
        printf "     • Ghostty: Reload config (Ctrl+Shift+Comma) or restart\n"
    end
    if test $vscode_updated = true
        printf "     • VSCode: Reload window (Ctrl+Shift+P → 'Reload Window')\n"
    end
end

function devbase-font --description "Set font for terminals and editors"
    # Check if running on WSL
    if uname -r | grep -qi microsoft
        printf "⚠  devbase-font is not applicable on WSL\n"
        printf "\n"
        printf "  Fonts must be installed on Windows, not in WSL.\n"
        printf "  Download from: https://github.com/ryanoasis/nerd-fonts/releases\n"
        printf "\n"
        return 0
    end
    
    set -l font_name $argv[1]
    
    # Check for missing argument
    if test -z "$font_name"
        __devbase_font_show_usage
        return 1
    end
    
    # Validate font name
    if not __devbase_font_validate $font_name
        return 1
    end
    
    # Get font properties
    set -l font_properties (__devbase_font_get_properties $font_name)
    set -l font_family_name $font_properties[1]
    set -l font_dir_name $font_properties[2]
    set -l font_display_name $font_properties[3]
    
    # Check if font is installed (will install from cache if needed)
    if not __devbase_font_check_installed $font_name $font_dir_name $font_display_name
        return 1
    end
    
    # Update configurations
    set -l gnome_terminal_updated false
    set -l ghostty_updated false
    set -l vscode_updated false
    
    if __devbase_font_update_gnome_terminal $font_family_name
        set gnome_terminal_updated true
    end
    
    if __devbase_font_update_ghostty $font_family_name
        set ghostty_updated true
    end
    
    if __devbase_font_update_vscode $font_family_name
        set vscode_updated true
    end
    
    # Save font preference
    set -e DEVBASE_FONT
    set -U DEVBASE_FONT $font_name
    
    # Print results
    __devbase_font_print_results $font_display_name $gnome_terminal_updated $ghostty_updated $vscode_updated
end
