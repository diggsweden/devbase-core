# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# devbase-vscode-extensions - Install VS Code extensions based on DevBase preferences
# Reads selected language packs from preferences and installs matching extensions

set -g __vscode_ext_config_dir "$HOME/.config/devbase"
set -g __vscode_ext_packages_yaml "$HOME/.config/devbase/packages.yaml"
set -g __vscode_ext_preferences "$HOME/.config/devbase/preferences.yaml"

function __vscode_ext_print_info
    printf "%sⓘ%s %s\n" (set_color cyan) (set_color normal) "$argv[1]"
end

function __vscode_ext_print_success
    printf "%s✓%s %s\n" (set_color green) (set_color normal) "$argv[1]"
end

function __vscode_ext_print_warning
    printf "%s‼%s %s\n" (set_color yellow) (set_color normal) "$argv[1]"
end

function __vscode_ext_print_error
    printf "%s✗%s %s\n" (set_color red) (set_color normal) "$argv[1]" >&2
end

function __vscode_ext_check_requirements
    # Check for yq
    if not command -q yq
        __vscode_ext_print_error "yq is required but not installed"
        return 1
    end

    # Check for VS Code
    if not command -q code
        __vscode_ext_print_error "VS Code (code) is not installed or not in PATH"
        return 1
    end

    # Check for packages.yaml
    if not test -f "$__vscode_ext_packages_yaml"
        __vscode_ext_print_error "packages.yaml not found: $__vscode_ext_packages_yaml"
        __vscode_ext_print_info "Run DevBase setup.sh to install the latest configuration"
        return 1
    end

    # Check for preferences.yaml
    if not test -f "$__vscode_ext_preferences"
        __vscode_ext_print_error "preferences.yaml not found: $__vscode_ext_preferences"
        __vscode_ext_print_info "Run DevBase setup first to configure preferences"
        return 1
    end

    return 0
end

function __vscode_ext_prompt_yn --description "Prompt user for yes/no"
    set -l prompt $argv[1]
    set -l default $argv[2]
    set -l prompt_text

    if test "$default" = "y"
        set prompt_text "$prompt [Y/n]: "
    else
        set prompt_text "$prompt [y/N]: "
    end

    # Drain any buffered stdin (e.g. accidental keypresses during slow yq/code startup)
    while read -n 1 -t 0 2>/dev/null
    end

    while true
        read -P "$prompt_text" response
        
        if test -z "$response"
            test "$default" = "y"; and return 0; or return 1
        end
        
        switch (string lower $response)
            case y yes
                return 0
            case n no
                return 1
        end
    end
end

function __vscode_ext_prompt_neovim --description "Ask user about neovim extension"
    echo
    printf "%sThe Neovim extension enables Vim keybindings and commands in VS Code.%s\n" (set_color brblack) (set_color normal)
    if __vscode_ext_prompt_yn "Include Neovim extension?" "y"
        return 0
    else
        return 1
    end
end

function __vscode_ext_get_vscode_settings_path --description "Get VS Code settings file path"
    if test -d ~/.vscode-server/data/Machine
        echo ~/.vscode-server/data/Machine/settings.json
        return 0
    else if test -d ~/.config/Code/User
        echo ~/.config/Code/User/settings.json
        return 0
    end
    return 1
end

function __vscode_ext_configure_neovim_settings --description "Merge neovim settings into VS Code settings.json"
    if not command -q jq
        __vscode_ext_print_warning "jq not found, skipping neovim settings (install jq for full support)"
        return 0
    end

    set -l settings_file (__vscode_ext_get_vscode_settings_path)
    if test -z "$settings_file"
        __vscode_ext_print_warning "VS Code settings directory not found, skipping neovim settings"
        return 0
    end

    set -l use_wsl false
    test -d ~/.vscode-server; and set use_wsl true

    set -l nvim_path "$HOME/.local/share/mise/installs/aqua-neovim-neovim/vlatest/nvim-linux-x86_64/bin/nvim"

    set -l neovim_json (jq -n --arg wsl "$use_wsl" --arg nvim "$nvim_path" \
        '{"vscode-neovim.useWSL": ($wsl == "true"), "vscode-neovim.neovimExecutablePaths.linux": $nvim, "vscode-neovim.neovimInitVimPaths.linux": ""}')

    if test -f $settings_file
        jq -s '.[0] * .[1]' $settings_file (echo "$neovim_json" | psub) >$settings_file.tmp
        and mv $settings_file.tmp $settings_file
        and __vscode_ext_print_success "Neovim settings configured"
    else
        mkdir -p (dirname $settings_file)
        echo "$neovim_json" >$settings_file
        and __vscode_ext_print_success "Neovim settings configured (new settings file created)"
    end
end

function __vscode_ext_get_selected_packs
    # Read selected packs from preferences.yaml
    set -l packs (yq -r '.packs // [] | .[]' "$__vscode_ext_preferences" 2>/dev/null)
    
    if test (count $packs) -eq 0
        # Fallback to default packs
        for pack in java node python go ruby
            echo $pack
        end
    else
        for pack in $packs
            echo $pack
        end
    end
end
function __vscode_ext_get_extensions
    # Get extensions from core and selected packs
    set -l packs $argv
    
    # Core extensions - read file directly with yq
    yq -r '.core.vscode // {} | keys | .[]' "$__vscode_ext_packages_yaml" 2>/dev/null
    
    # Pack extensions
    for pack in $packs
        yq -r ".packs.$pack.vscode // {} | keys | .[]" "$__vscode_ext_packages_yaml" 2>/dev/null
    end
end

function __vscode_ext_get_installed
    code --list-extensions 2>/dev/null
