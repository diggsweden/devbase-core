function __update_wt_detect_username --description "Detect Windows username"
    # Method 1: Try PowerShell (works in most cases)
    if test -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
        set -l win_user (/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command "Write-Host -NoNewline \$env:USERNAME" 2>/dev/null | tr -d '\r\n')
        if test -n "$win_user"
            echo $win_user
            return 0
        end
    end
    
    # Method 2: Fallback to cmd.exe
    if test -x /mnt/c/Windows/System32/cmd.exe
        set -l win_user (/mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
        if test -n "$win_user"
            echo $win_user
            return 0
        end
    end
    
    # Method 3: Fallback to finding real user directory in /mnt/c/Users
    if test -d /mnt/c/Users
        for user_dir in /mnt/c/Users/*
            set -l dir_name (basename "$user_dir")
            # Skip system directories
            if not string match -qr '^(Public|Default|All Users|Default User)$' "$dir_name"
                # Check if this user has a Windows Terminal settings file
                if test -f "$user_dir/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"; or test -f "$user_dir/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
                    echo $dir_name
                    return 0
                end
            end
        end
    end
    
    return 1
end

function __update_wt_find_settings_path --description "Find Windows Terminal settings.json path"
    set -l win_user $argv[1]
    set -l possible_paths \
        "/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json" \
        "/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
    
    for path in $possible_paths
        if test -f "$path"
            echo $path
            return 0
        end
    end
    
    return 1
end

function __update_wt_get_scheme_name --description "Get Windows Terminal scheme name for devbase theme"
    set -l devbase_theme $argv[1]
    switch $devbase_theme
        case everforest-dark
            echo "Everforest Dark Hard"
        case everforest-light
            echo "Everforest Light Med"
        case catppuccin-mocha
            echo "Catppuccin Mocha"
        case catppuccin-latte
            echo "Catppuccin Latte"
        case tokyonight-night
            echo "TokyoNight Night"
        case tokyonight-day
            echo "TokyoNight Day"
        case gruvbox-dark
            echo "Gruvbox Dark"
        case gruvbox-light
            echo "Gruvbox Light"
        case nord
            echo "Nord"
        case dracula
            echo "Dracula"
        case solarized-dark
            echo "Solarized Dark"
        case solarized-light
            echo "Solarized Light"
        case '*'
            echo "Everforest Dark Hard"
    end
end

function __update_wt_get_scheme_file --description "Get Windows Terminal scheme file for devbase theme"
    set -l devbase_theme $argv[1]
    switch $devbase_theme
        case everforest-dark
            echo "everforest-dark-hard.json"
        case everforest-light
            echo "everforest-light-med.json"
        case catppuccin-mocha
            echo "catppuccin-mocha.json"
        case catppuccin-latte
            echo "catppuccin-latte.json"
        case tokyonight-night
            echo "tokyonight-night.json"
        case tokyonight-day
            echo "tokyonight-day.json"
        case gruvbox-dark
            echo "gruvbox-dark.json"
        case gruvbox-light
            echo "gruvbox-light.json"
        case nord
            echo "nord.json"
        case dracula
            echo "dracula.json"
        case solarized-dark
            echo "solarized-dark.json"
        case solarized-light
            echo "solarized-light.json"
        case '*'
            echo "everforest-dark-hard.json"
    end
end

function __update_wt_find_theme_file --description "Find Windows Terminal theme file"
    set -l wt_scheme_file $argv[1]
    set -l possible_theme_locations \
        "$XDG_DATA_HOME/devbase/files/windows-terminal/$wt_scheme_file" \
        "$HOME/.local/share/devbase/files/windows-terminal/$wt_scheme_file"
    
    for path in $possible_theme_locations
        if test -f "$path"
            echo $path
            return 0
        end
    end
    
    return 1
end

function __update_wt_apply_scheme --description "Apply Windows Terminal color scheme"
    set -l wt_settings $argv[1]
    set -l wt_scheme_name $argv[2]
    set -l backup_file $argv[3]
    set -l temp_file (mktemp)
    
    if jq --arg scheme_name "$wt_scheme_name" '.profiles.defaults.colorScheme = $scheme_name' "$wt_settings" > "$temp_file" 2>/dev/null
        if test -s "$temp_file"; and jq empty "$temp_file" 2>/dev/null
            if mv "$temp_file" "$wt_settings" 2>/dev/null
                return 0
            else
                cp "$backup_file" "$wt_settings" 2>/dev/null
                rm -f "$temp_file"
                return 1
            end
        else
            echo "✗ Windows Terminal: Failed to update theme (invalid JSON produced)" >&2
            rm -f "$temp_file"
            return 1
        end
    else
        echo "✗ Windows Terminal: jq command failed" >&2
        rm -f "$temp_file"
        return 1
    end
end

function __update_wt_validate_environment --description "Validate WSL and prerequisites"
    if not uname -r | grep -qi microsoft
        return 1
    end
    
    if not type -q jq
        return 1
    end
    
    if test -z "$DEVBASE_THEME"
        return 1
    end
    
    return 0
end

function __update_wt_get_settings_and_backup --description "Find settings file and create backup"
    set -l win_user (__update_wt_detect_username)
    or return 1
    
    set -l wt_settings (__update_wt_find_settings_path $win_user)
    if test -z "$wt_settings"
        echo "✗ Windows Terminal: settings.json not found for user $win_user" >&2
        return 1
    end
    
    if not test -w "$wt_settings"
        return 1
    end
    
    set -l timestamp (date +%S.%H.%M.%y)
    set -l settings_dir (dirname "$wt_settings")
    set -l backup_file "$settings_dir/settings.$timestamp.json"
    if not cp "$wt_settings" "$backup_file" 2>/dev/null
        echo "✗ Windows Terminal: Failed to create backup" >&2
        return 1
    end
    
    echo "$wt_settings"
    echo "$backup_file"
    return 0
end

function __update_wt_prepare_theme_data --description "Get theme scheme name and validate theme file"
    set -l devbase_theme $argv[1]
    set -l wt_scheme_name (__update_wt_get_scheme_name $devbase_theme)
    set -l wt_scheme_file (__update_wt_get_scheme_file $devbase_theme)
    
    set -l theme_source (__update_wt_find_theme_file $wt_scheme_file)
    if test -z "$theme_source"
        echo "✗ Windows Terminal: Theme file not found for $devbase_theme" >&2
        echo "  Expected: $XDG_DATA_HOME/devbase/files/windows-terminal/$wt_scheme_file" >&2
        echo "  Note: Theme files are installed during devbase setup" >&2
        echo "  If missing, re-run setup.sh or check installation" >&2
        return 1
    end
    
    echo "$wt_scheme_name"
    return 0
end

function update-windows-terminal-theme --description "Update Windows Terminal color scheme (WSL only)"
    # Validate environment
    if not __update_wt_validate_environment
        return 0
    end
    
    # Get settings file and create backup
    set -l settings_data (__update_wt_get_settings_and_backup)
    or return 1
    
    set -l wt_settings (echo $settings_data | read -z | string split \n)[1]
    set -l backup_file (echo $settings_data | read -z | string split \n)[2]
    
    # Prepare theme data
    set -l wt_scheme_name (__update_wt_prepare_theme_data $DEVBASE_THEME)
    or return 1
    
    # Apply the color scheme
    __update_wt_apply_scheme "$wt_settings" "$wt_scheme_name" "$backup_file"
end
