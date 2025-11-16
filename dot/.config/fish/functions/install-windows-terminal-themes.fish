function __install_wt_try_bash_implementation --description "Try to use bash implementation if available"
    set -l bash_script ""
    
    if set -q XDG_DATA_HOME
        set bash_script "$XDG_DATA_HOME/devbase/libs/install-windows-terminal-themes.sh"
    else if test -f "$HOME/.local/share/devbase/libs/install-windows-terminal-themes.sh"
        set bash_script "$HOME/.local/share/devbase/libs/install-windows-terminal-themes.sh"
    end
    
    if test -f "$bash_script"
        bash -c "source '$bash_script' && install_windows_terminal_themes"
        return $status
    end
    
    return 1
end

function __install_wt_validate_prerequisites --description "Validate WSL and jq are available"
    if not uname -r | grep -qi microsoft
        return 1
    end
    
    if not type -q jq
        echo "✗ Windows Terminal: jq not available" >&2
        return 1
    end
    
    return 0
end

function __install_wt_detect_username --description "Detect Windows username using multiple methods"
    set -l win_user ""
    
    # Method 1: Try PowerShell
    if test -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
        set win_user (/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command "Write-Host -NoNewline \$env:USERNAME" 2>/dev/null | tr -d '\r\n')
    end
    
    # Method 2: Fallback to cmd.exe
    if test -z "$win_user"; and test -x /mnt/c/Windows/System32/cmd.exe
        set win_user (/mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
    end
    
    # Method 3: Fallback to filesystem scanning
    if test -z "$win_user"; and test -d /mnt/c/Users
        for user_dir in /mnt/c/Users/*
            set -l dir_name (basename "$user_dir")
            if not string match -qr '^(Public|Default|All Users|Default User)$' "$dir_name"
                # Check for any Windows Terminal package
                for pkg_dir in $user_dir/AppData/Local/Packages/Microsoft.WindowsTerminal_*
                    if test -f "$pkg_dir/LocalState/settings.json"
                        set win_user "$dir_name"
                        break
                    end
                end
                if test -n "$win_user"
                    break
                end
            end
        end
    end
    
    if test -z "$win_user"
        echo "✗ Windows Terminal: Could not detect Windows username" >&2
        return 1
    end
    
    echo $win_user
    return 0
end

function __install_wt_find_settings_file --description "Find Windows Terminal settings.json path"
    set -l win_user $argv[1]
    set -l packages_dir "/mnt/c/Users/$win_user/AppData/Local/Packages"
    
    # Find the Windows Terminal package directory (name can vary)
    set -l wt_settings ""
    if test -d "$packages_dir"
        for pkg_dir in $packages_dir/Microsoft.WindowsTerminal_*
            if test -f "$pkg_dir/LocalState/settings.json"
                set wt_settings "$pkg_dir/LocalState/settings.json"
                break
            end
        end
    end
    
    if test -z "$wt_settings"
        echo "✗ Windows Terminal: settings.json not found for user $win_user" >&2
        return 1
    end
    
    if not test -w "$wt_settings"
        echo "✗ Windows Terminal: settings.json not writable" >&2
        return 1
    end
    
    echo $wt_settings
    return 0
end

function __install_wt_find_theme_directory --description "Find theme files directory"
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
    
    if test -z "$theme_dir"
        echo "✗ Windows Terminal: Theme files not found" >&2
        echo "  Expected: $XDG_DATA_HOME/devbase/files/windows-terminal/" >&2
        return 1
    end
    
    echo $theme_dir
    return 0
end

function __install_wt_create_backup --description "Create timestamped backup of settings.json"
    set -l wt_settings $argv[1]
    set -l timestamp (date +%S.%H.%M.%y)
    set -l settings_dir (dirname "$wt_settings")
    set -l backup_file "$settings_dir/settings.$timestamp.json"
    
    if not cp "$wt_settings" "$backup_file" 2>/dev/null
        echo "✗ Windows Terminal: Failed to create backup" >&2
        return 1
    end
    
    echo $backup_file
    return 0
end

function __install_wt_build_themes_array --description "Build JSON array from theme files"
    set -l theme_dir $argv[1]
    
    # Skip solarized themes since Windows Terminal has them built-in
    set -l theme_files \
        "catppuccin-latte.json" \
        "catppuccin-mocha.json" \
        "dracula.json" \
        "everforest-dark-hard.json" \
        "everforest-light-med.json" \
        "gruvbox-dark.json" \
        "gruvbox-light.json" \
        "nord.json" \
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
    
    echo $themes_array
end

function __install_wt_inject_themes --description "Inject themes into settings.json using jq"
    set -l themes_array $argv[1]
    set -l wt_settings $argv[2]
    set -l backup_file $argv[3]
    set -l temp_file (mktemp)
    
    # jq filter: Remove old DevBase themes (except Solarized), then add new ones
    # .[0] = themes array from stdin, .[1] = settings.json file (both slurped by -s)
    # We don't remove or add Solarized themes since they're built-in
    set -l jq_filter '
        .[0] as $themes 
        | .[1] 
        | del(.schemes[]? | select(.name | test(
            "Everforest (Dark Hard|Light Med)|Catppuccin (Mocha|Latte)|TokyoNight (Night|Day)|Gruvbox (Dark|Light)|Nord|Dracula"
        ))) 
        | .schemes += $themes
    '
    
    if echo "$themes_array" | jq -s "$jq_filter" - "$wt_settings" > "$temp_file" 2>/dev/null
        if test -s "$temp_file"; and jq empty "$temp_file" 2>/dev/null
            if mv "$temp_file" "$wt_settings" 2>/dev/null
                return 0
            else
                cp "$backup_file" "$wt_settings" 2>/dev/null
                rm -f "$temp_file"
                echo "✗ Windows Terminal: Failed to update settings.json" >&2
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

function install-windows-terminal-themes --description "Install all DevBase themes to Windows Terminal (one-time setup)"
    # Try bash implementation first
    if __install_wt_try_bash_implementation
        return $status
    end
    
    # Validate prerequisites
    if not __install_wt_validate_prerequisites
        return 0
    end
    
    # Detect Windows username
    set -l win_user (__install_wt_detect_username)
    or return 1
    
    # Find settings file
    set -l wt_settings (__install_wt_find_settings_file $win_user)
    or return 1
    
    # Find theme directory
    set -l theme_dir (__install_wt_find_theme_directory)
    or return 1
    
    # Create backup
    set -l backup_file (__install_wt_create_backup $wt_settings)
    or return 1
    
    # Build themes array
    set -l themes_array (__install_wt_build_themes_array $theme_dir)
    
    # Inject themes
    if __install_wt_inject_themes $themes_array $wt_settings $backup_file
        echo "✓ Windows Terminal: 10 DevBase themes installed (Solarized themes use built-in versions)" >&2
    else
        echo "✗ Windows Terminal: Failed to install themes" >&2
        return 1
    end
end
