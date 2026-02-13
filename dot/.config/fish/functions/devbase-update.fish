# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# devbase-update - Smart update for devbase-core and custom config
# Checks for updates and re-runs setup.sh to apply changes
# Version info is read directly from the persisted git repos

set -g __devbase_core_dir "$HOME/.local/share/devbase/core"
set -g __devbase_custom_dir "$HOME/.local/share/devbase/custom"
set -g __devbase_snooze_file "$HOME/.config/devbase/update-snooze"

function __devbase_update_print_info
    printf "%sⓘ%s %s\n" (set_color cyan) (set_color normal) "$argv[1]"
end

function __devbase_update_print_success
    printf "%s✓%s %s\n" (set_color green) (set_color normal) "$argv[1]"
end

function __devbase_update_print_warning
    printf "%s‼%s %s\n" (set_color yellow) (set_color normal) "$argv[1]"
end

function __devbase_update_print_error
    printf "%s✗%s %s\n" (set_color red) (set_color normal) "$argv[1]" >&2
end

function __devbase_update_is_snoozed
    if test -f "$__devbase_snooze_file"
        set -l now (date +%s)
        set -l until (cat "$__devbase_snooze_file" 2>/dev/null)
        if string match -qr '^[0-9]+$' -- "$until"; and test "$now" -lt "$until"
            return 0
        end
    end
    return 1
end

function __devbase_update_set_snooze --description "Snooze update prompts for N hours"
    set -l hours "$argv[1]"
    if not string match -qr '^[0-9]+$' -- "$hours"
        __devbase_update_print_error "Invalid hours: $hours"
        return 1
    end

    set -l now (date +%s)
    set -l until (math "$now + ($hours * 3600)")
    mkdir -p (dirname "$__devbase_snooze_file")
    echo "$until" >"$__devbase_snooze_file"
    __devbase_update_print_success "Updates snoozed for $hours hour(s)"
    return 0
end

function __devbase_update_clear_snooze
    if test -f "$__devbase_snooze_file"
        rm -f "$__devbase_snooze_file"
        __devbase_update_print_success "Update snooze cleared"
    end
    return 0
end

function __devbase_update_get_latest_tag --description "Get latest tag from remote, supporting semver tags"
    # Supports SemVer tags: v1.0.0, v1.0.0-beta.N, v1.0.0-rc.N
    # Priority: release (vX.Y.Z) > rc > beta
    # Uses version sort (sort -V) for proper ordering
    set -l remote_url $argv[1]

    # Get all tags from remote
    set -l all_tags (git ls-remote --tags "$remote_url" 2>/dev/null | \
        string match -rg 'refs/tags/([^\^]+)$' | \
        string match -rv '\^{}')

    if test -z "$all_tags"
        return 1
    end

    # Check for release tags (vX.Y.Z without prerelease suffix) - highest priority
    set -l release_tags (printf '%s\n' $all_tags | string match -rg '^(v[0-9]+\.[0-9]+\.[0-9]+)$')
    if test -n "$release_tags"
        printf '%s\n' $release_tags | sort -V | tail -1
        return 0
    end

    # Check for rc tags (vX.Y.Z-rc.N)
    set -l rc_tags (printf '%s\n' $all_tags | string match -r '^v[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+$')
    if test -n "$rc_tags"
        printf '%s\n' $rc_tags | sort -V | tail -1
        return 0
    end

    # Check for beta tags (vX.Y.Z-beta.N)
    set -l beta_tags (printf '%s\n' $all_tags | string match -r '^v[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$')
    if test -n "$beta_tags"
        printf '%s\n' $beta_tags | sort -V | tail -1
        return 0
    end

    # No recognized tags found
    return 1
end

function __devbase_update_get_core_info --description "Get core version info from git repo"
    if not test -d "$__devbase_core_dir/.git"
        return 1
    end
    set -g CORE_TAG (git -C "$__devbase_core_dir" describe --tags --abbrev=0 2>/dev/null; or echo "unknown")
    set -g CORE_SHA (git -C "$__devbase_core_dir" rev-parse --short HEAD 2>/dev/null; or echo "unknown")
    set -g CORE_REMOTE (git -C "$__devbase_core_dir" remote get-url origin 2>/dev/null; or echo "")
    return 0
end

