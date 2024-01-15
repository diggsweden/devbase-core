function install-windows-terminal-themes --description "Install all DevBase themes to Windows Terminal (one-time setup)"
    # Delegate to bash implementation for better compatibility across shells and su contexts
    set -l bash_script ""
    
    # Try to find the bash implementation
    if set -q XDG_DATA_HOME
        set bash_script "$XDG_DATA_HOME/devbase/libs/install-windows-terminal-themes.sh"
    else if test -f "$HOME/.local/share/devbase/libs/install-windows-terminal-themes.sh"
        set bash_script "$HOME/.local/share/devbase/libs/install-windows-terminal-themes.sh"
    end
    
    # If bash implementation exists, use it
    if test -f "$bash_script"
        bash -c "source '$bash_script' && install_windows_terminal_themes"
        return $status
    end
    
    # Fallback to fish implementation if bash version not found
    # Only run in WSL
    if not uname -r | grep -qi microsoft
        return 0
    end

    # Check if jq is available
    if not type -q jq
        echo "✗ Windows Terminal: jq not available" >&2
        return 1
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
        echo "✗ Windows Terminal: settings.json not writable" >&2
        return 1
    end

    # Find theme files directory
    set -l theme_dir ""
    set -l possible_theme_dirs \
        "$XDG_DATA_HOME/devbase/files/windows-terminal" \
        "$HOME/.local/share/devbase/files/windows-terminal"
    
    for dir in $possible_theme_dirs
        if test -d "$dir"
            set theme_dir "$dir"
            break
        end
    end
    
    # Exit if theme directory not found
    if test -z "$theme_dir"
        echo "✗ Windows Terminal: Theme files not found" >&2
        echo "  Expected: $XDG_DATA_HOME/devbase/files/windows-terminal/" >&2
        return 1
    end

    # Create timestamped backup
    set -l timestamp (date +%S.%H.%M.%y)
    set -l settings_dir (dirname "$wt_settings")
    set -l backup_file "$settings_dir/settings.$timestamp.json"
    if not cp "$wt_settings" "$backup_file" 2>/dev/null
        echo "✗ Windows Terminal: Failed to create backup" >&2
        return 1
    end

    # Load all theme JSON files
    set -l temp_file (mktemp)
    
    # Build jq command to inject all themes at once
    set -l jq_cmd 'del(.schemes[]? | select(.name | test("Everforest (Dark Hard|Light Med)|Catppuccin (Mocha|Latte)|TokyoNight (Night|Day)|Gruvbox (Dark|Light)")))'
    
    # Read each theme file and add to jq arguments
    set -l theme_files \
        "catppuccin-latte.json" \
        "catppuccin-mocha.json" \
        "everforest-dark-hard.json" \
        "everforest-light-med.json" \
        "gruvbox-dark.json" \
        "gruvbox-light.json" \
        "tokyonight-day.json" \
        "tokyonight-night.json"
    
    set -l themes_array "["
    set -l first true
    for theme_file in $theme_files
        set -l theme_path "$theme_dir/$theme_file"
        if test -f "$theme_path"
            if test $first = false
                set themes_array "$themes_array,"
            end
            set themes_array "$themes_array"(cat "$theme_path")
            set first false
        end
    end
    set themes_array "$themes_array]"
    
    # Inject all themes into settings.json
    if echo "$themes_array" | jq -s '.[0] as $themes | input | del(.schemes[]? | select(.name | test("Everforest (Dark Hard|Light Med)|Catppuccin (Mocha|Latte)|TokyoNight (Night|Day)|Gruvbox (Dark|Light)"))) | .schemes += $themes' - "$wt_settings" > "$temp_file" 2>/dev/null
        # Validate output is valid JSON and non-empty
        if test -s "$temp_file"; and jq empty "$temp_file" 2>/dev/null
            # Use atomic move for safety
            if mv "$temp_file" "$wt_settings" 2>/dev/null
                echo "✓ Windows Terminal: All 8 DevBase themes installed" >&2
                return 0
            else
                # Restore from backup if move failed
                cp "$backup_file" "$wt_settings" 2>/dev/null
                rm -f "$temp_file"
                echo "✗ Windows Terminal: Failed to update settings.json" >&2
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
end
