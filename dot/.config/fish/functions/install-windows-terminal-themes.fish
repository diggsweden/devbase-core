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

function __install_wt_detect_username --description "Detect Windows username by scanning filesystem"
    if test -d /mnt/c/Users
        for user_dir in /mnt/c/Users/*
            set -l dir_name (basename "$user_dir")
            if not string match -qr '^(Public|Default|All Users|Default User|desktop\.ini)$' "$dir_name"
                for pkg_dir in $user_dir/AppData/Local/Packages/Microsoft.WindowsTerminal_*
                    if test -f "$pkg_dir/LocalState/settings.json"
                        echo "$dir_name"
                        return 0
                    end
                end
            end
        end
    end
    
    echo "✗ Windows Terminal: Could not detect Windows username" >&2
    return 1
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
    
    printf "["
    set -l first true
    for theme_file in catppuccin-latte.json catppuccin-mocha.json dracula.json everforest-dark-hard.json everforest-light-med.json gruvbox-dark.json gruvbox-light.json nord.json tokyonight-day.json tokyonight-night.json
        set -l theme_path "$theme_dir/$theme_file"
        if test -f "$theme_path"
            if test $first = false
                printf ","
            end
            command cat "$theme_path"
            set first false
        end
    end
    printf "]"
end

function __install_wt_inject_themes --description "Inject themes into settings.json using jq"
    set -l themes_json $argv[1]
    set -l wt_settings $argv[2]
    set -l backup_file $argv[3]
    set -l temp_file (mktemp)
    
    set -l jq_filter '
        .themes as $themes 
        | .settings 
        | del(.schemes[]? | select(.name | test(
            "Everforest (Dark Hard|Light Med)|Catppuccin (Mocha|Latte)|TokyoNight (Night|Day)|Gruvbox (Dark|Light)|Nord|Dracula"
        ))) 
        | .schemes += $themes
    '
    
    set -l settings_clean (mktemp)
    sed -E 's/,([[:space:]]*[}\]])/\1/g' "$wt_settings" > "$settings_clean"
    
    if not jq empty "$settings_clean" 2>/dev/null
        echo "✗ Windows Terminal: settings.json contains invalid JSON" >&2
        rm -f "$settings_clean"
        return 1
    end
    
    printf '%s' "$themes_json" | jq --slurpfile settings "$settings_clean" '{themes: ., settings: $settings[0]}' | jq "$jq_filter" > "$temp_file" 2>&1
    set -l jq_status $status
    rm -f "$settings_clean"
    
    if test $jq_status -ne 0
        echo "✗ Windows Terminal: jq command failed (status $jq_status)" >&2
        rm -f "$temp_file"
        return 1
    end
    
    if not test -s "$temp_file"
        echo "✗ Windows Terminal: jq produced empty output" >&2
        rm -f "$temp_file"
        return 1
    end
    
    if not jq empty "$temp_file" 2>/dev/null
        echo "✗ Windows Terminal: jq produced invalid JSON" >&2
        rm -f "$temp_file"
        return 1
    end
    
    if not mv "$temp_file" "$wt_settings" 2>/dev/null
        cp "$backup_file" "$wt_settings" 2>/dev/null
        rm -f "$temp_file"
        echo "✗ Windows Terminal: Failed to write settings.json" >&2
        return 1
    end
    
    return 0
end

function install-windows-terminal-themes --description "Install all DevBase themes to Windows Terminal (one-time setup)"
    if not __install_wt_validate_prerequisites
        return 0
    end
    
    set -l win_user (__install_wt_detect_username)
    or return 1
    
    set -l wt_settings (__install_wt_find_settings_file $win_user)
    or return 1
    
    set -l theme_dir (__install_wt_find_theme_directory)
    or return 1
    
    set -l backup_file (__install_wt_create_backup $wt_settings)
    or return 1
    
    set -l themes_json (__install_wt_build_themes_array $theme_dir | string collect)
    
    if __install_wt_inject_themes "$themes_json" $wt_settings $backup_file
        echo "✓ Windows Terminal: 10 DevBase themes installed (Solarized themes use built-in versions)" >&2
    else
        echo "✗ Windows Terminal: Failed to install themes" >&2
        return 1
    end
end