function __devbase_update_get_custom_info --description "Get custom config info from git repo"
    set -g CUSTOM_SHA ""
    set -g CUSTOM_REMOTE ""
    if test -d "$__devbase_custom_dir/.git"
        set -g CUSTOM_SHA (git -C "$__devbase_custom_dir" rev-parse --short HEAD 2>/dev/null; or echo "unknown")
        set -g CUSTOM_REMOTE (git -C "$__devbase_custom_dir" remote get-url origin 2>/dev/null; or echo "")
    end
end

function __devbase_update_check_core --description "Check if core update is available"
    # Returns:
    #   0 with output = update available
    #   0 with no output = no update (already current)
    #   1 = check failed (network error, repo not found, etc.)
    
    if not test -d "$__devbase_core_dir/.git"
        __devbase_update_print_warning "Core repo not found at $__devbase_core_dir"
        return 1
    end

    __devbase_update_get_core_info; or return 1

    if test -z "$CORE_REMOTE"
        __devbase_update_print_warning "Could not determine core remote URL"
        return 1
    end

    # Fetch tags (shallow)
    if not git -C "$__devbase_core_dir" fetch --depth 1 --tags --quiet 2>/dev/null
        return 1
    end

    # Get latest tag from remote (supports vX.Y.Z, vX.Y.Z-beta.N, vX.Y.Z-rc.N)
    set -l latest (__devbase_update_get_latest_tag "$CORE_REMOTE")

    if test -z "$latest"
        return 1
    end

    if test "$latest" != "$CORE_TAG"
        echo "devbase-core: $CORE_TAG → $latest"
    end
    # Return 0 whether update available or not - we successfully checked
    return 0
end

function __devbase_update_check_custom --description "Check if custom config update is available"
    # Returns:
    #   0 with output = update available
    #   0 with no output = no update (already current)
    #   1 = check failed (network error, repo not found, etc.)
    
    test -d "$__devbase_custom_dir/.git"; or return 1

    __devbase_update_get_custom_info
    test -n "$CUSTOM_REMOTE"; or return 1

    # Fetch latest (shallow)
    if not git -C "$__devbase_custom_dir" fetch --depth 1 --quiet 2>/dev/null
        return 1
    end

    # Get latest SHA from remote
    set -l latest (git -C "$__devbase_custom_dir" rev-parse --short origin/HEAD 2>/dev/null; \
        or git -C "$__devbase_custom_dir" rev-parse --short origin/main 2>/dev/null; \
        or echo "")

    if test -z "$latest"
        return 1
    end

    if test "$latest" != "$CUSTOM_SHA"
        echo "devbase-custom-config: $CUSTOM_SHA → $latest"
    end
    # Return 0 whether update available or not - we successfully checked
    return 0
end

function __devbase_update_core --description "Update core to latest version or ref"
    set -l ref "$argv[1]"
    set -l target ""

    if test -n "$ref"
        set target "$ref"
    else
        # Get latest tag (supports vX.Y.Z, alpha-N, beta-N, rc-N)
        set target (__devbase_update_get_latest_tag "$CORE_REMOTE")
    end

    __devbase_update_print_info "Updating core to $target..."

    # Fetch the target (branch or tag)
    if not git -C "$__devbase_core_dir" fetch --depth 1 origin "$target" --quiet 2>/dev/null
        git -C "$__devbase_core_dir" fetch --depth 1 --tags --quiet
    end

    # Stash any local changes
    git -C "$__devbase_core_dir" stash --quiet 2>/dev/null; or true

    set -l checkout_target "$target"

    # Ensure the ref exists locally after fetch (branch refs aren't created by default)
    if not git -C "$__devbase_core_dir" cat-file -e "$checkout_target^{commit}" 2>/dev/null
        if string match -qr '^[0-9a-f]{40}$' -- "$target"
            __devbase_update_print_error "SHA refs are not supported: $target"
            __devbase_update_print_info "Use a branch or tag name instead"
            return 1
        end

        if git -C "$__devbase_core_dir" fetch --depth 1 origin "+refs/heads/*:refs/remotes/origin/*" --quiet 2>/dev/null
            set checkout_target "origin/$target"
        else if git -C "$__devbase_core_dir" fetch --depth 1 origin "+refs/tags/$target:refs/tags/$target" --quiet 2>/dev/null
            set checkout_target "$target"
        end

        if not git -C "$__devbase_core_dir" cat-file -e "$checkout_target^{commit}" 2>/dev/null
            __devbase_update_print_error "Ref not found in core repo: $target"
            __devbase_update_print_info "Ensure the ref exists on the remote (branch/tag) and try again"
            return 1
        end
    end

    # Checkout the target ref
    if not git -C "$__devbase_core_dir" checkout "$checkout_target" --quiet
        __devbase_update_print_error "Failed to checkout core ref: $target"
        return 1
    end

    # Trust mise config to avoid trust prompt during setup
    if command -q mise; and test -f "$__devbase_core_dir/.mise.toml"
        mise trust "$__devbase_core_dir/.mise.toml"
    end

    __devbase_update_print_success "Core updated to $target"
