function devbase-update-nag
    set VERSION_FILE "$HOME/.config/devbase/version"
    set DAILY_CHECK_FILE "$HOME/.config/devbase/daily_check_done"
    
    # Get current date
    set CURRENT_DATE (date +%Y%m%d)
    
    # Check if we already ran today
    if test -f "$DAILY_CHECK_FILE"
        set LAST_CHECK_DATE (cat "$DAILY_CHECK_FILE")
        test "$LAST_CHECK_DATE" = "$CURRENT_DATE" && return 0
    end
    
    # Mark that we're checking today
    printf "%s\n" "$CURRENT_DATE" > "$DAILY_CHECK_FILE"
    
    # Check if version file exists
    test -f "$VERSION_FILE" || return 0
    
    # Get current epoch time
    set CURRENT_EPOCH (date +%s)
    
    # Get installed version info
    set INSTALLED_INFO (cat "$VERSION_FILE")
    set INSTALLED_TAG (printf "%s" "$INSTALLED_INFO" | awk '{print $3}')
    test -z "$INSTALLED_TAG" && set INSTALLED_TAG "v0.0.0"
    
    set INSTALL_DATE (printf "%s" "$INSTALLED_INFO" | cut -d' ' -f2)
    set INSTALL_EPOCH (date -d "$INSTALL_DATE" +%s 2>/dev/null || echo 0)
    
    # Check if at least 2 weeks have passed since installation
    set TWO_WEEKS_IN_SECONDS (math "14 * 24 * 60 * 60")
    set TIME_SINCE_INSTALL (math "$CURRENT_EPOCH - $INSTALL_EPOCH")
    
    # Exit if less than 2 weeks since installation
    test $TIME_SINCE_INSTALL -lt $TWO_WEEKS_IN_SECONDS && return 0
    
    # Check for updates (always fetch fresh)
    set -l repo_url "https://github.com/diggsweden/devbase-core.git"
    set LATEST_TAG (timeout 5 git ls-remote --tags $repo_url 2>/dev/null | \
        grep -oP 'refs/tags/v\K[0-9]+\.[0-9]+\.[0-9]+$' | \
        sort -V | tail -1 | \
        sed 's/^/v/')
    
    # If we couldn't get the latest tag, exit
    test -z "$LATEST_TAG" && return 0
    
    # Compare versions using sort -V
    set SORTED (printf '%s\n%s' "$INSTALLED_TAG" "$LATEST_TAG" | sort -V | head -n1)
    if test "$SORTED" = "$INSTALLED_TAG" -a "$INSTALLED_TAG" != "$LATEST_TAG"
        printf "\n"
        printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
        printf "%s⚠  UPDATE AVAILABLE: Dev-Quickstart %s is available!  ⚠%s\n" (set_color yellow) "$LATEST_TAG" (set_color normal)
        printf "%s   Current version: %s%s\n" (set_color yellow) "$INSTALLED_TAG" (set_color normal)
        printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
        printf "%s   To update, run:%s\n" (set_color yellow) (set_color normal)
        printf "%s   See README.adoc for installation instructions%s\n" (set_color yellow) (set_color normal)
        printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
        printf "\n"
    end
end
