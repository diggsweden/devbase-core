function update-windows-terminal-theme --description "Update Windows Terminal color scheme (WSL only)"
    # Only run in WSL
    if not uname -r | grep -qi microsoft
        return 0
    end

    # Check if jq is available
    if not type -q jq
        return 0
    end

    # Get Windows username - try multiple methods for reliability
    set -l win_user ""
    
    # Method 1: Try PowerShell (works in most cases)
    if test -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
        set win_user (/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command "Write-Host -NoNewline \$env:USERNAME" 2>/dev/null | tr -d '\r\n')
    end
    
    # Method 2: Fallback to cmd.exe
    if test -z "$win_user"; and test -x /mnt/c/Windows/System32/cmd.exe
        set win_user (/mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
    end
    
    # Method 3: Fallback to finding real user directory in /mnt/c/Users
    if test -z "$win_user"; and test -d /mnt/c/Users
        for user_dir in /mnt/c/Users/*
            set -l dir_name (basename "$user_dir")
            # Skip system directories
            if not string match -qr '^(Public|Default|All Users|Default User)$' "$dir_name"
                # Check if this user has a Windows Terminal settings file
                if test -f "$user_dir/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"; or test -f "$user_dir/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
                    set win_user "$dir_name"
                    break
                end
            end
        end
    end
    
    # Exit if we couldn't get Windows username
    if test -z "$win_user"
        echo "✗ Windows Terminal: Could not detect Windows username" >&2
        return 1
    end
    
    # Find Windows Terminal settings path
    set -l wt_settings ""
    set -l possible_paths \
        "/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json" \
        "/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
    
    for path in $possible_paths
        if test -f "$path"
            set wt_settings "$path"
            break
        end
    end
    
    # Exit if settings file not found
    if test -z "$wt_settings"
        echo "✗ Windows Terminal: settings.json not found for user $win_user" >&2
        return 1
    end
    
    # Check if file is writable
    if not test -w "$wt_settings"
        return 0
    end

    # Get current devbase theme
    set -l devbase_theme "$DEVBASE_THEME"
    if test -z "$devbase_theme"
        return 0
    end

    # Map devbase theme to Windows Terminal color scheme file and name
    set -l wt_scheme_name
    set -l wt_scheme_file
    switch $devbase_theme
        case everforest-dark
            set wt_scheme_name "Everforest Dark Hard"
            set wt_scheme_file "everforest-dark-hard.json"
        case everforest-light
            set wt_scheme_name "Everforest Light Med"
            set wt_scheme_file "everforest-light-med.json"
        case catppuccin-mocha
            set wt_scheme_name "Catppuccin Mocha"
            set wt_scheme_file "catppuccin-mocha.json"
        case catppuccin-latte
            set wt_scheme_name "Catppuccin Latte"
            set wt_scheme_file "catppuccin-latte.json"
        case tokyonight-night
            set wt_scheme_name "TokyoNight Night"
            set wt_scheme_file "tokyonight-night.json"
        case tokyonight-day
            set wt_scheme_name "TokyoNight Day"
            set wt_scheme_file "tokyonight-day.json"
        case gruvbox-dark
            set wt_scheme_name "Gruvbox Dark"
            set wt_scheme_file "gruvbox-dark.json"
        case gruvbox-light
            set wt_scheme_name "Gruvbox Light"
            set wt_scheme_file "gruvbox-light.json"
        case '*'
            set wt_scheme_name "Everforest Dark Hard"
            set wt_scheme_file "everforest-dark-hard.json"
    end
    
    # Find theme file in devbase installation
    set -l theme_source ""
    set -l possible_theme_locations \
        "$XDG_DATA_HOME/devbase/files/windows-terminal/$wt_scheme_file" \
        "$HOME/.local/share/devbase/files/windows-terminal/$wt_scheme_file"
    
    for path in $possible_theme_locations
        if test -f "$path"
            set theme_source "$path"
            break
        end
    end
    
    # Exit if theme file not found
    if test -z "$theme_source"
        echo "✗ Windows Terminal: Theme file not found for $devbase_theme" >&2
        echo "  Expected: $XDG_DATA_HOME/devbase/files/windows-terminal/$wt_scheme_file" >&2
        echo "  Note: Theme files are installed during devbase setup" >&2
        echo "  If missing, re-run setup.sh or check installation" >&2
        return 1
    end

    # Create timestamped backup before modification
    set -l timestamp (date +%S.%H.%M.%y)
    set -l settings_dir (dirname "$wt_settings")
    set -l backup_file "$settings_dir/settings.$timestamp.json"
    if not cp "$wt_settings" "$backup_file" 2>/dev/null
        echo "✗ Windows Terminal: Failed to create backup" >&2
        return 1
    end

    # Update Windows Terminal color scheme
    # Create temp file in /tmp (Linux filesystem for better compatibility)
    set -l temp_file (mktemp)
    
    # Update the active colorScheme (themes already installed during setup)
    if jq --arg scheme_name "$wt_scheme_name" '.profiles.defaults.colorScheme = $scheme_name' "$wt_settings" > "$temp_file" 2>/dev/null
        # Validate output is valid JSON and non-empty
        if test -s "$temp_file"; and jq empty "$temp_file" 2>/dev/null
            # Use atomic move for safety
            if mv "$temp_file" "$wt_settings" 2>/dev/null
                return 0
            else
                # Restore from backup if move failed
                cp "$backup_file" "$wt_settings" 2>/dev/null
                rm -f "$temp_file"
                return 1
            end
        else
            # Invalid JSON produced, cleanup and exit
            echo "✗ Windows Terminal: Failed to update theme (invalid JSON produced)" >&2
            rm -f "$temp_file"
            return 1
        end
    else
        # jq failed, cleanup and exit
        echo "✗ Windows Terminal: jq command failed" >&2
        rm -f "$temp_file"
        return 1
    end
    
    echo "✓ Windows Terminal: Theme updated to $wt_scheme_name" >&2
end