end

function __devbase_update_custom --description "Update custom config to latest"
    __devbase_update_print_info "Updating custom config..."

    # Fetch latest (shallow)
    git -C "$__devbase_custom_dir" fetch --depth 1 --quiet

    # Stash any local changes
    git -C "$__devbase_custom_dir" stash --quiet 2>/dev/null; or true

    # Reset to remote HEAD
    git -C "$__devbase_custom_dir" reset --hard origin/HEAD --quiet 2>/dev/null; \
        or git -C "$__devbase_custom_dir" reset --hard origin/main --quiet

    set -l new_sha (git -C "$__devbase_custom_dir" rev-parse --short HEAD)
    __devbase_update_print_success "Custom config updated to $new_sha"
end

function __devbase_update_check_only --description "Run the update check only (no prompt, no update)"
    if not test -d "$__devbase_core_dir/.git"
        # Not installed yet or not via new system
        return 1
    end

    set -l core_update ""
    set -l custom_update ""

    set core_update (__devbase_update_check_core 2>/dev/null); or true
    set custom_update (__devbase_update_check_custom 2>/dev/null); or true

    if test -n "$core_update"
        echo "$core_update"
    end

    if test -n "$custom_update"
        echo "$custom_update"
    end

    # Return 0 if any update available
    test -n "$core_update" -o -n "$custom_update"
end

function __devbase_update_show_version --description "Show current version info"
    if not __devbase_update_get_core_info
        __devbase_update_print_error "Core repo not found at $__devbase_core_dir"
        __devbase_update_print_info "Run devbase setup.sh first to install"
        return 1
    end

    __devbase_update_get_custom_info

    echo "DevBase Version Info"
    echo "===================="
    echo "Core:"
    echo "  Tag:    $CORE_TAG"
    echo "  SHA:    $CORE_SHA"
    echo "  Remote: $CORE_REMOTE"
    echo "  Path:   $__devbase_core_dir"

    if test -n "$CUSTOM_REMOTE"
        echo ""
        echo "Custom Config:"
        echo "  SHA:    $CUSTOM_SHA"
        echo "  Remote: $CUSTOM_REMOTE"
        echo "  Path:   $__devbase_custom_dir"
    end
end