end

function __vscode_ext_display_name
    set -l ext_id $argv[1]
    # Extract the extension name (after the dot)
    echo $ext_id | string replace -r '^[^.]+\.' ''
end

function __vscode_ext_is_optional_neovim
    set -l ext_id $argv[1]
    test "$ext_id" = "asvetliakov.vscode-neovim"
end

function __vscode_ext_install --description "Install extensions"
    set -l dry_run $argv[1]
    
    set -l packs (__vscode_ext_get_selected_packs)
    
    # Prompt for neovim extension preference and configure settings if accepted
    set -l neovim_pref "false"
    if test "$dry_run" != "true"
        if __vscode_ext_prompt_neovim
            set neovim_pref "true"
            __vscode_ext_configure_neovim_settings
        end
        echo
    end
    
    __vscode_ext_print_info "Selected language packs: $packs"
    
    set -l installed_list (__vscode_ext_get_installed)
    set -l extensions (__vscode_ext_get_extensions $packs)
    
    set -l installed_count 0
    set -l skipped_count 0
    set -l failed_count 0
    
    for ext_id in $extensions
        test -z "$ext_id"; and continue
        
        set -l display_name (__vscode_ext_display_name "$ext_id")
        
        # Skip neovim extension if user opted out
        if __vscode_ext_is_optional_neovim "$ext_id"; and test "$neovim_pref" != "true"
            __vscode_ext_print_info "$display_name (skipped - neovim not enabled)"
            set skipped_count (math $skipped_count + 1)
            continue
        end
        
        # Check if already installed (case-insensitive)
        set -l ext_lower (echo "$ext_id" | tr '[:upper:]' '[:lower:]')
        set -l already_installed false
        for installed in $installed_list
            set -l installed_lower (echo "$installed" | tr '[:upper:]' '[:lower:]')
            if test "$ext_lower" = "$installed_lower"
                set already_installed true
                break
            end
        end
        
        if test "$already_installed" = "true"
            __vscode_ext_print_info "$display_name (already installed)"
            set skipped_count (math $skipped_count + 1)
            continue
        end
        
        if test "$dry_run" = "true"
            __vscode_ext_print_info "$display_name (would install)"
            set installed_count (math $installed_count + 1)
        else
            if code --install-extension "$ext_id" --force >/dev/null 2>&1
                __vscode_ext_print_success "$display_name"
                set installed_count (math $installed_count + 1)
            else
                __vscode_ext_print_error "$display_name (failed)"
                set failed_count (math $failed_count + 1)
            end
        end
    end
    
    # Print summary
    echo
    if test "$dry_run" = "true"
        __vscode_ext_print_info "Dry run complete"
        test $installed_count -gt 0; and __vscode_ext_print_info "Would install $installed_count extensions"
    else
        test $installed_count -gt 0; and __vscode_ext_print_success "Installed $installed_count extensions"
    end
    test $skipped_count -gt 0; and __vscode_ext_print_info "Skipped $skipped_count extensions (already installed or disabled)"
    test $failed_count -gt 0; and __vscode_ext_print_warning "Failed to install $failed_count extensions"
    
    return 0
end

function __vscode_ext_list --description "List extensions that would be installed"
    set -l packs (__vscode_ext_get_selected_packs)
    
    echo "Extensions for selected packs: $packs"
    echo
    
    # Core extensions
    echo "Core extensions:"
    set -l core_exts (yq -r '.core.vscode // {} | keys | .[]' "$__vscode_ext_packages_yaml" 2>/dev/null)
    for ext in $core_exts
        if __vscode_ext_is_optional_neovim "$ext"
            echo "  - $ext (optional - prompted during install)"
        else
            echo "  - $ext"
        end
    end
    echo
    
    # Pack extensions
    for pack in $packs
        set -l pack_exts (yq -r ".packs.$pack.vscode // {} | keys | .[]" "$__vscode_ext_packages_yaml" 2>/dev/null)
        if test (count $pack_exts) -gt 0
            echo "$pack pack:"
            for ext in $pack_exts
                echo "  - $ext"
            end
            echo
        end
    end
end

function __vscode_ext_show_help
    echo "devbase-vscode-extensions - Install VS Code extensions based on DevBase preferences"
    echo
    echo "Usage: devbase-vscode-extensions [options]"
    echo
    echo "Options:"
    echo "  --list, -l      List extensions that would be installed"
    echo "  --dry-run, -n   Show what would be installed without installing"
    echo "  --help, -h      Show this help message"
    echo
    echo "Examples:"
    echo "  devbase-vscode-extensions          # Install extensions"
    echo "  devbase-vscode-extensions --list   # Show available extensions"
    echo "  devbase-vscode-extensions --dry-run # Preview installation"
    echo
    echo "Configuration:"
    echo "  Preferences: $__vscode_ext_preferences"
    echo "  Packages:    $__vscode_ext_packages_yaml"
end

function devbase-vscode-extensions --description "Install VS Code extensions based on DevBase preferences"
    # Parse arguments
    set -l show_list false
    set -l dry_run false
    
    for arg in $argv
        switch $arg
            case --list -l
                set show_list true
            case --dry-run -n
                set dry_run true
            case --help -h
                __vscode_ext_show_help
                return 0
            case '*'
                __vscode_ext_print_error "Unknown option: $arg"
                __vscode_ext_show_help
                return 1
        end
    end
    
    # Check requirements
    if not __vscode_ext_check_requirements
        return 1
    end
    
    if test "$show_list" = "true"
        __vscode_ext_list
        return 0
    end
    
    echo "Installing VS Code extensions..."
    echo
    __vscode_ext_install "$dry_run"
end
