# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# devbase-update - Smart update for devbase-core and custom config
# Checks for updates and re-runs setup.sh to apply changes
# Version info is read directly from the persisted git repos

function __devbase_update_config_home --description "Get XDG config home"
    if set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"
        echo "$XDG_CONFIG_HOME"
    else
        echo "$HOME/.config"
    end
end

set -g __devbase_core_dir "$HOME/.local/share/devbase/core"
set -g __devbase_custom_dir "$HOME/.local/share/devbase/custom"
set -g __devbase_snooze_file (__devbase_update_config_home)/devbase/update-snooze

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

function __devbase_update_print_check_error --description "Print why an update check failed"
    # argv[1] = summary, argv[2..] = detail lines
    # Silenced via a flag: fish does not apply a caller's 2>/dev/null to
    # output from nested command substitutions
    set -q __devbase_update_quiet; and return 0
    __devbase_update_print_warning "$argv[1]" >&2
    for line in $argv[2..-1]
        printf "    %s\n" "$line" >&2
    end
end

set -g __devbase_update_net_timeout 30
# Same retry policy as retry_command in libs/utils.sh: 3 attempts, 5s doubling
set -g __devbase_update_net_attempts 3
set -g __devbase_update_net_retry_delay 5

function __devbase_update_net_transient --description "True when a failed network git command is worth retrying"
    # argv[1] = exit status, argv[2..] = git output (LC_ALL=C)
    test "$argv[1]" = 124; and return 0
    string match -qi -r 'could not resolve host|connection (timed out|reset|refused|closed)|network is unreachable|operation timed out|remote end hung up|early eof|unexpected disconnect|temporary failure in name resolution' -- $argv[2..-1]
end

function __devbase_update_git_net --description "Run a network git command that fails instead of prompting or hanging"
    # Leaves git's combined output in $__devbase_update_net_output and returns
    # git's status, so retry notices on stderr reach the user uncaptured.
    # Fail instead of waiting for a passphrase, and give up on unreachable hosts.
    # Respect an SSH command the user configured.
    if not set -q GIT_SSH_COMMAND; and not git config --get core.sshCommand >/dev/null
        set -fx GIT_SSH_COMMAND "ssh -o BatchMode=yes -o ConnectTimeout=10 -o VisualHostKey=no"
    end
    set -fx GIT_TERMINAL_PROMPT 0
    # English messages, so failures can be classified
    set -fx LC_ALL C
    # Retry timeouts and dropped connections, never an auth failure or a
    # missing ref. The silent shell-start check does not retry: it would
    # hold up a new terminal.
    set -l attempts $__devbase_update_net_attempts
    set -q __devbase_update_quiet; and set attempts 1
    set -l attempt 1
    while true
        set -g __devbase_update_net_output (timeout $__devbase_update_net_timeout git $argv 2>&1)
        set -l rc $status
        set -g __devbase_update_net_last_attempts $attempt
        if test $rc -eq 0; or test $attempt -ge $attempts; or not __devbase_update_net_transient $rc $__devbase_update_net_output
            return $rc
        end
        set -l delay (math "$__devbase_update_net_retry_delay * 2 ^ ($attempt - 1)")
        __devbase_update_print_warning "Attempt $attempt/$attempts failed, retrying in {$delay}s..." >&2
        sleep $delay
        set attempt (math $attempt + 1)
    end
end

function __devbase_update_print_net_error --description "Explain a failed network git command"
    # argv[1] = summary, argv[2] = exit status, argv[3] = remote, argv[4..] = git output
    set -l output (string match -rv '^\s*$' -- $argv[4..-1])
    set -l details $output[1..3]
    if test "$argv[2]" = 124
        set details "Timed out after $__devbase_update_net_timeout seconds"
    end
    if set -q __devbase_update_net_last_attempts; and test "$__devbase_update_net_last_attempts" -gt 1
        set -a details "Gave up after $__devbase_update_net_last_attempts attempts"
    end

    # SSH auth failures mostly come from ssh-agent, so say what state it is in.
    # ssh-add -l exits 2 when no agent is reachable, 1 when it holds no keys.
    if string match -q '*Permission denied (publickey*' -- $output
        set -l host (string replace -r '^(ssh://)?([^/:]+).*' '$2' -- "$argv[3]")
        ssh-add -l >/dev/null 2>&1
        switch $status
            case 2
                set -a details "→ ssh-agent is not running or not reachable (SSH_AUTH_SOCK=$SSH_AUTH_SOCK)"
            case 1
                set -a details "→ ssh-agent has no keys loaded, add yours with: ssh-add ~/.ssh/<key>"
            case '*'
                set -a details "→ $host accepted none of the keys in ssh-agent, check: ssh-add -l; ssh -T $host"
        end
    end

    __devbase_update_print_check_error "$argv[1]" $details