function __devbase_update_do_update --description "Perform the update"
    set -l target_ref "$argv[1]"
    set -l force_ref false
    if test -n "$target_ref"
        set force_ref true
    end
    if not __devbase_update_get_core_info
        __devbase_update_print_error "Core repo not found at $__devbase_core_dir"
        __devbase_update_print_info "Run devbase setup.sh first to install"
        return 1
    end

    __devbase_update_get_custom_info

    set -l update_core false
    set -l update_custom false
    set -l core_msg ""
    set -l custom_msg ""

    set -l core_check_failed false
    set -l custom_check_failed false

    if test "$force_ref" = true
        set update_core true
        set core_msg "devbase-core: $CORE_TAG → $target_ref"
    else
        # Check for core updates
        # Return 0 = check succeeded, output = update available
        # Return 1 = check failed (network error, etc.)
        if set core_msg (__devbase_update_check_core)
            if test -n "$core_msg"
                set update_core true
            end
        else
            set core_check_failed true
        end
    end

    # Check for custom updates
    if test "$force_ref" = false
        if test -d "$__devbase_custom_dir/.git"
            if set custom_msg (__devbase_update_check_custom)
                if test -n "$custom_msg"
                    set update_custom true
                end
            else
                set custom_check_failed true
            end
        end
    end

    if test "$update_core" = false -a "$update_custom" = false
        if test "$core_check_failed" = true -o "$custom_check_failed" = true
            printf "%sOffline: Could not check for updates%s\n" (set_color yellow) (set_color normal)
            return 0
        end
        __devbase_update_print_success "Already up to date (core: $CORE_TAG)"
        return 0
    end

    # Show what's available
    echo ""
    if test "$force_ref" = true
        echo "Requested core update:"
    else
        echo "Updates available:"
    end
    test -n "$core_msg"; and echo "  • $core_msg"
    test -n "$custom_msg"; and echo "  • $custom_msg"
    echo ""

    # Prompt user (unless non-interactive or ref forced)
    if test "$force_ref" = true
        __devbase_update_print_info "Updating core to requested ref"
    else if status --is-interactive
        read -l -P "Proceed with update? [y/N] " response
        echo
        if not string match -qi 'y' -- $response
            __devbase_update_print_info "Update cancelled"
            return 0
        end
    else
        __devbase_update_print_info "Non-interactive mode - proceeding with update"
    end

    # Perform updates
    if test "$update_core" = true
        set -gx DEVBASE_CORE_REF "$target_ref"
        __devbase_update_core "$target_ref"
        or return 1
    end

    if test "$update_custom" = true
        __devbase_update_custom
    end

    # Re-run installation to apply changes
    echo ""
    __devbase_update_print_info "Re-running setup to apply changes..."
    echo ""

    if test -f "$__devbase_core_dir/setup.sh"
        bash "$__devbase_core_dir/setup.sh"
    else
        __devbase_update_print_error "setup.sh not found in $__devbase_core_dir"
        return 1
    end
end

function __devbase_update_usage --description "Show usage information"
    echo "Usage: devbase-update [OPTION]"
    echo ""
    echo "Check for and apply DevBase updates."
    echo ""
    echo "Options:"
    echo "  --ref <ref>  Update core to a specific git ref (branch, tag, or SHA)"
    echo "  --snooze <h> Snooze update prompts for N hours"
    echo "  --unsnooze   Clear update snooze"
    echo "  --check     Check for updates without prompting (for shell integration)"
    echo "  --version   Show current version information"
    echo "  --help      Show this help message"
    echo ""
    echo "Without options, checks for updates and prompts to apply them."
    echo ""
    echo "Version info is read directly from the git repos at:"
    echo "  Core:   $__devbase_core_dir"
    echo "  Custom: $__devbase_custom_dir"
end

function devbase-update --description "Check for and apply DevBase updates"
    set -l ref ""
    set -l mode ""
    set -l snooze_hours ""

    for arg in $argv
        switch $arg
            case --ref
                if test -n "$ref"
                    continue
                end
                set mode "ref"
            case --snooze
                set mode "snooze"
            case --check
                set mode "check"
            case --version -v
                set mode "version"
            case --unsnooze
                set mode "unsnooze"
            case --help -h
                set mode "help"
            case '*'
                if string match -qr '^--ref=' -- $arg
                    set ref (string replace -r '^--ref=' '' -- $arg)
                    set mode "ref"
                else if string match -qr '^--snooze=' -- $arg
                    set snooze_hours (string replace -r '^--snooze=' '' -- $arg)
                    set mode "snooze"
                else if test "$mode" = "ref" -a -z "$ref"
                    set ref "$arg"
                else if test "$mode" = "snooze" -a -z "$snooze_hours"
                    set snooze_hours "$arg"
                else
                    __devbase_update_print_error "Unknown option: $arg"
                    __devbase_update_usage
                    return 1
                end
        end
    end

    if test "$mode" = "ref"
        if test -z "$ref"
            __devbase_update_print_error "Missing value for --ref"
            __devbase_update_usage
            return 1
        end
        __devbase_update_do_update "$ref"
        return $status
    end

    if test "$mode" = "snooze"
        if test -z "$snooze_hours"
            __devbase_update_print_error "Missing value for --snooze"
            __devbase_update_usage
            return 1
        end
        __devbase_update_set_snooze "$snooze_hours"
        return $status
    end

    if test "$mode" = "unsnooze"
        __devbase_update_clear_snooze
        return $status
    end

    if test "$mode" = "check"
        __devbase_update_check_only
        return $status
    end

    if test "$mode" = "version"
        __devbase_update_show_version
        return $status
    end

    if test "$mode" = "help"
        __devbase_update_usage
        return 0
    end

    if __devbase_update_is_snoozed
        return 0
    end

    __devbase_update_do_update
end
