function __devbase_update_nag_already_checked_today --description "Check if update check already ran today"
    set -l check_file $argv[1]
    set -l current_date $argv[2]
    
    if test -f "$check_file"
        set -l last_check (cat "$check_file")
        test "$last_check" = "$current_date"
    else
        return 1
    end
end

function __devbase_update_nag_get_installed_version --description "Extract installed version from version file"
    set -l version_file $argv[1]
    set -l info (cat "$version_file")
    set -l tag (printf "%s" "$info" | awk '{print $3}')
    test -z "$tag" && echo "v0.0.0" || echo "$tag"
end

function __devbase_update_nag_get_install_epoch --description "Get installation date as epoch timestamp"
    set -l version_file $argv[1]
    set -l info (cat "$version_file")
    set -l install_date (printf "%s" "$info" | cut -d' ' -f2)
    date -d "$install_date" +%s 2>/dev/null || echo 0
end

function __devbase_update_nag_is_old_enough --description "Check if at least 2 weeks passed since install"
    set -l install_epoch $argv[1]
    set -l current_epoch (date +%s)
    set -l two_weeks (math "14 * 24 * 60 * 60")
    set -l time_diff (math "$current_epoch - $install_epoch")
    test $time_diff -ge $two_weeks
end

function __devbase_update_nag_fetch_latest_version --description "Fetch latest version tag from GitHub"
    set -l repo_url "https://github.com/diggsweden/devbase-core.git"
    timeout 5 git ls-remote --tags $repo_url 2>/dev/null | \
        grep -oP 'refs/tags/v\K[0-9]+\.[0-9]+\.[0-9]+$' | \
        sort -V | tail -1 | \
        sed 's/^/v/'
end

function __devbase_update_nag_is_newer --description "Check if latest version is newer than installed"
    set -l installed $argv[1]
    set -l latest $argv[2]
    set -l sorted (printf '%s\n%s' "$installed" "$latest" | sort -V | head -n1)
    test "$sorted" = "$installed" -a "$installed" != "$latest"
end

function __devbase_update_nag_print_notification --description "Print update available notification"
    set -l installed_tag $argv[1]
    set -l latest_tag $argv[2]
    
    printf "\n"
    printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
    printf "%s⚠  UPDATE AVAILABLE: Dev-Quickstart %s is available!  ⚠%s\n" (set_color yellow) "$latest_tag" (set_color normal)
    printf "%s   Current version: %s%s\n" (set_color yellow) "$installed_tag" (set_color normal)
    printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
    printf "%s   To update, run:%s\n" (set_color yellow) (set_color normal)
    printf "%s   See README.adoc for installation instructions%s\n" (set_color yellow) (set_color normal)
    printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
    printf "\n"
end

function devbase-update-nag --description "Check for devbase updates and notify user (once per day)"
    set -l version_file "$HOME/.config/devbase/version"
    set -l check_file "$HOME/.config/devbase/daily_check_done"
    set -l current_date (date +%Y%m%d)
    
    # Skip if already checked today
    __devbase_update_nag_already_checked_today $check_file $current_date && return 0
    
    # Mark as checked today
    printf "%s\n" "$current_date" > "$check_file"
    
    # Skip if version file doesn't exist
    test -f "$version_file" || return 0
    
    # Get installed version and install date
    set -l installed_tag (__devbase_update_nag_get_installed_version $version_file)
    set -l install_epoch (__devbase_update_nag_get_install_epoch $version_file)
    
    # Skip if less than 2 weeks since installation
    __devbase_update_nag_is_old_enough $install_epoch || return 0
    
    # Fetch latest version
    set -l latest_tag (__devbase_update_nag_fetch_latest_version)
    test -z "$latest_tag" && return 0
    
    # Print notification if update available
    if __devbase_update_nag_is_newer $installed_tag $latest_tag
        __devbase_update_nag_print_notification $installed_tag $latest_tag
    end
end