end

# __devbase_update_is_snoozed lives in its own file so the shell-start check can
# autoload it; load it here too for callers that source this file directly.
functions -q __devbase_update_is_snoozed; or source (dirname (status current-filename))/__devbase_update_is_snoozed.fish

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

    # Get all tags from remote; on failure, print git's reason to stderr
    __devbase_update_git_net ls-remote --tags "$remote_url"
    set -l rc $status
    set -l output $__devbase_update_net_output
    if test $rc -ne 0
        __devbase_update_print_net_error "Could not list tags from $remote_url" $rc "$remote_url" $output
        return 1
    end

    set -l all_tags (printf '%s\n' $output | string match -rg 'refs/tags/([^\^]+)$')

    if test -z "$all_tags"
        __devbase_update_print_check_error "No tags found at $remote_url"
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

    __devbase_update_print_check_error "No release tags (vX.Y.Z, -rc.N, -beta.N) found at $remote_url"
    return 1
end

function __devbase_update_get_core_info --description "Get core version info from git repo"
    if not test -d "$__devbase_core_dir/.git"
        return 1
    end
    set -g CORE_SHA (git -C "$__devbase_core_dir" rev-parse --short HEAD 2>/dev/null; or echo "unknown")
    # A core installed from a branch has no tag; name the commit instead
    set -g CORE_TAG (git -C "$__devbase_core_dir" describe --tags --exact-match 2>/dev/null; or echo "untagged $CORE_SHA")
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

    # Ask the remote directly instead of fetching: the check must not depend
    # on local tag state (a tag moved upstream makes `fetch --tags` fail)
    set -l latest (__devbase_update_get_latest_tag "$CORE_REMOTE")

    if test -z "$latest"
        return 1
    end
    # The update reuses this instead of asking the remote a second time
    set -g __devbase_update_latest_tag "$latest"

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
    __devbase_update_git_net -C "$__devbase_custom_dir" fetch --depth 1 --quiet
    set -l rc $status
    set -l fetch_output $__devbase_update_net_output
    if test $rc -ne 0
        __devbase_update_print_net_error "Could not fetch custom config from $CUSTOM_REMOTE" $rc "$CUSTOM_REMOTE" $fetch_output
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
    else if set -q __devbase_update_latest_tag; and test -n "$__devbase_update_latest_tag"
        # Found by the update check a moment ago
        set target "$__devbase_update_latest_tag"
    else
        # Get latest tag (supports vX.Y.Z, alpha-N, beta-N, rc-N)
        set target (__devbase_update_get_latest_tag "$CORE_REMOTE")
    end
    if test -z "$target"
        __devbase_update_print_error "Could not determine the release to update to"
        return 1
    end
    if string match -qr '^[0-9a-f]{7,40}$' -- "$target"
        __devbase_update_print_error "SHA refs are not supported: $target"
        __devbase_update_print_info "Use a branch or tag name instead"
        return 1
    end

    __devbase_update_print_info "Updating core to $target..."

    # A single-branch shallow clone stores neither new tags nor other
    # branches, and a local copy may be stale, so always fetch the ref
    # explicitly: tag first (releases), then branch. The forced refspec also
    # replaces a tag that moved upstream. A successful fetch is checked to
    # have produced the ref before it is used.
    set -l checkout_target ""
    __devbase_update_git_net -C "$__devbase_core_dir" fetch --depth 1 origin "+refs/tags/$target:refs/tags/$target"
    set -l rc $status
    set -l output $__devbase_update_net_output
    if test $rc -eq 0; and git -C "$__devbase_core_dir" cat-file -e "$target^{commit}" 2>/dev/null
        set checkout_target "$target"
    else if not string match -qi '*couldn*t find remote ref*' -- $output
        # Not a missing ref: network, auth or timeout. Say so instead of "not found".
        __devbase_update_print_net_error "Could not fetch $target from $CORE_REMOTE" $rc "$CORE_REMOTE" $output
        return 1
    else
        __devbase_update_git_net -C "$__devbase_core_dir" fetch --depth 1 origin "+refs/heads/$target:refs/remotes/origin/$target"
        set rc $status
        set output $__devbase_update_net_output
        if test $rc -eq 0; and git -C "$__devbase_core_dir" cat-file -e "origin/$target^{commit}" 2>/dev/null
            set checkout_target "origin/$target"
        else if not string match -qi '*couldn*t find remote ref*' -- $output
            __devbase_update_print_net_error "Could not fetch $target from $CORE_REMOTE" $rc "$CORE_REMOTE" $output
            return 1
        end
    end

    if test -z "$checkout_target"
        __devbase_update_print_error "Ref not found in core repo: $target"
        __devbase_update_print_info "Ensure the ref exists on the remote (branch/tag) and try again"
        return 1
    end

    # Stash local changes only once the target is known to exist, so a
    # failed update never leaves them hidden in the stash
    git -C "$__devbase_core_dir" stash --quiet 2>/dev/null; or true

    if not git -C "$__devbase_core_dir" -c advice.detachedHead=false checkout "$checkout_target" --quiet
        __devbase_update_print_error "Failed to checkout core ref: $target"
        git -C "$__devbase_core_dir" stash pop --quiet 2>/dev/null; or true
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

    # Runs at shell start: stay silent on failure
    set -g __devbase_update_quiet 1
    set core_update (__devbase_update_check_core 2>/dev/null); or true
    set custom_update (__devbase_update_check_custom 2>/dev/null); or true
    set -e __devbase_update_quiet

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
    # argv[1] = ref to update to (empty: latest release), argv[2] = "yes" to skip confirming
    set -l target_ref "$argv[1]"
    set -l assume_yes "$argv[2]"
    set -l force_ref false
    if test -n "$target_ref"
        set force_ref true
    end

    # Refuse before touching the repo: updating the checkout and then failing
    # in setup.sh leaves a core version that cannot be installed.
    if __devbase_ubuntu_too_old
        __devbase_ubuntu_upgrade_notice
        return 1
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
            # The failing check already printed git's reason above
            __devbase_update_print_error "Could not check for updates"
            return 1
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
    else if test "$assume_yes" = yes
        # Already confirmed, e.g. by the shell-start prompt
        __devbase_update_print_info "Proceeding with update"
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
    __devbase_update_print_info "Saved preferences are kept; run devbase-reconfigure afterwards to change editor, theme, packs or tools"
    echo ""

    if test -f "$__devbase_core_dir/setup.sh"
        pushd "$__devbase_core_dir" >/dev/null
        # Saved preferences are applied without prompting; devbase-reconfigure changes them.
        # An older ref's setup.sh rejects the flag, so only pass it when supported.
        if grep -q -- '--keep-preferences' setup.sh
            bash setup.sh --keep-preferences
        else
            bash setup.sh
        end
        set -l setup_status $status
        popd >/dev/null
        if test $setup_status -ne 0
            return $setup_status
        end
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
    echo "  --ref <ref>  Update core to a specific branch or tag"
    echo "  --snooze <h> Snooze update prompts for N hours"
    echo "  --unsnooze   Clear update snooze"
    echo "  --check     Check for updates without prompting (for shell integration)"
    echo "  --yes, -y    Apply an available update without asking to confirm"
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
    set -l assume_yes ""
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
            case --yes -y
                # Skip the confirmation; the caller has already asked
                set assume_yes yes
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
        __devbase_update_do_update "$ref" "$assume_yes"
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

    __devbase_update_do_update "" "$assume_yes"
end
